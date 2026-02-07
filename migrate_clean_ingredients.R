#' Migration script to clean existing ingredients in the database
#'

library(DBI)
library(duckdb)
source("R/ingredient_utils.R")

db_path <- "recipes.duckdb"
message("Connecting to database at: ", db_path)

# Connect to the database
con <- dbConnect(duckdb::duckdb(), dbdir = db_path)

# 1. Add column if it doesn't exist (in case db_init wasn't run)
cols <- dbGetQuery(con, "PRAGMA table_info(ingredients)")
if (!"clean_ingredient" %in% cols$name) {
    message("Adding clean_ingredient column...")
    dbExecute(con, "ALTER TABLE ingredients ADD COLUMN clean_ingredient VARCHAR")
}

# 2. Fetch all ingredients
message("Fetching ingredients...")
ingredients_df <- dbGetQuery(con, "SELECT DISTINCT ingredient FROM ingredients")

# 3. Update each unique ingredient
message("Updating ingredients (this may take a moment)...")
for (i in 1:nrow(ingredients_df)) {
    raw <- ingredients_df$ingredient[i]
    clean <- clean_ingredient(raw)

    # Update all rows with this raw ingredient
    dbExecute(
        con,
        "UPDATE ingredients SET clean_ingredient = ? WHERE ingredient = ?",
        list(clean, raw)
    )

    if (i %% 50 == 0) message("Processed ", i, " / ", nrow(ingredients_df))
}

# 4. Create index on clean_ingredient for faster searching
message("Creating index...")
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_clean_ingredient ON ingredients(clean_ingredient)")

dbDisconnect(con, shutdown = TRUE)
message("✓ Ingredients migration complete.")
