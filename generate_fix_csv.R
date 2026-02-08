source("R/get_hbh_urls.R")
source("R/get_cookwell_urls.R")
library(DBI)
library(duckdb)
library(stringr)

# Connect in read-only mode to avoid locking issues
con <- dbConnect(duckdb::duckdb(), dbdir = "recipes.duckdb", read_only = TRUE)
recipes <- dbGetQuery(con, "SELECT id, title FROM recipes")
dbDisconnect(con, shutdown = TRUE)

cat("Fetching all known URLs from sitemaps...\n")
hbh_urls <- get_hbh_urls()
cookwell_urls <- get_cookwell_urls()

cat("Mapping", nrow(recipes), "recipes...\n")
fix_data <- data.frame(id = character(), title = character(), corrected_url = character(), source = character(), stringsAsFactors = FALSE)

for (i in 1:nrow(recipes)) {
    id <- recipes$id[i]
    title <- recipes$title[i]
    clean_id <- gsub("-+$", "", gsub("^-+", "", id))

    # Try HBH
    hbh_match <- hbh_urls[grep(paste0("/", clean_id, "/?$"), hbh_urls)]
    if (length(hbh_match) > 0) {
        fix_data <- rbind(fix_data, data.frame(id = id, title = title, corrected_url = hbh_match[1], source = "HBH"))
        next
    }

    # Try Cookwell
    cw_match <- cookwell_urls[grep(paste0("/", clean_id, "$"), cookwell_urls)]
    if (length(cw_match) > 0) {
        fix_data <- rbind(fix_data, data.frame(id = id, title = title, corrected_url = cw_match[1], source = "Cookwell"))
        next
    }

    # Fallback/Not Found
    fix_data <- rbind(fix_data, data.frame(id = id, title = title, corrected_url = NA, source = "Unknown"))
}

write.csv(fix_data, "corrected_recipe_urls.csv", row.names = FALSE)
cat("Generated corrected_recipe_urls.csv\n")
cat("Direct matches found:", sum(!is.na(fix_data$corrected_url)), "of", nrow(fix_data), "\n")
