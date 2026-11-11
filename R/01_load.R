# 01_load.R
# Download raw data for the project and save it, unchanged, to data/raw/.
# Download and save only: no cleaning, filtering, or joining happens here.

redownload <- FALSE   # set TRUE to re-download files that already exist

# ---- Packages (install only what's missing) --------------------------------
pkgs <- c("here", "readr", "nflreadr")
missing <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(missing)) install.packages(missing)

library(here)
library(readr)

raw_dir <- here("data", "raw")
dir.create(here(raw_dir, "stadiums"), recursive = TRUE, showWarnings = FALSE)
dir.create(here(raw_dir, "weather"),  recursive = TRUE, showWarnings = FALSE)

# Downloads `url` to `dest` unless it already exists (and redownload is FALSE).
# Failures are reported and skipped so the rest of the script keeps going.
fetch <- function(url, dest) {
  if (file.exists(dest) && !redownload) {
    message("Skip (exists): ", dest)
    return(invisible(TRUE))
  }
  tryCatch({
    download.file(url, dest, mode = "wb", quiet = TRUE)
    message("Downloaded: ", dest)
    invisible(TRUE)
  }, error = function(e) {
    if (file.exists(dest)) file.remove(dest)   # don't leave a partial file
    message("FAILED: ", url, "\n  ", conditionMessage(e))
    invisible(FALSE)
  })
}

options(timeout = max(300, getOption("timeout")))   # allow slow downloads

# ---- 1a. NFL games: Item Response Warehouse --------------------------------
# Page: https://itemresponsewarehouse.org/tables/nflverse_nfl_1999_2025/
# The page's "Download CSV" link (hosted on Redivis, no account needed).
# One row per game with the home team as agent_a. License: CC BY 4.0.
fetch(
  "https://redivis.com/api/v1/tables/datapages.irw_competitions:v7_1.nflverse_nfl_1999_2025/rows?format=csv",
  here(raw_dir, "irw_nfl_1999_2025.csv")
)

# ---- 1b. NFL games: nflverse schedules (backup / fuller version) -----------
# Source: https://github.com/nflverse/nflverse-data (via nflreadr::load_schedules)
sched_dest <- here(raw_dir, "nfl_schedules_1999_2025.csv")
if (file.exists(sched_dest) && !redownload) {
  message("Skip (exists): ", sched_dest)
} else {
  tryCatch({
    write_csv(nflreadr::load_schedules(1999:2025), sched_dest)
    message("Downloaded: ", sched_dest)
  }, error = function(e) message("FAILED: nflreadr::load_schedules\n  ", conditionMessage(e)))
}

# ---- 2. Stadium data -------------------------------------------------------
# Repo: https://github.com/greerreNFL/stadiums  (files in data/ on branch main)
stadium_base  <- "https://raw.githubusercontent.com/greerreNFL/stadiums/main/data/"
stadium_files <- c(
  "stadiums.csv",            # one row per stadium: location, altitude, roof, surface
  "team_stadiums.csv",       # team -> home stadium mapping (stadium info joined in)
  "rolling_team_hfa.csv",    # rolling Elo-based home field advantage by team/week
  "rolling_league_hfa.csv"   # rolling Elo-based home field advantage, league-wide
)
for (f in stadium_files) fetch(paste0(stadium_base, f), here(raw_dir, "stadiums", f))

# ---- 3. Weather data -------------------------------------------------------
# Repo: https://github.com/ThompsonJamesBliss/WeatherData  (data/ on branch master)
# Covers seasons 2000-2020 only.
weather_base  <- "https://raw.githubusercontent.com/ThompsonJamesBliss/WeatherData/master/data/"
weather_files <- c(
  "games.csv",               # game_id, season, stadium, start/end time
  "games_weather.csv",       # hourly weather readings per game
  "stadium_coordinates.csv"  # stadium lat/long, roof type, field orientation
)
for (f in weather_files) fetch(paste0(weather_base, f), here(raw_dir, "weather", f))

message("Done.")
