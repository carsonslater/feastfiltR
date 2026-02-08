#!/usr/bin/env Rscript

#' Bulk Recipe Processing Script
#'
#' Usage:
#'   Rscript scripts/bulk_process.R --limit 10
#'   Rscript scripts/bulk_process.R --url "https://..."
#'   Rscript scripts/bulk_process.R --limit 50 --parallel

library(future.apply)
library(dplyr)

# Paths (Assuming running from project root)
db_path <- "recipes.duckdb"
cookbook_dir <- "cookbook"

# Source workflow logic
source("R/recipe_workflow.R")
source("R/get_hbh_urls.R")

# Manual Argument Parsing
args <- commandArgs(trailingOnly = TRUE)

# Defaults
limit <- 10
url <- NULL
parallel <- FALSE

# Parse loop
i <- 1
while (i <= length(args)) {
    arg <- args[i]

    if (arg == "--limit" || arg == "-l") {
        if (i + 1 <= length(args)) {
            limit <- as.integer(args[i + 1])
            i <- i + 1 # Skip next arg as it's the value
        }
    } else if (arg == "--url" || arg == "-u") {
        if (i + 1 <= length(args)) {
            url <- args[i + 1]
            i <- i + 1
        }
    } else if (arg == "--parallel" || arg == "-p") {
        parallel <- TRUE
    }

    i <- i + 1
}

# Determine URLs to process
urls_to_process <- c()

if (!is.null(url)) {
    urls_to_process <- c(url)
} else {
    message(paste("Fetching top", limit, "URLs from Half Baked Harvest..."))
    tryCatch(
        {
            urls_to_process <- get_hbh_urls(limit = limit)
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
if (parallel) {
    message("Starting PARALLEL processing (4 workers)...")
    plan(multisession, workers = 4)

    results <- future_lapply(urls_to_process, function(url) {
        tryCatch(
            {
                process_recipe(url, db_path = db_path, cookbook_dir = cookbook_dir)
            },
            error = function(e) {
                list(status = "error", message = e$message)
            }
        )
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
