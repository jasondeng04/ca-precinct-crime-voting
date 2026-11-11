# 02_regressions.R
# Runs every specification for all six cities and saves the tables
# to output/tables/ (one markdown file per specification, plus a CSV
# of every coefficient).

source("R/00_setup.R")
source("R/functions.R")

city_data <- readRDS(file.path(out_dir, "city_data.rds"))
models    <- map(city_data, ~ run_models(.x$df))

coef_map <- c(
  violent_shock_30     = "High violent crime (top 10%, last 30 days)",
  violent_pm_30        = "Violent crime per month per 1,000 (last 30 days)",
  theft_pm_30          = "Theft per month per 1,000 (last 30 days)",
  violent_pm_1y_excl30 = "Violent crime per month per 1,000 (31-365 days before)",
  theft_pm_1y_excl30   = "Theft per month per 1,000 (31-365 days before)",
  violent_pm_5y_excl1y = "Violent crime per month per 1,000 (1-5 years before)",
  theft_pm_5y_excl1y   = "Theft per month per 1,000 (1-5 years before)",
  trump_share          = "Trump vote share (2024)",
  `(Intercept)`        = "Constant"
)

titles <- c(
  turnout_30          = "Turnout (pp) ~ crime in the last 30 days",
  turnout_1y          = "Turnout (pp) ~ crime 31-365 days before",
  turnout_5y          = "Turnout (pp) ~ crime 1-5 years before",
  turnout_violent_all = "Turnout (pp) ~ violent crime across all windows",
  turnout_theft_all   = "Turnout (pp) ~ theft across all windows",
  turnout_shock       = "Turnout (pp) ~ violent crime spike (top 10%, last 30 days)",
  prop36_30           = "Prop 36 yes (pp) ~ crime in the last 30 days",
  prop36_1y           = "Prop 36 yes (pp) ~ crime 31-365 days before",
  prop36_5y           = "Prop 36 yes (pp) ~ crime 1-5 years before",
  prop36_violent_all  = "Prop 36 yes (pp) ~ violent crime across all windows",
  prop36_theft_all    = "Prop 36 yes (pp) ~ theft across all windows",
  prop36_shock        = "Prop 36 yes (pp) ~ violent crime spike (top 10%, last 30 days)"
)

# One table per specification, cities as columns
for (spec in names(titles)) {
  modelsummary(
    map(models, spec),
    coef_map  = coef_map,
    stars     = TRUE,
    statistic = "({std.error})",
    gof_omit  = "AIC|BIC|Log.Lik|RMSE",
    title     = titles[[spec]],
    output    = file.path(tables_dir, paste0(spec, ".md"))
  )
}

# Every coefficient in one long CSV
coefs <- imap_dfr(models, function(city_models, city) {
  imap_dfr(city_models, ~ broom::tidy(.x) %>% mutate(city = city, spec = .y))
}) %>%
  select(city, spec, term, estimate, std.error, statistic, p.value)

write_csv(coefs, file.path(tables_dir, "all_coefficients.csv"))

# The headline result: Prop 36 support in precincts with a violent-crime spike
coefs %>%
  filter(spec == "prop36_shock", term == "violent_shock_30") %>%
  mutate(across(where(is.numeric), ~ round(., 3))) %>%
  print()
