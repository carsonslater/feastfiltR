library(shiny)
library(DT)
library(DBI)
library(duckdb)
library(dplyr)
library(jsonlite)
library(bslib)
library(stringr)
library(shinyjs)

# Database Connection
db_path <- "recipes.duckdb"
con <- dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = TRUE)

# Serve images from the cookbook directory
addResourcePath("images", file.path(getwd(), "cookbook/images"))

# Helper function to get all unique ingredients for selectizeInput
get_all_ingredients <- function() {
    res <- dbGetQuery(con, "SELECT DISTINCT ingredient FROM ingredients ORDER BY ingredient")
    res$ingredient
}

# Helper function to find recipes matching ingredients
# This version finds recipes that contain ALL selected ingredients
search_recipes <- function(selected_ingredients) {
    if (length(selected_ingredients) == 0) {
        return(dbGetQuery(con, "SELECT *, 0 as match_count FROM recipes ORDER BY title"))
    }

    # Normalize selected ingredients (optional, but good for robust matching)
    # For now, we'll assume exact matches from the selectizeInput

    # SQL to find recipes containing ALL selected ingredients
    placeholder <- paste(rep("?", length(selected_ingredients)), collapse = ",")
    query <- paste0("
    SELECT r.*, COUNT(i.ingredient) as match_count
    FROM recipes r
    JOIN ingredients i ON r.id = i.recipe_id
    WHERE i.ingredient IN (", placeholder, ")
    GROUP BY r.id, r.title, r.source_url, r.image_path, r.prep_time, r.cook_time, r.total_time, r.yield, r.instructions, r.created_at
    HAVING COUNT(i.ingredient) = ?
  ")

    dbGetQuery(con, query, params = as.list(c(selected_ingredients, length(selected_ingredients))))
}

# Source scraping logic (for the Add Recipe tab)
source("R/scrape_recipe.R")
source("R/create_recipe_page.R")
