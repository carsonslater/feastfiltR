library(DBI)
library(duckdb)

db_path <- "recipes.duckdb"
con <- dbConnect(duckdb::duckdb(), dbdir = db_path)

# Get recipes without source_url
recipes <- dbGetQuery(con, "SELECT id, title FROM recipes WHERE source_url IS NULL OR source_url = ''")

cat("Found", nrow(recipes), "recipes to backfill.\n")

if (nrow(recipes) > 0) {
    # Prepare update statement
    # We assume most are Half Baked Harvest for now based on the slug patterns
    # If we find other patterns, we can expand this.

    success_count <- 0

    for (i in 1:nrow(recipes)) {
        id <- recipes$id[i]

        # Heuristic for URL reconstruction
        # Most are HBH: https://www.halfbakedharvest.com/<slug>/
        # The slug used in ID usually matches the URL slug

        # Clean up the ID for URL (ensure no double hyphens at end, etc.)
        url_slug <- id
        # Remove trailing hyphens if any
        url_slug <- gsub("-+$", "", url_slug)

        source_url <- paste0("https://www.halfbakedharvest.com/", url_slug, "/")

        dbExecute(con, "UPDATE recipes SET source_url = ? WHERE id = ?", list(source_url, id))
        success_count <- success_count + 1

        if (i %% 100 == 0) cat("Processed", i, "recipes...\n")
    }

    cat("Successfully backfilled", success_count, "recipes with HBH URLs.\n")
}

dbDisconnect(con, shutdown = TRUE)
