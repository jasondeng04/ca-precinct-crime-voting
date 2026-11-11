# Runs the whole project from the repo root:
#   Rscript run_all.R
# Set CRIME_VOTING_DATA first if the data is not in ./data

source("R/01_build_data.R")
source("R/02_regressions.R")
source("R/03_maps.R")
