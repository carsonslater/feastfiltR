library(DBI)
library(duckdb)

con <- dbConnect(duckdb::duckdb(), "recipes.duckdb", read_only = TRUE)
res <- dbGetQuery(con, "SELECT id, title, source_url FROM recipes WHERE title LIKE '%Risotto%'")
print(res)
dbDisconnect(con, shutdown = TRUE)
