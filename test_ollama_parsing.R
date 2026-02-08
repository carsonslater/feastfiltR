library(httr2)
library(jsonlite)
source("R/ingredient_utils.R")

test_strings <- c(
    "2 1/2 cup bread flour",
    "2 cup all purpose flour",
    "2 cup almond milk vanilla sweetened",
    "2 green onions (chopped)",
    "1/2 teaspoon salt",
    "1.5 lbs chicken breast, sliced",
    "½ cup butter",
    "1 can (15 oz) black beans, drained and rinsed"
)

cat("--- Testing Ollama-based ingredient parsing ---\n")
for (s in test_strings) {
    cat(sprintf("Original: '%s'\n", s))

    parsed <- parse_ingredient_ollama(s)
    if (!is.null(parsed)) {
        cat("Parsed JSON components:\n")
        cat(jsonlite::toJSON(parsed, auto_unbox = TRUE, pretty = TRUE), "\n")

        clean_name <- clean_ingredient_ollama(s)
        cat(sprintf("Cleaned Name: '%s'\n", clean_name))
    } else {
        cat("Parsing failed.\n")
    }
    cat("--------------------------------------------\n")
}
