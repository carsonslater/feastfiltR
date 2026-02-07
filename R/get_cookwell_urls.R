library(rvest)
library(purrr)
library(stringr)
library(httr)

#' Get Cookwell Recipe URLs
#'
#' Fetches and parses Cookwell sitemaps to find recipe post URLs.
#'
#' @param limit Maximum number of URLs to return. Defaults to NULL (all).
#' @return A character vector of recipe URLs.
#' @export
get_cookwell_urls <- function(limit = NULL) {
    sitemaps <- c(
        "https://www.cookwell.com/sitemap-0.xml",
        "https://www.cookwell.com/server-sitemap.xml"
    )

    recipe_urls <- c()

    for (sitemap_url in sitemaps) {
        cat("Processing sitemap:", sitemap_url, "\n")
        response <- GET(
            sitemap_url,
            user_agent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        )

        if (status_code(response) != 200) {
            warning(paste("Failed to fetch sitemap:", sitemap_url))
            next
        }

        s_xml <- read_html(content(response, as = "text"))
        urls <- s_xml %>%
            html_nodes("loc") %>%
            html_text()

        # Filter for potential recipes
        # Cookwell recipe URLs usually follow the pattern: https://www.cookwell.com/recipe/...
        urls <- urls[grepl("/recipe/", urls)]

        recipe_urls <- c(recipe_urls, urls)

        if (!is.null(limit) && length(recipe_urls) >= limit) {
            recipe_urls <- head(recipe_urls, limit)
            break
        }
    }

    return(unique(recipe_urls))
}
