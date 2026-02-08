#!/usr/bin/env Rscript

# Load required functions
source("R/scrape_recipe.R")
source("R/create_recipe_page.R")
source("R/get_hbh_urls.R")
source("R/update_config.R")

# Get arguments
args <- commandArgs(trailingOnly = TRUE)
limit <- 10 # Default limit

if (length(args) > 0) {
    limit <- as.numeric(args[1])
}

cat("--- Bulk Adding Recipes from Half Baked Harvest ---\n")
cat("Target limit:", limit, "\n\n")

# 1. Discover URLs
urls <- get_hbh_urls(limit = limit)
cat("\nDiscovered", length(urls), "potential recipe URLs.\n\n")

if (length(urls) == 0) {
    cat("No URLs found. Exiting.\n")
    quit(status = 0)
}

output_dir <- "cookbook"
success_count <- 0
error_count <- 0

# 2. Process each URL
for (i in seq_along(urls)) {
    url <- urls[i]

    # Create filename to check if it already exists
    # This logic matches how filenames are generated lower down
    temp_title_tag <- gsub("https://www.halfbakedharvest.com/", "", url)
    temp_title_tag <- gsub("/", "", temp_title_tag)
    # Actually, let's just use the URL to see if we've processed it
    # But a better way is to check the cookbook directory for a file that matches what scrape_recipe would produce.
    # However, since we don't know the title yet, let's just rely on the fact that
    # if it's in the cookbook, we probably already have it.

    cat(sprintf("[%d/%d] Checking: %s\n", i, length(urls), url))

    tryCatch(
        {
            # Scrape the recipe (we need this to get the title for the filename check)
            # Optimization: could we check the URL against a log of already scraped URLs?
            # For now, let's just scrape it and then skip if the file exists.
            recipe <- scrape_recipe(url)

            filename <- paste0(tolower(gsub("[^a-zA-Z0-9]+", "-", recipe$title)), ".qmd")
            filepath <- file.path(output_dir, filename)

            if (file.exists(filepath)) {
                cat("  - Skipping (already exists):", recipe$title, "\n")
                next
            }

            # Create the recipe page
            create_recipe_page(recipe, output_dir)

            # Update _quarto.yml
            updated <- update_quarto_config(filename, output_dir)

            if (updated) {
                cat("  ✓ Added and updated config:", recipe$title, "\n")
            } else {
                cat("  ✓ Added (already in config):", recipe$title, "\n")
            }

            success_count <<- success_count + 1

            # Rate limiting: short sleep to be polite
            Sys.sleep(1)
        },
        error = function(e) {
            cat("  ✗ Error:", e$message, "\n")
            error_count <<- error_count + 1
        }
    )
    cat("\n")
}

cat("--- Summary ---\n")
cat("Successfully added:", success_count, "\n")
cat("Errors encountered:", error_count, "\n")

# 3. Optional Migration to Database
if (success_count > 0) {
    cat("\nRunning migration to DuckDB...\n")
    source("migrate_to_db.R")
}

cat("\nTo render the cookbook, run: quarto render cookbook\n")
