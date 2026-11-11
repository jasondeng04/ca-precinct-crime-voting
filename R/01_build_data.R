# 01_build_data.R
# Builds one precinct-level data set per city and saves them all to
# output/city_data.rds (used by the regression and map scripts).

source("R/00_setup.R")
source("R/functions.R")

crimes_all <- readRDS(crime_rds)

city_data <- pmap(cities, function(key, label, county, city, crime_obj) {
  message("Building ", label, " ...")
  precincts <- read_precincts(county, city)
  df <- build_city_df(read_election(county, city), crimes_all[[crime_obj]], precincts)
  list(df = df, precincts = precincts)
}) %>%
  set_names(cities$key)

saveRDS(city_data, file.path(out_dir, "city_data.rds"))

# Quick summary of what went in
imap_dfr(city_data, ~ tibble(
  city             = .y,
  precincts        = nrow(.x$df),
  violent_30d      = sum(.x$df$violent_30),
  violent_1y       = sum(.x$df$violent_1y_excl30),
  violent_5y       = sum(.x$df$violent_5y_excl1y),
  mean_turnout_pp  = round(mean(.x$df$turnout_pp, na.rm = TRUE), 1),
  mean_prop36_pp   = round(mean(.x$df$prop36_yes_pp, na.rm = TRUE), 1)
)) %>%
  print() %>%
  write_csv(file.path(tables_dir, "data_summary.csv"))
