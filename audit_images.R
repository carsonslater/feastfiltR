library(DBI)
library(duckdb)

# Connect to database
con <- dbConnect(duckdb::duckdb(), "recipes.duckdb")

# Get recipes
recipes <- dbGetQuery(con, "SELECT title, image_path FROM recipes")
dbDisconnect(con)

# Find missing image metadata
missing_metadata <- recipes[is.na(recipes$image_path) | recipes$image_path == "", ]

# Check for exists and size (146 bytes = placeholder/broken)
recipes$has_image_file <- FALSE
recipes$file_size <- NA

for (i in seq_len(nrow(recipes))) {
    path <- recipes$image_path[i]
    if (!is.na(path) && path != "") {
        # Check relative path from current dir (assuming app root)
        # image_path usually looks like 'images/filename.jpg' or similar
        # Based on previous work, real path is likely cookbook/images/filename.jpg
        full_path <- file.path("cookbook", path)
        if (file.exists(full_path)) {
            recipes$has_image_file[i] <- TRUE
            recipes$file_size[i] <- file.info(full_path)$size
        }
    }
}

# Define broken: either missing file or 146 bytes
recipes$is_broken <- !recipes$has_image_file | recipes$file_size == 146

broken_recipes <- recipes[recipes$is_broken, ]

cat(sprintf("Total Recipes: %d\n", nrow(recipes)))
cat(sprintf("Missing/Empty path: %d\n", nrow(missing_metadata)))
cat(sprintf("Broken/Placeholder images: %d\n", nrow(broken_recipes)))

write.csv(broken_recipes[, c("title", "image_path", "is_broken")], "image_audit_results.csv", row.names = FALSE)
