# 03_maps.R
# Choropleth maps for each city: Prop 36 support, turnout, Trump share,
# and violent crime in the last 30 days. Saved as PNGs in output/maps/.

source("R/00_setup.R")

city_data <- readRDS(file.path(out_dir, "city_data.rds"))
tmap_mode("plot")

# Some precincts include far-off islands (SF's Presidio precinct also holds
# the Farallon Islands, ~45 km offshore), which shrink the city to a corner
# of the map. For display only, drop polygon pieces that sit much farther
# from the city center than the rest.
drop_far_parts <- function(shapes) {
  parts  <- suppressWarnings(st_cast(shapes, "POLYGON"))
  cent   <- st_coordinates(suppressWarnings(st_centroid(parts)))
  center <- apply(cent, 2, median)
  dist   <- sqrt((cent[, 1] - center[1])^2 + (cent[, 2] - center[2])^2)
  parts[dist <= 3 * quantile(dist, 0.95), ]
}

map_vars <- c(
  prop36_yes_pp = "Prop 36 yes (%)",
  turnout_pp    = "Turnout (%)",
  trump_share   = "Trump share",
  violent_pm_30 = "Violent crimes per 1,000 voters (last 30 days)"
)

for (key in names(city_data)) {
  label <- cities$label[cities$key == key]
  shapes <- city_data[[key]]$precincts %>%
    inner_join(city_data[[key]]$df, by = "srprec") %>%   # drops water-only precincts
    drop_far_parts()

  for (v in names(map_vars)) {
    m <- tm_shape(shapes) +
      tm_polygons(
        fill        = v,
        fill.scale  = tm_scale_continuous(values = "brewer.yl_or_rd"),
        fill.legend = tm_legend(title = map_vars[[v]]),
        col         = "grey60",
        lwd         = 0.1
      ) +
      tm_title(paste0(label, ", 2024"))

    # base png() instead of tmap_save(), which needs cairo (XQuartz on macOS)
    png(file.path(maps_dir, paste0(tolower(key), "_", v, ".png")),
        width = 7, height = 7, units = "in", res = 150)
    print(m)
    dev.off()
  }
}
