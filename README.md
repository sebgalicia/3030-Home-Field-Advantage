# NFL Home Field Advantage

ISYE 3030 class project analyzing home field advantage in the NFL.

## Group members

- Sebastian
- Quinn
- Ethan
- Luke

## Dependencies

Requires R 4.6 or newer. Install the packages once per computer:

```r
install.packages(c("tidyverse", "nflreadr", "here", "geosphere", "broom", "janitor"))
```

| Package | Used for |
|---|---|
| tidyverse | Data wrangling (dplyr, tidyr, readr) and plotting (ggplot2) |
| nflreadr | Downloading NFL schedules and game results |
| here | File paths relative to the project root |
| geosphere | Travel distance between stadiums |
| broom | Tidy tables of model results |
| janitor | Cleaning column names and quick frequency tables |

Optional, for VS Code users only: `install.packages(c("languageserver", "httpgd"))`
for autocomplete and the plot viewer.

## Folder structure

```
data/raw/        original downloaded data (read-only, never edit)
data/clean/      shared cleaned data made by R/02_clean.R
R/               shared scripts: load and clean the data
R/members/<name>.R  each person's own script: features, analysis, and plots
output/figures/  figures picked for the final report
```

## Saving output

Results only show on screen unless you save them. Save to `output/` using `here()`:

```r
# Plot -> PNG (assign the plot to a variable so you can save it)
p <- ggplot(games, aes(season, home_win)) + geom_col()
ggsave(here("output", "figures", "home_win_by_season.png"), p, width = 7, height = 5)

# Table or model results -> CSV
write_csv(results, here("output", "results.csv"))
write_csv(broom::tidy(model), here("output", "model_results.csv"))
```

Name files so it is clear who made them, e.g. `sebastian_altitude_plot.png`.

## Run order

1. `R/01_load.R`: download and save raw data to `data/raw/` (already done; data is in the repo)
2. `R/02_clean.R`: filter and tidy games into `data/clean/`
3. Your own script, `R/members/<name>.R` (features, then analysis, then plots)

Open the project with `nfl-home-adv.Rproj` (RStudio) or open this folder in VS Code.
