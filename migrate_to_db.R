library(DBI)
library(duckdb)
library(yaml)
library(stringr)
library(jsonlite)
source("R/ingredient_utils.R")

# Paths
db_path <- "recipes.duckdb"
cookbook_dir <- "cookbook"

# Connect to database
con <- dbConnect(duckdb::duckdb(), dbdir = db_path)

# Function to parse a single .qmd file
parse_qmd <- function(filepath) {
    # Read as binary and convert to character to handle encoding issues
    raw_content <- tryCatch(readBin(filepath, "raw", file.info(filepath)$size), error = function(e) {
        return(NULL)
    })
    if (is.null(raw_content)) {
        return(NULL)
    }

    content <- iconv(rawToChar(raw_content), from = "", to = "UTF-8", sub = "")
    lines <- strsplit(content, "\n")[[1]]

    # Extract YAML frontmatter
    yaml_bounds <- which(lines == "---")
    if (length(yaml_bounds) < 2) {
        return(NULL)
    }

    yaml_content <- lines[(yaml_bounds[1] + 1):(yaml_bounds[2] - 1)]

    # Manual extraction for robustness
    extract_val <- function(key, lines) {
        line <- lines[grep(paste0("^", key, ":"), lines)]
        if (length(line) == 0) {
            return(NULL)
        }
        val <- sub(paste0("^", key, ":\\s*"), "", line[1])
        val <- gsub('^"|"$', "", val) # Remove quotes
        return(val)
    }

    title <- extract_val("title", yaml_content)
    image <- extract_val("image", yaml_content)
    source_url <- extract_val("source_url", yaml_content)

    if (is.null(title)) {
        return(NULL)
    }

    # Body content
    body <- lines[(yaml_bounds[2] + 1):length(lines)]
    body_text <- paste(body, collapse = "\n")

    # Extract Time info
    # Format: **Prep Time:** ... | **Cook Time:** ... | **Total Time:** ...
    time_line <- body[grep("\\*\\*Prep Time:\\*\\*", body)]
    prep_time <- ""
    cook_time <- ""
    total_time <- ""

    if (length(time_line) > 0) {
        prep_time <- str_match(time_line, "\\*\\*Prep Time:\\*\\*\\s*([^|]*)")[, 2] %>% trimws()
        cook_time <- str_match(time_line, "\\*\\*Cook Time:\\*\\*\\s*([^|]*)")[, 2] %>% trimws()
        total_time <- str_match(time_line, "\\*\\*Total Time:\\*\\*\\s*(.*)")[, 2] %>% trimws()
    }

    # Extract Ingredients
    ingredients <- c()
    ing_start <- grep("^## Ingredients", body)
    ing_end <- grep("^## Instructions", body)

    if (length(ing_start) > 0) {
        end_idx <- if (length(ing_end) > 0) ing_end - 1 else length(body)
        ing_lines <- body[(ing_start + 1):end_idx]
        ingredients <- str_match(ing_lines, "^-\\s*(.*)")[, 2]
        ingredients <- ingredients[!is.na(ingredients)]
    }

    # Extract Instructions
    instructions <- c()
    if (length(ing_end) > 0) {
        ins_lines <- body[(ing_end + 1):length(body)]
        instructions <- str_match(ins_lines, "^[0-9]+\\.\\s*(.*)")[, 2]
        instructions <- instructions[!is.na(instructions)]
    }

    # Yield (not usually in .qmd, but we can check if it's there)
    yield <- "" # Placeholder if we find it later

    list(
        id = tools::file_path_sans_ext(basename(filepath)),
        title = title,
        source_url = if (is.null(source_url) || source_url == "") NA else source_url,
        image_path = image,
        prep_time = if (is.null(prep_time)) "" else prep_time,
        cook_time = if (is.null(cook_time)) "" else cook_time,
        total_time = if (is.null(total_time)) "" else total_time,
        yield = yield,
        ingredients = ingredients,
        instructions = toJSON(instructions)
    )
}

# Get all .qmd files except index.qmd
qmd_files <- list.files(cookbook_dir, pattern = "\\.qmd$", full.names = TRUE)
qmd_files <- qmd_files[basename(qmd_files) != "index.qmd"]

cat("Found", length(qmd_files), "recipes to migrate.\n")

# Process each file
for (f in qmd_files) {
    recipe <- parse_qmd(f)
    if (is.null(recipe)) next

    cat("Migrating:", recipe$title, "\n")

    # Insert into recipes table
    dbExecute(con, "
    INSERT OR REPLACE INTO recipes (id, title, source_url, image_path, prep_time, cook_time, total_time, yield, instructions)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  ", list(
        recipe$id, recipe$title, recipe$source_url, recipe$image_path,
        recipe$prep_time, recipe$cook_time, recipe$total_time, recipe$yield,
        recipe$instructions
    ))

    # Insert into ingredients table
    # First clear old ingredients for this recipe
    dbExecute(con, "DELETE FROM ingredients WHERE recipe_id = ?", list(recipe$id))

    for (ing in recipe$ingredients) {
        clean_ing <- clean_ingredient(ing)
        dbExecute(con, "INSERT INTO ingredients (recipe_id, ingredient, clean_ingredient) VALUES (?, ?, ?)", list(recipe$id, ing, clean_ing))
    }
}

dbDisconnect(con, shutdown = TRUE)
cat("\nMigration complete!\n")
