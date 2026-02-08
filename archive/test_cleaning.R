source("R/ingredient_utils.R")

test_strings <- c(
    "2 1/2 cup bread flour",
    "2 cup all purpose flour",
    "2 cup almond breeze almondmilk coconutmilk original unsweetened http://www.almondbreeze.com/navid-329/pid-508",
    "2 cup almond milk vanilla sweetened",
    "1 cup silk oatmilk",
    "2 green onions (chopped)",
    "1/2 teaspoon salt",
    "1.5 lbs chicken breast, sliced",
    "½ cup butter"
)

cat("--- Testing clean_ingredient function ---\n")
for (s in test_strings) {
    clean <- clean_ingredient(s)
    cat(sprintf("Original: '%s'\nCleaned:  '%s'\n\n", s, clean))
}
