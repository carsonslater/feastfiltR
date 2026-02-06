#!/usr/bin/env Rscript

# Get port from environment variable or use default
port <- as.numeric(Sys.getenv("SHINY_PORT", unset = "8888"))
host <- Sys.getenv("SHINY_HOST", unset = "127.0.0.1")

message(paste0("Starting feastfiltR on ", host, ":", port))

# Run the app
shiny::runApp(
    appDir = ".",
    port = port,
    host = host,
    launch.browser = FALSE
)
