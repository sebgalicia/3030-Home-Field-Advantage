# 02_clean.R
# Filter and tidy the raw games; save the result to data/clean/.

library(tidyverse)
library(here)

# Assumed temperature (deg F) for games played indoors where the raw data has none
indoor_temp <- 70

schedules <- read_csv(here("data", "raw", "nfl_schedules_1999_2025.csv"), show_col_types = FALSE)
stadiums <- read_csv(here("data", "raw", "stadiums", "stadiums.csv"), show_col_types = FALSE) |>
  select(stadium_id, stadium_lat = lat, stadium_lon = lon, stadium_altitude_m = altitude)

# Map relocated franchises to their current team code
current_code <- c(OAK = "LV", SD = "LAC", STL = "LA")
to_franchise <- function(x) coalesce(unname(current_code[x]), x)

# Each team's regular-season record entering every game (including neutral-site
# games, which count toward records). Playoff games get the full regular-season record.
team_games <- bind_rows(
  schedules |> transmute(game_id, season, week, game_type, team = home_team, pts_for = home_score, pts_against = away_score,
                         venue = if_else(location == "Neutral", "neutral", "home")),
  schedules |> transmute(game_id, season, week, game_type, team = away_team, pts_for = away_score, pts_against = home_score,
                         venue = if_else(location == "Neutral", "neutral", "away"))
)

records <- team_games |>
  mutate(
    reg = game_type == "REG",
    won = reg & pts_for > pts_against,
    lost = reg & pts_for < pts_against,
    tied = reg & pts_for == pts_against
  ) |>
  arrange(season, team, week) |>
  group_by(season, team) |>
  mutate(
    wins = cumsum(won) - won,
    losses = cumsum(lost) - lost,
    ties = cumsum(tied) - tied,
    win_pct = if_else(wins + losses + ties > 0, (wins + 0.5 * ties) / (wins + losses + ties), NA_real_)
  ) |>
  ungroup() |>
  select(game_id, team, wins, losses, ties, win_pct)

home_records <- records |>
  rename(home_team = team, home_wins = wins, home_losses = losses, home_ties = ties, home_win_pct = win_pct)
away_records <- records |>
  rename(away_team = team, away_wins = wins, away_losses = losses, away_ties = ties, away_win_pct = win_pct)

# Each franchise's final regular-season win % from the previous season
# (missing for 1999 and for expansion years)
prev_season <- team_games |>
  filter(game_type == "REG") |>
  group_by(franchise = to_franchise(team), season) |>
  summarise(prev_win_pct = (sum(pts_for > pts_against) + 0.5 * sum(pts_for == pts_against)) / n(), .groups = "drop") |>
  mutate(season = season + 1)

home_prev <- prev_season |> rename(home_franchise = franchise, home_prev_win_pct = prev_win_pct)
away_prev <- prev_season |> rename(away_franchise = franchise, away_prev_win_pct = prev_win_pct)

games <- schedules |>
  filter(location != "Neutral") |>
  mutate(
    is_playoff = game_type != "REG",
    home_franchise = to_franchise(home_team),
    away_franchise = to_franchise(away_team),
    is_tie = result == 0,
    home_win = as.integer(result > 0),
    # closed-roof games are played indoors; open-roof games are not
    is_indoor = roof %in% c("dome", "closed"),
    temp = if_else(is_indoor & is.na(temp), indoor_temp, temp),
    wind = if_else(is_indoor & is.na(wind), 0, wind)
  ) |>
  left_join(stadiums, by = "stadium_id") |>
  left_join(home_records, by = c("game_id", "home_team")) |>
  left_join(away_records, by = c("game_id", "away_team")) |>
  left_join(home_prev, by = c("season", "home_franchise")) |>
  left_join(away_prev, by = c("season", "away_franchise")) |>
  select(
    game_id, old_game_id, season, game_type, is_playoff, week, gameday,
    home_team, away_team, home_franchise, away_franchise,
    home_score, away_score, result, total, home_win, is_tie, overtime,
    home_wins, home_losses, home_ties, home_win_pct,
    away_wins, away_losses, away_ties, away_win_pct,
    home_prev_win_pct, away_prev_win_pct,
    home_rest, away_rest, div_game, spread_line, total_line,
    roof, is_indoor, surface, temp, wind,
    stadium_id, stadium, stadium_lat, stadium_lon, stadium_altitude_m
  )

stopifnot(!anyDuplicated(games$game_id))

write_csv(games, here("data", "clean", "games.csv"))

# One row per team per regular season: overall, home and away results.
# Overall win % includes neutral-site games; the home/away splits do not.
team_seasons <- team_games |>
  filter(game_type == "REG") |>
  mutate(
    franchise = to_franchise(team),
    win = (pts_for > pts_against) + 0.5 * (pts_for == pts_against),
    margin = pts_for - pts_against
  ) |>
  group_by(team, franchise, season) |>
  summarise(
    games = n(),
    win_pct = mean(win),
    avg_margin = mean(margin),
    home_games = sum(venue == "home"),
    home_win_pct = mean(win[venue == "home"]),
    home_margin = mean(margin[venue == "home"]),
    away_games = sum(venue == "away"),
    away_win_pct = mean(win[venue == "away"]),
    away_margin = mean(margin[venue == "away"]),
    .groups = "drop"
  ) |>
  mutate(
    hfa_win_pct = home_win_pct - away_win_pct,
    hfa_margin = home_margin - away_margin
  )

write_csv(team_seasons, here("data", "clean", "team_seasons.csv"))
