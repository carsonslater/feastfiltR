library(DBI)
library(duckdb)

# Path to DuckDB database
db_path <- "recipes.duckdb"

# Connect to (or create) the database
con <- dbConnect(duckdb::duckdb(), dbdir = db_path)

# Create recipes table
dbExecute(con, "
  CREATE TABLE IF NOT EXISTS recipes (
    id VARCHAR PRIMARY KEY,
    title VARCHAR,
    source_url VARCHAR,
    image_path VARCHAR,
    prep_time VARCHAR,
    cook_time VARCHAR,
    total_time VARCHAR,
    yield VARCHAR,
    instructions TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  )
")

# Create ingredients table (for normalized filtering)
dbExecute(con, "
  CREATE TABLE IF NOT EXISTS ingredients (
    recipe_id VARCHAR,
    ingredient VARCHAR,
    FOREIGN KEY (recipe_id) REFERENCES recipes(id)
  )
")

# Create a view or index for faster search if needed
dbExecute(con, "CREATE INDEX IF NOT EXISTS idx_ingredient ON ingredients(ingredient)")

dbDisconnect(con, shutdown = TRUE)

cat("DuckDB initialized at:", db_path, "\n")
