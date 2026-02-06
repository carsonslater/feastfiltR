# Slater Family Cookbook

A tool to scrape recipes from websites and generate a beautifully formatted PDF cookbook using R and Quarto with the PrettyPDF theme.

## Quick Start

### Add a Recipe

Simply run the following command with a recipe URL:

```zsh
Rscript add_recipe.R <recipe_url>
```

**Example:**
```zsh
Rscript add_recipe.R https://www.cookwell.com/recipe/chicken-posole-verde
```

### Bulk Add from Half Baked Harvest

To scrape a batch of recipes from [Half Baked Harvest](https://www.halfbakedharvest.com):

```zsh
Rscript bulk_add_hbh_recipes.R <limit>
```

**Example:**
```zsh
Rscript bulk_add_hbh_recipes.R 20
```

### Generate the Cookbook PDF

After adding recipes, render the cookbook:

```zsh
quarto render cookbook
```

The PDF will be created at `cookbook/_book/Slater-Family-Cookbook.pdf`

## Features

- **Easy Recipe Addition**: One command to scrape and add individual recipes.
- **Bulk Scraping**: Automated URL discovery and batch processing for Half Baked Harvest.
- **Robust Extraction**: Handles complex JSON-LD structures (including `@graph` formats).
- **Beautiful PDF Output**: Custom theme with high-quality images and formatting.
- **Smart Formatting**: 
    - Automatically splits embedded instructions into numbered lists.
    - Decodes HTML entities in titles and ingredients.
    - Ensures UTF-8 encoding for reliable rendering.

## Project Structure

- `R/` - Core functions (scraper, page generator, URL discovery)
- `cookbook/` - Quarto book project
- `add_recipe.R` - Tools for adding individual recipes
- `bulk_add_hbh_recipes.R` - Automated discovery and bulk addition for HBH
- `generate_cookbook.R` - Template for manual batch generation
