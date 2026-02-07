source("global.R")

# Define UI
ui <- tagList(
    useShinyjs(),
    page_navbar(
        title = "feastfiltR",
        theme = bs_theme(
            version = 5,
            bootswatch = "lux",
            primary = "#2c3e50",
            secondary = "#95a5a6",
            base_font = font_google("Inter"),
            heading_font = font_google("Outfit")
        ),
        nav_panel(
            title = "Recipe Finder",
            icon = icon("search"),
            layout_sidebar(
                sidebar = sidebar(
                    width = 350,
                    title = "What's in your fridge?",
                    selectizeInput(
                        "ingredients_filter",
                        "Select Ingredients",
                        choices = NULL, # Populated on server
                        multiple = TRUE,
                        options = list(
                            placeholder = "Type to search ingredients...",
                            onInitialize = I('function() { this.setValue(""); }')
                        )
                    ),
                    hr(),
                    helpText("Selected recipes will contain ALL ingredients chosen above."),
                    actionButton("clear_filters", "Clear All", icon = icon("times"), class = "btn-outline-secondary btn-sm")
                ),
                card(
                    full_screen = TRUE,
                    card_header("Matching Recipes"),
                    DTOutput("recipe_table")
                )
            )
        ),
        nav_panel(
            title = "Let's Cook!",
            icon = icon("utensils"),
            uiOutput("recipe_detail_view")
        ),
        nav_panel(
            title = "Add Recipe",
            icon = icon("plus-circle"),
            card(
                width = "600px",
                style = "margin: 20px auto;",
                card_header("Import New Recipe"),
                card_body(
                    textInput("recipe_url", "Recipe URL", placeholder = "https://..."),
                    actionButton("scrape_btn", "Scrape & Add", icon = icon("download"), class = "btn-primary"),
                    br(), br(),
                    uiOutput("scrape_status")
                )
            )
        )
    )
)

# Define Server
server <- function(input, output, session) {
    # Populate ingredients on start
    updateSelectizeInput(
        session, "ingredients_filter",
        choices = get_all_ingredients(),
        server = TRUE
    )

    # Reactive values to hold state
    vals <- reactiveValues(
        selected_recipe_id = NULL
    )

    # Clear filters
    observeEvent(input$clear_filters, {
        updateSelectizeInput(session, "ingredients_filter", selected = character(0))
    })

    # Recipe Search
    filtered_recipes <- reactive({
        req(input$ingredients_filter)
        search_recipes(input$ingredients_filter)
    })

    # Render Table
    output$recipe_table <- renderDT({
        data <- if (length(input$ingredients_filter) == 0) {
            dbGetQuery(con, "SELECT id, title, prep_time, cook_time, total_time FROM recipes ORDER BY title")
        } else {
            filtered_recipes() %>% select(id, title, prep_time, cook_time, total_time)
        }

        datatable(
            data,
            selection = "single",
            options = list(pageLength = 10, dom = "ftp"),
            rownames = FALSE,
            colnames = c("ID", "Recipe Name", "Prep", "Cook", "Total")
        )
    })

    # Handle Selection
    observeEvent(input$recipe_table_rows_selected, {
        data <- if (length(input$ingredients_filter) == 0) {
            dbGetQuery(con, "SELECT id, title, prep_time, cook_time, total_time FROM recipes ORDER BY title")
        } else {
            filtered_recipes() %>% select(id, title, prep_time, cook_time, total_time)
        }

        row_idx <- input$recipe_table_rows_selected
        vals$selected_recipe_id <- data$id[row_idx]

        # Switch to Let's Cook tab
        nav_select("Let's Cook!")
    })

    # Recipe Detail View
    output$recipe_detail_view <- renderUI({
        req(vals$selected_recipe_id)

        # Get recipe details
        recipe <- dbGetQuery(con, "SELECT * FROM recipes WHERE id = ?", params = list(vals$selected_recipe_id))
        ingredients_list <- dbGetQuery(con, "SELECT ingredient FROM ingredients WHERE recipe_id = ?", params = list(vals$selected_recipe_id))$ingredient
        instructions <- fromJSON(recipe$instructions)

        layout_columns(
            col_widths = c(4, 8),
            card(
                card_header(recipe$title),
                if (!is.na(recipe$image_path)) {
                    # Image path fix: serving from 'images' resource path
                    img(src = recipe$image_path, style = "width: 100%; border-radius: 8px;")
                } else {
                    div("No image available", class = "text-muted text-center p-4")
                },
                hr(),
                p(icon("clock"), " Prep: ", recipe$prep_time),
                p(icon("fire"), " Cook: ", recipe$cook_time),
                p(icon("hourglass-half"), " Total: ", recipe$total_time)
            ),
            card(
                card_header("Details"),
                navset_card_pill(
                    nav_panel(
                        "Ingredients",
                        tags$ul(lapply(ingredients_list, tags$li))
                    ),
                    nav_panel(
                        "Instructions",
                        tags$ol(lapply(instructions, tags$li))
                    )
                )
            )
        )
    })

    # Scrape & Add
    observeEvent(input$scrape_btn, {
        req(input$recipe_url)
        output$scrape_status <- renderUI(div("Scraping...", class = "text-info"))

        tryCatch(
            {
                # Scrape
                recipe_data <- scrape_recipe(input$recipe_url)

                # Create page (for cookbook)
                create_recipe_page(recipe_data)

                # Update DB
                recipe_id <- tolower(gsub("[^a-zA-Z0-9]+", "-", recipe_data$title))

                # Connect for writing (global con is read-only)
                write_con <- dbConnect(duckdb::duckdb(), dbdir = db_path)

                dbExecute(write_con, "
        INSERT OR REPLACE INTO recipes (id, title, source_url, image_path, prep_time, cook_time, total_time, yield, instructions)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ", list(
                    recipe_id, recipe_data$title, input$recipe_url, NA,
                    recipe_data$prep_time, recipe_data$cook_time, recipe_data$total_time, NA,
                    toJSON(recipe_data$instructions)
                ))

                dbExecute(write_con, "DELETE FROM ingredients WHERE recipe_id = ?", list(recipe_id))
                for (ing in recipe_data$ingredients) {
                    clean_ing <- clean_ingredient(ing)
                    dbExecute(write_con, "INSERT INTO ingredients (recipe_id, ingredient, clean_ingredient) VALUES (?, ?, ?)", list(recipe_id, ing, clean_ing))
                }

                dbDisconnect(write_con, shutdown = TRUE)

                # Update selectize
                updateSelectizeInput(session, "ingredients_filter", choices = get_all_ingredients(), server = TRUE)

                output$scrape_status <- renderUI(div(paste("✓ Successfully added:", recipe_data$title), class = "text-success"))
            },
            error = function(e) {
                output$scrape_status <- renderUI(div(paste("✗ Error:", e$message), class = "text-danger"))
            }
        )
    })
}

# Run the application
shinyApp(ui = ui, server = server)
