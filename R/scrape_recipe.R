library(rvest)
library(jsonlite)
library(purrr)
library(stringr)
library(lubridate)
library(httr)

#' Scrape Recipe Metadata
#'
#' Extracts recipe information from a URL, prioritizing Schema.org JSON-LD.
#'
#' @param url The URL of the recipe page.
#' @return A list containing title, image, time, ingredients, and instructions.
#' @export
scrape_recipe <- function(url) {
  # Use realistic browser headers to avoid being blocked
  response <- GET(
    url,
    user_agent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"),
    add_headers(
      "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
      "Accept-Language" = "en-US,en;q=0.9",
      "Accept-Encoding" = "gzip, deflate",
      "Connection" = "keep-alive",
      "Upgrade-Insecure-Requests" = "1",
      "Sec-Fetch-Dest" = "document",
      "Sec-Fetch-Mode" = "navigate",
      "Sec-Fetch-Site" = "none",
      "Sec-Fetch-User" = "?1",
      "Cache-Control" = "max-age=0"
    ),
    timeout(30) # 30 second timeout
  )

  if (status_code(response) != 200) {
    stop(paste("Failed to retrieve page. Status code:", status_code(response)))
  }

  page <- read_html(response)

  # 1. Try to find Schema.org JSON-LD
  json_ld_nodes <- page %>% html_nodes('script[type="application/ld+json"]')

  recipe_data <- NULL

  if (length(json_ld_nodes) > 0) {
    for (node in json_ld_nodes) {
      json_content <- html_text(node)
      # Handle potential parsing errors
      tryCatch(
        {
          data <- fromJSON(json_content, flatten = TRUE)

          # Check if it's a graph or a single object
          items <- NULL
          if ("@graph" %in% names(data)) {
            items <- data[["@graph"]]
          } else {
            items <- list(data)
          }

          if (is.data.frame(items)) {
            # If it's a data frame, find the row with @type "Recipe"
            if ("@type" %in% names(items)) {
              recipe_idx <- which(grepl("Recipe", as.character(items[["@type"]]), fixed = TRUE))
              if (length(recipe_idx) > 0) {
                # Convert row to list
                recipe_data <- as.list(items[recipe_idx[1], , drop = FALSE])
                # Clean up list-columns (nested data frames or lists)
                recipe_data <- lapply(recipe_data, function(v) {
                  if (is.list(v) && length(v) == 1 && is.data.frame(v[[1]])) {
                    return(v[[1]])
                  }
                  if (is.list(v) && length(v) == 1) {
                    return(v[[1]])
                  }
                  return(v)
                })
              }
            }
          } else if (is.list(items)) {
            # Find the item with @type "Recipe"
            recipe_item <- tryCatch(
              {
                keep(items, function(x) {
                  tryCatch(
                    {
                      if (is.null(x[["@type"]])) {
                        return(FALSE)
                      }
                      type_val <- x[["@type"]]
                      if (is.null(type_val) || length(type_val) == 0) {
                        return(FALSE)
                      }
                      type_str <- paste(as.character(type_val), collapse = " ")
                      grepl("Recipe", type_str, fixed = TRUE)
                    },
                    error = function(e) FALSE
                  )
                })
              },
              error = function(e) list()
            )

            if (length(recipe_item) > 0) {
              recipe_data <- recipe_item[[1]]
            }
          }

          if (!is.null(recipe_data)) break # Stop if we found a recipe
        },
        error = function(e) {
          # Continue to next node if parsing fails
        }
      )
    }
  }

  if (is.null(recipe_data)) {
    stop("Could not find Schema.org Recipe data on this page. Fallback scraping is not yet implemented.")
  }

  # 2. Extract fields
  decode_html <- function(text) {
    if (is.null(text) || length(text) == 0) {
      return(text)
    }
    # Use xml2 to decode entities by reading as HTML and extracting text
    sapply(text, function(x) {
      if (is.na(x) || x == "") {
        return(x)
      }
      tryCatch(
        {
          # Wrap in a tag to ensure valid XML fragment parsing
          node <- xml2::read_html(paste0("<html><body>", x, "</body></html>"))
          xml2::xml_text(xml2::xml_find_first(node, "//body"))
        },
        error = function(e) x
      )
    }, USE.NAMES = FALSE)
  }

  # Title
  raw_name <- as.character(recipe_data$name[1])
  # Fix common double-encoding or Latin-1 interpreted as UTF-8
  title <- decode_html(raw_name)
  title <- iconv(title, from = "UTF-8", to = "UTF-8", sub = "")

  # Image (can be string or list)
  image <- recipe_data$image
  if (is.list(image)) {
    if ("url" %in% names(image)) {
      image <- image$url
    } else {
      image <- unlist(image)[1] # Take first if multiple
    }
  }
  image <- as.character(image[1])
  # URL encode non-ASCII characters in image URL
  image <- URLencode(image)

  # Time
  # Parse ISO 8601 duration
  parse_duration_iso <- function(iso_duration) {
    if (is.null(iso_duration) || length(iso_duration) == 0 || is.na(iso_duration[1])) {
      return(NA)
    }
    # Take first element if it's a vector
    iso_duration <- as.character(iso_duration[1])
    d <- tryCatch(lubridate::duration(iso_duration), error = function(e) NA)
    if (is.na(d)) {
      return(iso_duration)
    } # Return raw string if parsing fails

    # Format nicely
    seconds <- as.numeric(d)
    hours <- floor(seconds / 3600)
    minutes <- floor((seconds %% 3600) / 60)

    time_str <- ""
    if (hours > 0) time_str <- paste0(hours, " hr ")
    if (minutes > 0) time_str <- paste0(time_str, minutes, " min")
    return(trimws(time_str))
  }

  prep_time <- parse_duration_iso(recipe_data$prepTime)
  cook_time <- parse_duration_iso(recipe_data$cookTime)
  total_time <- parse_duration_iso(recipe_data$totalTime)

  # Ingredients
  ingredients <- decode_html(as.character(unlist(recipe_data$recipeIngredient)))

  # Instructions
  instructions_raw <- recipe_data$recipeInstructions
  instructions <- NULL

  if (is.character(instructions_raw)) {
    instructions <- instructions_raw
  } else if (is.data.frame(instructions_raw)) {
    # often a list of steps with 'text' field
    if ("text" %in% names(instructions_raw)) {
      instructions <- instructions_raw$text
    }
  } else if (is.list(instructions_raw)) {
    # could be a list of HowToStep objects
    instructions <- sapply(instructions_raw, function(x) {
      tryCatch(
        {
          if (is.list(x) && "text" %in% names(x)) {
            text <- x$text
            # Handle case where text might be a vector
            if (length(text) > 1) {
              return(paste(text, collapse = " "))
            }
            return(as.character(text))
          }
          if (is.character(x)) {
            return(as.character(x))
          }
          return("")
        },
        error = function(e) {
          return("")
        }
      )
    })
  }

  # Clean up instructions
  instructions <- decode_html(as.character(instructions))
  instructions <- instructions[instructions != ""]

  list(
    title = title,
    url = url,
    image = image,
    prep_time = prep_time,
    cook_time = cook_time,
    total_time = total_time,
    ingredients = ingredients,
    instructions = instructions
  )
}
