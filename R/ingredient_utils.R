#' Clean an ingredient string to its core name
#'
#' Removes quantities, units, preparation adjectives, brands, and varieties.
#' Keeps descriptive types (e.g., "red onion").
#'
#' @param text The raw ingredient string
#' @return A cleaned version of the ingredient string
clean_ingredient <- function(text) {
  if (is.na(text) || text == "") {
    return(text)
  }

  # 1. Lowercase and trim
  cleaned <- tolower(trimws(text))

  # 2. Remove URLs
  cleaned <- gsub("http\\S+|www\\.\\S+", "", cleaned)

  # 3. Normalize fractions and weird characters
  cleaned <- gsub("½", " 1/2 ", cleaned)
  cleaned <- gsub("¼", " 1/4 ", cleaned)
  cleaned <- gsub("¾", " 3/4 ", cleaned)
  cleaned <- gsub("⅓", " 1/3 ", cleaned)
  cleaned <- gsub("⅔", " 2/3 ", cleaned)

  # 4. Remove parentheticals
  cleaned <- gsub("\\s*\\([^)]*\\)", "", cleaned)

  # 5. Remove leading quantities and measurement-related symbols
  last_cleaned <- ""
  while (last_cleaned != cleaned) {
    last_cleaned <- cleaned
    cleaned <- gsub("^[0-9\\s./-]+(\\b|\\s|$)", " ", cleaned)
    cleaned <- trimws(cleaned)
  }

  # 6. Normalize common ingredient names and remove brand names/varieties
  # Normalizations
  cleaned <- gsub("almondmilk", "almond milk", cleaned)
  cleaned <- gsub("coconutmilk", "coconut milk", cleaned)
  cleaned <- gsub("oatmilk", "oat milk", cleaned)
  cleaned <- gsub("soymilk", "soy milk", cleaned)

  # Brands and Variety Keywords (to be removed)
  junk <- c(
    "almond breeze", "silk", "chobani", "califia farms", "trader joes", "kirkland",
    "original", "unsweetened", "sweetened", "vanilla", "plain", "low fat", "low-fat",
    "full fat", "full-fat", "organic", "all natural", "all-natural", "pure"
  )
  junk_pattern <- paste0("\\b(", paste(junk, collapse = "|"), ")\\b")
  cleaned <- gsub(junk_pattern, "", cleaned)

  # 7. Remove common culinary units
  units <- c(
    "cup", "cups", "tbsp", "tablespoon", "tablespoons", "tsp", "teaspoon", "teaspoons",
    "oz", "ounce", "ounces", "lb", "lbs", "pound", "pounds", "g", "gram", "grams", "kg", "kilogram",
    "ml", "l", "liter", "liters", "can", "cans", "bottle", "bottles", "handful", "handfuls",
    "clove", "cloves", "sprig", "sprigs", "stalk", "stalks", "head", "heads", "bunch", "bunches",
    "package", "pkg", "container", "bags", "bag", "pint", "quart", "gallon", "stick", "sticks"
  )
  unit_pattern <- paste0("\\b(", paste(units, collapse = "|"), ")\\b")
  cleaned <- gsub(unit_pattern, "", cleaned)

  # 8. Remove preparation adjectives/verbs
  prep <- c(
    "chopped", "sliced", "diced", "minced", "grated", "shredded", "melted", "cubed",
    "crushed", "beaten", "softened", "prepared", "toasted", "roasted", "dried",
    "fresh", "freshly", "room temperature", "divided", "sifted", "peeled", "halved",
    "quartered", "seeded", "stemmed", "trimmed", "rinsed", "drained", "packed",
    "large", "medium", "small", "extra-large", "extra-small", "heaping", "leveled",
    "plus more", "for serving", "optional", "slid", "slided"
  )
  prep_pattern <- paste0("\\b(", paste(prep, collapse = "|"), ")\\b")
  cleaned <- gsub(prep_pattern, "", cleaned)

  # 9. Handle blends (if multiple milks remain, simplify to the first one)
  if (grepl("almond milk", cleaned) && grepl("coconut milk", cleaned)) {
    cleaned <- "almond milk"
  }

  # 10. Remove commas and everything after them
  cleaned <- gsub(",.*$", "", cleaned)

  # 11. Final cleanup: remove residual punctuation and normalize whitespace
  cleaned <- gsub("[[:punct:]]", " ", cleaned)
  cleaned <- trimws(gsub("\\s+", " ", cleaned))

  # 12. Final pass to strip any remaining leading numbers
  cleaned <- gsub("^[0-9]+\\s+", "", cleaned)

  return(cleaned)
}

#' Parse an ingredient string using Ollama (Gemma3:4b)
#'
#' @param text The raw ingredient string
#' @param model The Ollama model to use (default: "gemma3:4b")
#' @return A list with parsed components (name, amount, unit, prep)
parse_ingredient_ollama <- function(text, model = "gemma3:4b", verbose = FALSE) {
  if (is.na(text) || text == "") {
    return(NULL)
  }

  prompt <- paste0(
    "You are a culinary data extractor. Convert the following raw ingredient string into a structured JSON object.\n",
    "The JSON should have the following keys: 'name', 'amount', 'unit', 'prep'.\n\n",
    "Rules:\n",
    "- 'name' should be the core ingredient name (e.g., 'onion' not '2 onions').\n",
    "- 'amount' should be a number (convert fractions like '1/2' to 0.5; if no amount, use null).\n",
    "- 'unit' should be the measurement unit (e.g., 'cups', 'tbsp', 'oz', or null if not applicable).\n",
    "- 'prep' should be any preparation instructions (e.g., 'chopped', 'thinly sliced', or null if not applicable).\n\n",
    "Examples:\n",
    "- '2 1/2 cups chopped onions' -> {\"name\": \"onion\", \"amount\": 2.5, \"unit\": \"cups\", \"prep\": \"chopped\"}\n",
    "- '1 tbsp olive oil' -> {\"name\": \"olive oil\", \"amount\": 1, \"unit\": \"tbsp\", \"prep\": null}\n",
    "- '3 large eggs' -> {\"name\": \"egg\", \"amount\": 3, \"unit\": \"large\", \"prep\": null}\n",
    "- 'salt to taste' -> {\"name\": \"salt\", \"amount\": null, \"unit\": null, \"prep\": \"to taste\"}\n\n",
    "Input: '", text, "'\n",
    "Output (JSON only):"
  )

  tryCatch(
    {
      req <- httr2::request("http://localhost:11434/api/generate") %>%
        httr2::req_body_json(list(
          model = model,
          prompt = prompt,
          stream = FALSE,
          format = "json"
        )) %>%
        httr2::req_timeout(120) %>%
        httr2::req_retry(max_tries = 3)

      resp <- httr2::req_perform(req)
      body <- httr2::resp_body_json(resp)

      parsed <- jsonlite::fromJSON(body$response)
      return(parsed)
    },
    error = function(e) {
      warning(paste("Ollama parsing failed:", e$message))
      return(NULL)
    }
  )
}

#' Clean an ingredient string to its core name using Ollama
#'
#' @param text The raw ingredient string
#' @param parsed Optional pre-parsed list from parse_ingredient_ollama
#' @return A cleaned version of the ingredient string
clean_ingredient_ollama <- function(text, parsed = NULL) {
  if (is.null(parsed)) {
    parsed <- parse_ingredient_ollama(text)
  }

  # If parsing failed or returned invalid data, fallback to regex-based cleaning
  if (is.null(parsed) || is.null(parsed$name) || is.na(parsed$name) || as.character(parsed$name) == "") {
    return(clean_ingredient(text))
  }

  # Ensure name is a string and not a list or other object
  name_val <- parsed$name
  if (is.list(name_val)) {
    name_val <- name_val[[1]]
  }

  cleaned_name <- tolower(trimws(as.character(name_val)))

  if (cleaned_name == "") {
    return(clean_ingredient(text))
  }

  return(cleaned_name)
}
