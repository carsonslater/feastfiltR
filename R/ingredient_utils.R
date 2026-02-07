#' Clean an ingredient string to its core name
#' 
#' Removes quantities, units, and preparation adjectives.
#' Keeps descriptive types (e.g., "red onion").
#' 
#' @param text The raw ingredient string
#' @return A cleaned version of the ingredient string
clean_ingredient <- function(text) {
  if (is.na(text) || text == "") return(text)
  
  # 1. Lowercase and trim
  cleaned <- tolower(trimws(text))
  
  # 2. Remove parentheticals (instructions like "(chopped)")
  cleaned <- gsub("\\s*\\([^)]*\\)", "", cleaned)
  
  # 3. Remove leading quantities (numbers, fractions, etc.)
  # Handles "1 ", "1/2 ", "1.5 ", "2-3 "
  cleaned <- gsub("^(\\d+([./-]\\d+)?\\s*)+", "", cleaned)
  
  # 4. Remove common culinary units (case insensitive via step 1)
  units <- c(
    "cup", "cups", "tbsp", "tablespoon", "tablespoons", "tsp", "teaspoon", "teaspoons",
    "oz", "ounce", "ounces", "lb", "pound", "pounds", "g", "gram", "grams", "kg", "kilogram", 
    "ml", "l", "liter", "liters", "can", "cans", "bottle", "bottles", "handful", "handfuls",
    "clove", "cloves", "sprig", "sprigs", "stalk", "stalks", "head", "heads", "bunch", "bunches",
    "package", "pkg", "container", "bags", "bag"
  )
  unit_pattern <- paste0("\\b(", paste(units, collapse = "|"), ")\\b")
  cleaned <- gsub(unit_pattern, "", cleaned)
  
  # 5. Remove preparation adjectives/verbs
  # These are usually at the beginning or end after a comma
  prep <- c(
    "chopped", "sliced", "diced", "minced", "grated", "shredded", "melted", "cubed", 
    "crushed", "beaten", "softened", "prepared", "toasted", "roasted", "dried", 
    "fresh", "freshly", "room temperature", "divided", "sifted", "peeled", "halved", 
    "quartered", "seeded", "stemmed", "trimmed", "rinsed", "drained", "packed",
    "large", "medium", "small", "extra-large", "extra-small", "heaping", "leveled",
    "plus more", "for serving", "optional", "slid", "slided", "chopped", "diced", "cubed"
  )
  prep_pattern <- paste0("\\b(", paste(prep, collapse = "|"), ")\\b")
  cleaned <- gsub(prep_pattern, "", cleaned)
  
  # 6. Remove commas and everything after them (often additional instructions)
  cleaned <- gsub(",.*$", "", cleaned)
  
  # 7. Final cleanup of whitespace and punctuation
  cleaned <- gsub("[[:punct:]]", " ", cleaned) # Remove remaining punctuation
  cleaned <- trimws(gsub("\\s+", " ", cleaned)) # Normalize whitespace
  
  return(cleaned)
}
