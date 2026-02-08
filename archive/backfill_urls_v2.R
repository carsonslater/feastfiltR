source("R/get_hbh_urls.R")
source("R/get_cookwell_urls.R")
library(DBI)
library(duckdb)
library(stringr)

cat("Fetching all known URLs from sitemaps...\n")
hbh_urls <- get_hbh_urls()
cookwell_urls <- get_cookwell_urls()

cat("Found", length(hbh_urls), "HBH URLs and", length(cookwell_urls), "Cookwell URLs.\n")

# Connect to DB
con <- dbConnect(duckdb::duckdb(), dbdir = "recipes.duckdb")

# Get all recipes
recipes <- dbGetQuery(con, "SELECT id, title FROM recipes")

# Create a mapping of slugs to URLs
hbh_map <- setNames(hbh_urls, tolower(gsub("[^a-zA-Z0-9]+", "-", gsub("https://www.halfbakedharvest.com/|/", "", hbh_urls))))

# Wait, the HBH slug logic needs to be exactly what scrape_recipe.R uses
# scrape_recipe.R uses the title: tolower(gsub("[^a-zA-Z0-9]+", "-", recipe_data$title))
# But we don't know the title for every URL.
# However, the ID already in the DB was generated from the title.

# Let's try matching the ID to the URL slug
hbh_slugs <- gsub("https://www.halfbakedharvest.com/|/", "", hbh_urls)
cookwell_slugs <- gsub("https://www.cookwell.com/recipes/|/", "", cookwell_urls)

cat("Backfilling database...\n")
success_count <- 0
not_found_count <- 0

for (i in 1:nrow(recipes)) {
    id <- recipes$id[i]
    clean_id <- gsub("-+$", "", gsub("^-+", "", id)) # Trim leading/trailing hyphens

    # Try HBH
    hbh_match <- hbh_urls[grep(paste0("/", clean_id, "/?$"), hbh_urls)]
    if (length(hbh_match) > 0) {
        dbExecute(con, "UPDATE recipes SET source_url = ? WHERE id = ?", list(hbh_match[1], id))
        success_count <- success_count + 1
        next
    }

    # Try Cookwell
    cw_match <- cookwell_urls[grep(paste0("/", clean_id, "$"), cookwell_urls)]
    if (length(cw_match) > 0) {
        dbExecute(con, "UPDATE recipes SET source_url = ? WHERE id = ?", list(cw_match[1], id))
        success_count <- success_count + 1
        next
    }

    not_found_count <- not_found_count + 1
}

dbDisconnect(con, shutdown = TRUE)

cat("Summary:\n")
cat("Successfully matched:", success_count, "\n")
cat("Not found:", not_found_count, "\n")
