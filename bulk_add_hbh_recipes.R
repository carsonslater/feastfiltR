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
    cat(sprintf("[%d/%d] Scraping: %s\n", i, length(urls), url))

    tryCatch(
        {
            # Scrape the recipe
            recipe <- scrape_recipe(url)

            # Create the recipe page
            create_recipe_page(recipe, output_dir)

            # Update _quarto.yml
            filename <- paste0(tolower(gsub("[^a-zA-Z0-9]+", "-", recipe$title)), ".qmd")
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
cat("\nTo render the cookbook, run: quarto render cookbook\n")
