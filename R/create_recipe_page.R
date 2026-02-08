#' Create Recipe Page
#'
#' Generates a Quarto markdown file for a recipe.
#'
#' @param recipe_data A list containing recipe metadata (title, image, time, ingredients, instructions).
#' @param output_dir The directory to save the .qmd file.
#' @export
create_recipe_page <- function(recipe_data, output_dir = "cookbook") {
  # Ensure title and image are scalar to avoid vectorization Issues
  title <- recipe_data$title[1]
  # image <- recipe_data$image[1] # This will be replaced by image_path_to_use

  # Create a filename from the title
  filename_base <- tolower(gsub("[^a-zA-Z0-9]+", "-", title))
  filename <- paste0(filename_base, ".qmd")
  filepath <- file.path(output_dir, filename)

  # 1. Download image locally for robust rendering
  image_url <- recipe_data$image[1]
  image_ext <- tools::file_ext(gsub("\\?.*$", "", image_url))
  if (image_ext == "") image_ext <- "jpg"

  image_filename <- paste0(filename_base, ".", image_ext)
  image_dir <- file.path(output_dir, "images")
  if (!dir.exists(image_dir)) dir.create(image_dir, recursive = TRUE)

  image_local_path <- file.path(image_dir, image_filename)
  image_rel_path <- file.path("images", image_filename)

  image_path_to_use <- image_url # Default to URL in case of download failure

  tryCatch(
    {
      # Download image if it doesn't exist locally
      if (!file.exists(image_local_path)) {
        message(paste("Downloading image:", image_url))
        # Ensure httr is loaded or use httr::GET explicitly
        if (!requireNamespace("httr", quietly = TRUE)) {
          stop("Package 'httr' needed for image download. Please install it with install.packages('httr').")
        }
        httr::GET(image_url, httr::write_disk(image_local_path, overwrite = TRUE), httr::timeout(15))
      }
      image_path_to_use <- image_rel_path
    },
    error = function(e) {
      message(paste("Warning: Failed to download image. Using URL instead.", e$message))
      image_path_to_use <- image_url
    }
  )

  # Format ingredients list
  ingredients <- recipe_data$ingredients
  ingredients <- ingredients[!is.na(ingredients)]
  ingredients_md <- paste(paste("-", ingredients), collapse = "\n")

  # Format instructions list - split multi-paragraph instructions into separate bullets
  instructions <- recipe_data$instructions
  instructions <- instructions[!is.na(instructions)]

  # Clean up common HBH artifacts like &nbsp; and non-breaking spaces
  instructions <- gsub("&nbsp;", " ", instructions)
  instructions <- gsub("\u00A0", " ", instructions)

  instructions_formatted <- unlist(lapply(instructions, function(instr) {
    # 1. Insert newlines before numbered steps that are embedded (e.g. "1. Step... 2. Step...")
    # Matches a period/question/exclamation followed by any whitespace and then a digit
    instr <- gsub("(?<=[.!\\?])\\s*([0-9]+\\.)", "\n\\1", instr, perl = TRUE)

    # 2. Split on newlines
    paragraphs <- strsplit(instr, "\n+")[[1]]
    # Trim whitespace and filter out empty strings
    paragraphs <- trimws(paragraphs)
    paragraphs <- paragraphs[paragraphs != ""]
    return(paragraphs)
  }))

  # Strip existing leading numbers to avoid "1. 1. Step"
  instructions_cleaned <- gsub("^[0-9]+\\s*\\.\\s*", "", instructions_formatted)

  instructions_md <- paste(paste("1.", instructions_cleaned), collapse = "\n")

  # Create YAML header
  yaml_header <- paste0(
    "---\n",
    "title: \"", title, "\"\n",
    "image: \"", image_path_to_use, "\"\n",
    "source_url: \"", if (is.null(recipe_data$url)) "" else recipe_data$url, "\"\n",
    "---\n"
  )

  # Create content
  # Ensure all other fields are scalar too
  prep_time <- if (is.null(recipe_data$prep_time) || is.na(recipe_data$prep_time[1])) "" else recipe_data$prep_time[1]
  cook_time <- if (is.null(recipe_data$cook_time) || is.na(recipe_data$cook_time[1])) "" else recipe_data$cook_time[1]
  total_time <- if (is.null(recipe_data$total_time) || is.na(recipe_data$total_time[1])) "" else recipe_data$total_time[1]

  content <- paste0(
    yaml_header,
    "\n",
    "![]( ", image_path_to_use, " ){width=100%}\n\n",
    "**Prep Time:** ", prep_time, " | ",
    "**Cook Time:** ", cook_time, " | ",
    "**Total Time:** ", total_time, "\n\n",
    "## Ingredients\n\n",
    ingredients_md,
    "\n\n",
    "## Instructions\n\n",
    instructions_md,
    "\n"
  )

  # Write to file with UTF-8 encoding
  con <- file(filepath, open = "w", encoding = "UTF-8")
  writeLines(content, con)
  close(con)
  message(paste("Created recipe page:", filepath))
}
