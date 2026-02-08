# feastfiltR: The Slater Family Cookbook

A modern recipe management and discovery tool. `feastfiltR` allows you to maintain a local database of your favorite recipes, search for what to cook based on the ingredients you have on hand, and view them in a beautiful desktop application.

![Recipe Finder UI](ui1.png)
![Recipe Detail View](ui2.png)

## Features

- **Ingredient-Based Discovery**: Use the "Recipe Finder" to select ingredients from your pantry and find matching recipes.
- **Local Recipe Viewer**: The "Let's Cook!" tab provides a clean, distraction-free view of your recipes with full instructions and images.
- **Smart Import**: The "Add Recipe" tab allows you to paste a URL and automatically scrape the recipe.
    - **Intelligent Parsing**: Uses **Ollama** (if available) to intelligently parse and clean ingredient lines.
    - **Fallback**: Robust regex-based cleaning if LLM services are offline.
- **DuckDB Backend**: Blazing fast SQL-based searching and structured data storage.
- **Desktop Experience**: Runs as a standalone macOS application.
- **Beautiful Exports**: Still maintains the ability to generate a Quarto PDF cookbook.

## Quick Start

### 1. Launch the Desktop App (Recommended)

This project includes a standalone macOS application bundle.

1.  Locate `feastfiltR.app` in the project root.
2.  Drag it to your **Applications** folder or keep it in the project directory.
3.  Double-click to launch!

### 2. Manual Launch (Developer Mode)

If you prefer to run the app from the terminal or are developing new features:

```zsh
# Run the Python wrapper directly (same as the App bundle)
./.venv/bin/python3 desktop_app.py
```

Or run the Shiny app directly via R:

```zsh
Rscript run_app.R
```

## Advanced Usage

### Manual PDF Generation

You can still render the static PDF cookbook using Quarto:
```zsh
quarto render cookbook
```

### Command Line Tools

The project includes several utility scripts in `scripts/` and `R/`:

- `R/recipe_workflow.R`: The core logic for processing new recipes.
- `R/scrape_recipe.R`: Functions to extract data from websites.
- `backfill_urls_v2.R`: Utility to fix or update source URLs in the database.

## Project Structure

- `feastfiltR.app/`: The macOS application bundle.
- `app.R`: Main Shiny application logic.
- `global.R`: App configuration and database connectivity.
- `desktop_app.py`: Python wrapper that launches the Shiny app in a webview window.
- `recipes.duckdb`: The central recipe database.
- `cookbook/`: Source `.qmd` files and images for the cookbook.
- `R/`: Core R functions (scraping, parsing, UI helpers).
- `scripts/`: specialized maintenance scripts.
