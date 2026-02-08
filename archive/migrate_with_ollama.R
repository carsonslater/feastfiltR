#' Migration script to clean existing ingredients in the database using Ollama
#'
#' This script fetches all ingredients, parses them with Ollama (Gemma3:4b),
#' and updates the clean_ingredient column.

library(DBI)
library(duckdb)
library(httr2)
library(jsonlite)
source("R/ingredient_utils.R")

db_path <- "recipes.duckdb"
message("Connecting to database at: ", db_path)

# Connect to the database
con <- dbConnect(duckdb::duckdb(), dbdir = db_path)

# 1. Fetch all distinct ingredients to re-parse everything
message("Fetching ingredients...")
ingredients_df <- dbGetQuery(con, "SELECT DISTINCT ingredient FROM ingredients")

if (nrow(ingredients_df) == 0) {
    message("✓ No ingredients found in database.")
    dbDisconnect(con, shutdown = TRUE)
    quit(status = 0)
}

message("Updating ALL ", nrow(ingredients_df), " unique ingredients (this will take a significant amount of time)...")

for (i in seq_len(nrow(ingredients_df))) {
    raw <- ingredients_df$ingredient[i]

    # Try parsing with Ollama
    clean <- clean_ingredient_ollama(raw)

    # Update all rows with this raw ingredient
    dbExecute(
        con,
        "UPDATE ingredients SET clean_ingredient = ? WHERE ingredient = ?",
        list(clean, raw)
    )

    if (i %% 5 == 0 || i == nrow(ingredients_df)) {
        message(sprintf("[%d/%d] Processed: '%s' -> '%s'", i, nrow(ingredients_df), raw, clean))
    }
}

# 2. Create index on clean_ingredient for faster searching if it doesn't exist
message("Ensuring index exists...")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_clean_ingredient ON ingredients(clean_ingredient)")

dbDisconnect(con, shutdown = TRUE)
message("✓ Ingredients migration with Ollama complete.")
