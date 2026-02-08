#!/usr/bin/env Rscript

#' Bulk Recipe Processing Script
#'
#' Usage:
#'   Rscript scripts/bulk_process.R --limit 10
#'   Rscript scripts/bulk_process.R --url "https://..."
#'   Rscript scripts/bulk_process.R --limit 50 --parallel

library(optparse)
library(future.apply)
library(dplyr)

# Paths (Assuming running from project root)
db_path <- "recipes.duckdb"
cookbook_dir <- "cookbook"

# Source workflow logic
source("R/recipe_workflow.R")
source("R/get_hbh_urls.R")

# Define options
option_list <- list(
    make_option(c("-u", "--url"),
        type = "character", default = NULL,
        help = "Specific URL to scrape", metavar = "URL"
    ),
    make_option(c("-l", "--limit"),
        type = "integer", default = 10,
        help = "Number of recipes to fetch/process (if not providing URL)", metavar = "NUMBER"
    ),
    make_option(c("-p", "--parallel"),
        action = "store_true", default = FALSE,
        help = "Enable parallel processing (4 workers)", metavar = "BOOL"
    )
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

# Determine URLs to process
urls_to_process <- c()

if (!is.null(opt$url)) {
    urls_to_process <- c(opt$url)
} else {
    message(paste("Fetching top", opt$limit, "URLs from Half Baked Harvest..."))
    tryCatch(
        {
            urls_to_process <- get_hbh_urls(limit = opt$limit)
        },
        error = function(e) {
            stop(paste("Failed to fetch URLs:", e$message))
        }
    )
}

if (length(urls_to_process) == 0) {
    message("No URLs found to process.")
    quit(status = 0)
}

message(paste("Found", length(urls_to_process), "URLs to process."))

# Processing Loop
if (opt$parallel) {
    message("Starting PARALLEL processing (4 workers)...")
    plan(multisession, workers = 4)

    results <- future_lapply(urls_to_process, function(url) {
        # Re-source necessary files in worker if needed, but future usually handles exports.
        # To be safe with DuckDB connections in parallel, we rely on process_recipe creating its own connection.
        process_recipe(url, db_path = db_path, cookbook_dir = cookbook_dir)
    }, future.seed = TRUE)
} else {
    message("Starting SEQUENTIAL processing...")
    results <- lapply(urls_to_process, function(url) {
        process_recipe(url, db_path = db_path, cookbook_dir = cookbook_dir)
    })
}

# Summary
status_counts <- table(sapply(results, function(x) x$status))
message("\n--- Summary ---")
print(status_counts)

# Print errors if any
errors <- Filter(function(x) x$status == "error", results)
if (length(errors) > 0) {
    message("\nErrors encountered:")
    for (err in errors) {
        message(paste("-", err$message))
    }
}
