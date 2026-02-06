#!/usr/bin/env Rscript

# Load required functions
source("R/scrape_recipe.R")
source("R/create_recipe_page.R")
library("yaml")

# Get URL from command line argument
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
    cat("Usage: Rscript add_recipe.R <recipe_url>\n")
    cat(
        "Example: Rscript add_recipe.R https://www.cookwell.com/recipe/chicken-posole-verde\n"
    )
    quit(status = 1)
}

url <- args[1]
output_dir <- "cookbook"

cat("Scraping recipe from:", url, "\n")

tryCatch(
    {
        # Scrape the recipe
        recipe <- scrape_recipe(url)

        # Create the recipe page
        create_recipe_page(recipe, output_dir)

        # Update _quarto.yml
        config_path <- file.path(output_dir, "_quarto.yml")
        if (file.exists(config_path)) {
            config <- read_yaml(config_path)

            # Get the new filename
            filename <- paste0(
                tolower(gsub("[^a-zA-Z0-9]+", "-", recipe$title)),
                ".qmd"
            )

            # Add to chapters if not already there
            if (!filename %in% config$book$chapters) {
                config$book$chapters <- c(config$book$chapters, filename)

                # Write with custom handler for booleans
                write_yaml(
                    config,
                    config_path,
                    handlers = list(
                        logical = function(x) {
                            result <- ifelse(x, "true", "false")
                            class(result) <- "verbatim"
                            return(result)
                        }
                    )
                )
                cat("Updated _quarto.yml with new recipe.\n")
            }
        }

        cat("\n✓ Successfully added recipe:", recipe$title, "\n")
        cat("To render the cookbook, run: quarto render cookbook\n")
    },
    error = function(e) {
        cat("✗ Error adding recipe:", e$message, "\n")
        quit(status = 1)
    }
)
