#' Parallelized Migration script to clean ingredients using Ollama
#'
#' This script fetches all distinct ingredients, parses them in parallel
#' using future.apply, and updates the DuckDB database in batches.

library(DBI)
library(duckdb)
library(future.apply)
library(httr2)
library(jsonlite)
source("R/ingredient_utils.R")

# Configure Parallelization
# Using 4 workers to stay within 16GB RAM constraints
plan(multisession, workers = 4)

db_path <- "recipes.duckdb"
batch_size <- 50

message("Connecting to database at: ", db_path)
con <- dbConnect(duckdb::duckdb(), dbdir = db_path)

# 1. Fetch all distinct ingredients
message("Fetching distinct ingredients...")
ingredients_df <- dbGetQuery(con, "SELECT DISTINCT ingredient FROM ingredients")
total_ingredients <- nrow(ingredients_df)

if (total_ingredients == 0) {
    message("✓ No ingredients found.")
    dbDisconnect(con, shutdown = TRUE)
    quit(status = 0)
}

message(sprintf("Starting parallel migration for %d ingredients using 4 workers...", total_ingredients))
message(sprintf("Processing in batches of %d...", batch_size))

# Process in batches
num_batches <- ceiling(total_ingredients / batch_size)

for (b in seq_len(num_batches)) {
    start_idx <- (b - 1) * batch_size + 1
    end_idx <- min(b * batch_size, total_ingredients)

    batch_raw <- ingredients_df$ingredient[start_idx:end_idx]

    # Parallel Parse with Ollama
    message(sprintf("[%d/%d] Batch %d: Parsing %d ingredients...", end_idx, total_ingredients, b, length(batch_raw)))

    # future_lapply parallelizes the requests
    # Note: Ollama handles concurrent requests by queuing or processing them based on context size.
    batch_cleaned <- future_lapply(batch_raw, function(x) {
        # Using the utility function we already implemented
        clean_ingredient_ollama(x)
    })

    # Update Database within a transaction for efficiency and thread-safety
    dbWithTransaction(con, {
        for (i in seq_along(batch_raw)) {
            dbExecute(
                con,
                "UPDATE ingredients SET clean_ingredient = ? WHERE ingredient = ?",
                list(batch_cleaned[[i]], batch_raw[i])
            )
        }
    })

    # Progress check every batch
    # time_elapsed calculation could be added here for ETA
}

# 2. Finalize
message("Ensuring index exists...")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_clean_ingredient ON ingredients(clean_ingredient)")

dbDisconnect(con, shutdown = TRUE)
message("✓ Parallel ingredients migration complete.")
