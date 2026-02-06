#!/usr/bin/env Rscript

# Load required functions
source("R/scrape_recipe.R")
source("R/create_recipe_page.R")
source("R/update_config.R")
library(rvest)
library(dplyr)
library(stringr)

# Get URL from command line argument
args <- commandArgs(trailingOnly = TRUE)
url <- if (length(args) > 0) args[1] else "https://www.halfbakedharvest.com/26-most-popular-super-bowl-recipes/"
output_dir <- "cookbook"

cat("--- Scraping Roundup Recipes from:", url, "---\n\n")

# 1. Extract recipe URLs from the roundup page
cat("Extracting recipe links...\n")
page <- read_html(url)

# Find links that contain "See The Recipe" or links in headers/buttons that point to other recipes
recipe_urls <- page %>%
    html_nodes("a") %>%
    html_attr("href")

# Filter for links that appear to be recipes (on halfbakedharvest.com and not the roundup itself)
# We can also look for the "See The Recipe" text specifically
see_recipe_links <- page %>%
    html_nodes("a") %>%
    keep(~ str_detect(html_text(.), "See The Recipe")) %>%
    html_attr("href")

# If no "See The Recipe" links found, fallback to all HBH links that aren't the current page or administrative
if (length(see_recipe_links) == 0) {
    cat("Warning: No 'See The Recipe' links found. Falling back to generic link detection.\n")
    recipe_urls <- recipe_urls[str_detect(recipe_urls, "halfbakedharvest\\.com") &
        !str_detect(recipe_urls, url) &
        !str_detect(recipe_urls, "/category/") &
        !str_detect(recipe_urls, "/shop/") &
        !str_detect(recipe_urls, "/about/")]
} else {
    recipe_urls <- see_recipe_links
}

recipe_urls <- unique(recipe_urls)
recipe_urls <- recipe_urls[!is.na(recipe_urls)]

cat("Discovered", length(recipe_urls), "potential recipe URLs.\n\n")

if (length(recipe_urls) == 0) {
    cat("No recipe URLs found. Exiting.\n")
    quit(status = 0)
}

success_count <- 0
error_count <- 0

# 2. Process each URL
for (i in seq_along(recipe_urls)) {
    recipe_url <- recipe_urls[i]
    cat(sprintf("[%d/%d] Scraping: %s\n", i, length(recipe_urls), recipe_url))

    tryCatch(
        {
            # Scrape the recipe
            recipe <- scrape_recipe(recipe_url)

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

            success_count <- success_count + 1

            # Rate limiting: short sleep to be polite
            Sys.sleep(1)
        },
        error = function(e) {
            cat("  ✗ Error:", e$message, "\n")
            error_count <- error_count + 1
        }
    )
    cat("\n")
}

cat("--- Summary ---\n")
cat("Successfully added:", success_count, "\n")
cat("Errors encountered:", error_count, "\n")
cat("\nTo render the cookbook, run: quarto render cookbook\n")
