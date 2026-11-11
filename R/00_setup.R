# 00_setup.R
# Packages, file paths, and the list of cities in the study.
# Every other script sources this file first.

suppressPackageStartupMessages({
  library(tidyverse)
  library(sf)
  library(janitor)
  library(modelsummary)
  library(tmap)
})

sf_use_s2(FALSE)

# ---- Paths ----
# Point CRIME_VOTING_DATA at the folder that holds the raw data
# (see data/README.md for the expected layout). Defaults to ./data.
data_dir  <- Sys.getenv("CRIME_VOTING_DATA", "data")
sdb24_dir <- file.path(data_dir, "Statewide Database 2024")
crime_rds <- file.path(data_dir, "Crime data", "crimes_all.Rds")

out_dir    <- "output"
tables_dir <- file.path(out_dir, "tables")
maps_dir   <- file.path(out_dir, "maps")
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(maps_dir,   recursive = TRUE, showWarnings = FALSE)

# ---- Constants ----
election_day <- as.Date("2024-11-05")

# UTM zone 10N (meters). Used for the point-in-polygon joins.
# San Diego and part of LA sit in zone 11, but a small distortion
# does not change which precinct a point falls in.
proj_crs <- 32610

# ---- Cities ----
# county:    Statewide Database county code (c075 = San Francisco, ...)
# city:      name in the precinct-to-city crosswalk; NA = use the whole county
# crime_obj: name of the data frame inside crimes_all.Rds
cities <- tribble(
  ~key,  ~label,          ~county, ~city,         ~crime_obj,
  "SF",  "San Francisco", "075",   NA,            "crimes_sf",
  "SJ",  "San Jose",      "085",   "SAN JOSE",    "crimes_sj",
  "LA",  "Los Angeles",   "037",   "LOS ANGELES", "crimes_la",
  "OAK", "Oakland",       "001",   "OAKLAND",     "crimes_oak",
  "SAC", "Sacramento",    "067",   "SACRAMENTO",  "crimes_scto",
  "SD",  "San Diego",     "073",   "SAN DIEGO",   "crimes_sd"
)
