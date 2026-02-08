#' Unified Recipe Workflow
#'
#' This module consolidates the recipe scraping, parsing, and storage logic.
#' It handles:
#' 1. Scraping from URL
#' 2. Parsing ingredients (Ollama or Regex)
#' 3. Generating Quarto markdown (cookbook)
#' 4. Updating DuckDB

library(DBI)
library(duckdb)
library(jsonlite)
library(dplyr)
library(stringr)

# Source dependencies
# Assuming this script is sourced from project root or these paths are relative
source("R/scrape_recipe.R")
source("R/create_recipe_page.R")
source("R/ingredient_utils.R")
source("R/update_config.R")

#' Process a single recipe URL
#'
#' @param url The URL to scrape
#' @param db_path Path to the DuckDB database
#' @param cookbook_dir Path to the cookbook directory (for .qmd files)
#' @param force_reparse If TRUE, re-scrapes even if ID exists (optional logic)
#' @return A list with status ("success", "skipped", "error") and message
process_recipe <- function(url, db_path = "recipes.duckdb", cookbook_dir = "cookbook", force_reparse = FALSE) {
    # Connect to DB
    # We want to manage the connection locally for this function call
    con <- dbConnect(duckdb::duckdb(), dbdir = db_path)
    on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

    tryCatch(
        {
            # 1. Check if URL already exists
            # We might need to normalize the URL or check by title later, but URL is a good first check
            existing <- dbGetQuery(con, "SELECT id, title FROM recipes WHERE source_url = ?", list(url))

            if (nrow(existing) > 0 && !force_reparse) {
                return(list(status = "skipped", message = paste("Recipe already exists:", existing$title[1])))
            }

            # 2. Scrape
            message(paste("Scraping:", url))
            recipe_data <- scrape_recipe(url)

            if (is.null(recipe_data) || is.null(recipe_data$title)) {
                return(list(status = "error", message = "Failed to scrape recipe data."))
            }

            # 3. Generate ID and Filename
            # Consistent ID generation with previous scripts
            recipe_id <- tolower(gsub("[^a-zA-Z0-9]+", "-", recipe_data$title))
            filename <- paste0(recipe_id, ".qmd")

            # Check if ID exists (in case URL was different but title is same)
            existing_id <- dbGetQuery(con, "SELECT id FROM recipes WHERE id = ?", list(recipe_id))
            if (nrow(existing_id) > 0 && !force_reparse) {
                return(list(status = "skipped", message = paste("Recipe with ID", recipe_id, "already exists.")))
            }

            # 4. Parse Ingredients with Ollama
            message("Parsing ingredients with Ollama...")
            parsed_ingredients <- list()

            # Create the ingredients for the DB
            updated_ingredients_db <- list()

            for (ing in recipe_data$ingredients) {
                if (is.na(ing) || ing == "") next

                # Use the utility function from R/ingredient_utils.R
                # It handles the Ollama call and falls back to regex if needed
                clean <- clean_ingredient_ollama(ing)
                parsed_ingredients[[ing]] <- clean
            }

            # 5. Create .qmd file and update configuration
            output_path <- file.path(cookbook_dir, filename)
            if (!dir.exists(cookbook_dir)) dir.create(cookbook_dir)

            # create_recipe_page usually takes (recipe_data, output_dir)
            create_recipe_page(recipe_data, output_dir)

            # update_quarto_config checks/adds file to _quarto.yml
            update_quarto_config(filename, cookbook_dir)

            # 6. Update Database (Transaction)
            dbWithTransaction(con, {
                # Insert/Replace Recipe
                # Note: image_path is currently NA as we aren't downloading images here yet
                # If scrape_recipe returns an image URL, we might want to use that or download it.
                # Existing implementation scraped image URL but didn't always download.
                # For now, we will store the image URL if available, or NA.
                img_path <- if (!is.null(recipe_data$image_url)) recipe_data$image_url else NA

                dbExecute(con, "
        INSERT OR REPLACE INTO recipes (id, title, source_url, image_path, prep_time, cook_time, total_time, yield, instructions)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ", list(
                    recipe_id,
                    recipe_data$title,
                    url,
                    img_path,
                    recipe_data$prep_time,
                    recipe_data$cook_time,
                    recipe_data$total_time,
                    NA, # Yield not always captured
                    toJSON(recipe_data$instructions)
                ))

                # Refresh Ingredients
                dbExecute(con, "DELETE FROM ingredients WHERE recipe_id = ?", list(recipe_id))

                for (raw_ing in names(parsed_ingredients)) {
                    clean_ing <- parsed_ingredients[[raw_ing]]
                    dbExecute(
                        con, "INSERT INTO ingredients (recipe_id, ingredient, clean_ingredient) VALUES (?, ?, ?)",
                        list(recipe_id, raw_ing, clean_ing)
                    )
                }
            })

            return(list(status = "success", message = paste("Successfully processed:", recipe_data$title)))
        },
        error = function(e) {
            message(paste("Error processing", url, ":", e$message))
            return(list(status = "error", message = paste("Error processing", url, ":", e$message)))
        }
    )
}
