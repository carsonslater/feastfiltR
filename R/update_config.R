library(yaml)

#' Update Quarto Config
#'
#' Adds a recipe filename to the book chapters in _quarto.yml.
#'
#' @param filename The filename to add.
#' @param output_dir The directory containing _quarto.yml.
#' @export
update_quarto_config <- function(filename, output_dir = "cookbook") {
    config_path <- file.path(output_dir, "_quarto.yml")
    if (!file.exists(config_path)) {
        warning("_quarto.yml not found in ", output_dir)
        return(FALSE)
    }

    config <- read_yaml(config_path)

    # Add to chapters if not already there
    if (!filename %in% config$book$chapters) {
        config$book$chapters <- c(config$book$chapters, filename)

        # Write with custom handler for booleans
        write_yaml(config, config_path, handlers = list(
            logical = function(x) {
                result <- ifelse(x, "true", "false")
                class(result) <- "verbatim"
                return(result)
            }
        ))
        return(TRUE)
    }

    return(FALSE)
}
