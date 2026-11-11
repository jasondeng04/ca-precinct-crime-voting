# functions.R
# Helpers for loading the election data, counting crimes per precinct,
# and running the regressions.

# ---- Election data ----

# Precinct-to-city crosswalk for one county.
read_crosswalk <- function(county) {
  read_csv(file.path(sdb24_dir, paste0("c", county, "_g24_srprec_to_city.csv")),
           show_col_types = FALSE) %>%
    clean_names() %>%
    transmute(srprec = as.character(srprec), city)
}

# Keep only the precincts in one city (or all of them when city is NA).
filter_city <- function(df, county, city) {
  if (is.na(city)) return(df)
  df %>%
    left_join(read_crosswalk(county), by = "srprec") %>%
    filter(city == !!city) %>%
    select(-city)
}

# Raw statement-of-vote file for one county, cut down to one city.
read_election <- function(county, city) {
  read_csv(file.path(sdb24_dir, paste0("c", county, "_g24_sov_data_by_g24_srprec.csv")),
           show_col_types = FALSE) %>%
    clean_names() %>%
    mutate(srprec = as.character(srprec)) %>%
    filter_city(county, city)
}

# Turn raw vote counts into the outcome and control variables.
#   turnout_pp    = votes cast / registered voters * 100 (capped at 100)
#   prop36_yes_pp = yes / (yes + no) on Prop 36 * 100
#   trump_share   = Trump / (Trump + Harris), a continuous share from 0 to 1
clean_election <- function(df) {
  num_cols <- c("totreg", "totvote", "prsdem01", "prsrep01", "pr_36_y", "pr_36_n")

  df %>%
    mutate(across(all_of(num_cols),
                  ~ suppressWarnings(as.numeric(gsub(",", "", as.character(.)))))) %>%
    filter(!is.na(srprec), !is.na(totreg), totreg > 0, !is.na(totvote)) %>%
    mutate(
      turnout_pp    = 100 * pmin(totvote / totreg, 1),
      trump_share   = prsrep01 / (prsrep01 + prsdem01),
      prop36_yes_pp = 100 * pr_36_y / (pr_36_y + pr_36_n),
      across(c(trump_share, prop36_yes_pp), ~ ifelse(is.finite(.), ., NA_real_))
    )
}

# ---- Precinct shapes ----

read_precincts <- function(county, city) {
  st_read(file.path(sdb24_dir,
                    paste0("srprec_", county, "_g24_v01_shp"),
                    paste0("srprec_", county, "_g24_v01.shp")),
          quiet = TRUE) %>%
    st_transform(st_crs(proj_crs)) %>%
    mutate(srprec = as.character(srprec)) %>%
    filter_city(county, city) %>%
    select(srprec)
}

# ---- Crime counts ----

# Count crimes by type in each precinct between two dates (inclusive).
crime_in_window <- function(cr_pts, precincts, start_date, end_date) {
  cr_pts %>%
    filter(date >= start_date, date <= end_date) %>%
    st_join(precincts, join = st_within) %>%
    st_drop_geometry() %>%
    filter(!is.na(srprec)) %>%
    group_by(srprec) %>%
    summarise(
      violent = sum(crime_violent, na.rm = TRUE),
      theft   = sum(crime_theft,   na.rm = TRUE),
      drug    = sum(crime_drug,    na.rm = TRUE),
      other   = sum(crime_other,   na.rm = TRUE),
      .groups = "drop"
    )
}

# One row per precinct: election outcomes plus crime in three
# non-overlapping windows before the election.
#   _30        last 30 days                      (1 month)
#   _1y_excl30 day 31 to day 365 before          (11 months)
#   _5y_excl1y year 1 to year 5 before           (48 months)
# Rates are per month per 1,000 registered voters so the windows are comparable.
build_city_df <- function(elex_raw, cr_pts, precincts) {
  cr_pts <- cr_pts %>%
    mutate(date = as.Date(date)) %>%
    st_transform(st_crs(proj_crs))

  w30_start <- election_day - 30
  w1y_start <- election_day - 365
  w5y_start <- election_day - 5 * 365

  cr_30 <- crime_in_window(cr_pts, precincts, w30_start, election_day) %>%
    rename_with(~ paste0(.x, "_30"), -srprec)
  cr_1y <- crime_in_window(cr_pts, precincts, w1y_start, w30_start - 1) %>%
    rename_with(~ paste0(.x, "_1y_excl30"), -srprec)
  cr_5y <- crime_in_window(cr_pts, precincts, w5y_start, w1y_start - 1) %>%
    rename_with(~ paste0(.x, "_5y_excl1y"), -srprec)

  clean_election(elex_raw) %>%
    left_join(cr_30, by = "srprec") %>%
    left_join(cr_1y, by = "srprec") %>%
    left_join(cr_5y, by = "srprec") %>%
    mutate(
      across(matches("^(violent|theft|drug|other)_(30|1y_excl30|5y_excl1y)$"),
             ~ replace_na(., 0)),

      violent_pm_30        = 1000 * violent_30 / totreg,
      theft_pm_30          = 1000 * theft_30   / totreg,
      violent_pm_1y_excl30 = 1000 * violent_1y_excl30 / totreg / 11,
      theft_pm_1y_excl30   = 1000 * theft_1y_excl30   / totreg / 11,
      violent_pm_5y_excl1y = 1000 * violent_5y_excl1y / totreg / 48,
      theft_pm_5y_excl1y   = 1000 * theft_5y_excl1y   / totreg / 48,

      # 1 if the precinct is in the city's top 10% for violent crimes
      # in the 30 days before the election
      violent_shock_30 = as.integer(violent_30 >= quantile(violent_30, 0.90, na.rm = TRUE))
    )
}

# ---- Models ----

# All specifications for one city. Each controls for Trump vote share.
run_models <- function(df) {
  specs <- list(
    turnout_30          = turnout_pp ~ violent_pm_30 + theft_pm_30 + trump_share,
    turnout_1y          = turnout_pp ~ violent_pm_1y_excl30 + theft_pm_1y_excl30 + trump_share,
    turnout_5y          = turnout_pp ~ violent_pm_5y_excl1y + theft_pm_5y_excl1y + trump_share,
    turnout_violent_all = turnout_pp ~ violent_pm_30 + violent_pm_1y_excl30 + violent_pm_5y_excl1y + trump_share,
    turnout_theft_all   = turnout_pp ~ theft_pm_30 + theft_pm_1y_excl30 + theft_pm_5y_excl1y + trump_share,
    turnout_shock       = turnout_pp ~ violent_shock_30 + trump_share,

    prop36_30           = prop36_yes_pp ~ violent_pm_30 + theft_pm_30 + trump_share,
    prop36_1y           = prop36_yes_pp ~ violent_pm_1y_excl30 + theft_pm_1y_excl30 + trump_share,
    prop36_5y           = prop36_yes_pp ~ violent_pm_5y_excl1y + theft_pm_5y_excl1y + trump_share,
    prop36_violent_all  = prop36_yes_pp ~ violent_pm_30 + violent_pm_1y_excl30 + violent_pm_5y_excl1y + trump_share,
    prop36_theft_all    = prop36_yes_pp ~ theft_pm_30 + theft_pm_1y_excl30 + theft_pm_5y_excl1y + trump_share,
    prop36_shock        = prop36_yes_pp ~ violent_shock_30 + trump_share
  )
  map(specs, ~ lm(.x, data = df))
}
