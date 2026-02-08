library(DBI)
library(duckdb)

con <- dbConnect(duckdb::duckdb(), "recipes.duckdb", read_only = TRUE)
recipes <- dbGetQuery(con, "SELECT title, source_url FROM recipes LIMIT 10")
print(recipes)

# Check count of recipes with missing URLs
missing_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM recipes WHERE source_url IS NULL OR source_url = ''")
total_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM recipes")
cat("\nTotal recipes:", total_count$count, "\n")
cat("Recipes missing source_url:", missing_count$count, "\n")

dbDisconnect(con, shutdown = TRUE)
