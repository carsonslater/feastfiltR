
source("R/scrape_recipe.R")
source("R/create_recipe_page.R")
library(yaml)

# List of recipes to scrape
urls <- c(
  "https://www.cookwell.com/recipe/chicken-posole-verde"
)

# Output directory
output_dir <- "cookbook"

# Initialize list of generated files
generated_files <- c("index.qmd")

for (url in urls) {
  message(paste("Scraping:", url))
  tryCatch({
    recipe <- scrape_recipe(url)
    create_recipe_page(recipe, output_dir)
    
    # Add to list of files
    filename <- paste0(tolower(gsub("[^a-zA-Z0-9]+", "-", recipe$title)), ".qmd")
    generated_files <- c(generated_files, filename)
    
  }, error = function(e) {
    message(paste("Failed to scrape:", url))
    message(e$message)
  })
}

# Update _quarto.yml
config_path <- file.path(output_dir, "_quarto.yml")
if (file.exists(config_path)) {
  config <- read_yaml(config_path)
  config$book$chapters <- generated_files
  
  # Custom handler to ensure booleans are written as true/false, not yes/no
  write_yaml(config, config_path, handlers = list(
    logical = function(x) {
      result <- ifelse(x, "true", "false")
      class(result) <- "verbatim"
      return(result)
    }
  ))
  message("Updated _quarto.yml with new chapters.")
} else {
  warning("_quarto.yml not found!")
}
