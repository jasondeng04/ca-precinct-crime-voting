# Crime and Voting in California Precincts (2024)

Does recent crime near where people live change how they vote? This project
looks at the 2024 California general election in six cities (San Francisco,
San Jose, Los Angeles, Oakland, Sacramento, and San Diego) and asks whether
precincts with more crime before the election had different turnout or
different support for **Proposition 36**, which raised penalties for some
theft and drug crimes.

This was part of an undergraduate econometrics research project at Santa Clara
University (Econ 192), supervised by Professor William Sundstrom. The crime data was put
together by the research group; the code in this repo is my part of the work.

## Data

- **Election results:** 2024 precinct-level votes, precinct shapes, and the
  precinct-to-city crosswalk from the
  [California Statewide Database](https://statewidedatabase.org/).
- **Crime:** geocoded crime incidents from each city's public data, grouped
  into violent, theft, drug, and other.

The raw data is not in this repo. See [data/README.md](data/README.md) for
the files and layout the code expects.

## Method

1. **Match crimes to precincts.** Each crime point is placed in the precinct
   polygon that contains it (a spatial join with `sf`).
2. **Count crime in three windows before Election Day (Nov 5, 2024):**
   the last 30 days, 31 to 365 days before, and 1 to 5 years before.
   The windows do not overlap, so recent crime and long-run crime can be
   told apart.
3. **Put the counts on one scale:** crimes per month per 1,000 registered
   voters.
4. **Run OLS regressions** for each city, with turnout or Prop 36 "yes" share
   (in percentage points) as the outcome and Trump's 2024 vote share as a
   control for how conservative the precinct is.
5. **Spike test.** A dummy for precincts in the city's top 10% of violent
   crime in the last 30 days, to see if a sudden local spike mattered.

Outcomes:

- `turnout_pp` = votes cast / registered voters x 100
- `prop36_yes_pp` = yes / (yes + no) on Prop 36 x 100

## Results

- In **San Francisco and San Jose**, precincts in the top 10% of violent crime
  in the 30 days before the election had **lower** support for Prop 36, after
  controlling for Trump vote share.
- Maps of Prop 36 support, turnout, Trump share, and recent violent crime are
  written to `output/maps/` when the code is run.

## How to run

Requires R (4.3 or newer) and these packages:

```r
install.packages(c("tidyverse", "sf", "janitor", "modelsummary", "tmap", "broom"))
```

From the repo root:

```bash
Rscript run_all.R
```

or, if the data lives somewhere else:

```bash
CRIME_VOTING_DATA="/path/to/data" Rscript run_all.R
```

This writes:

- `output/tables/*.md`: one regression table per specification, cities as columns
- `output/tables/all_coefficients.csv`: every coefficient in one file
- `output/tables/data_summary.csv`: precinct and crime counts per city
- `output/maps/*.png`: maps of Prop 36 support, turnout, Trump share, and recent violent crime

## Files

| File | What it does |
|------|--------------|
| `R/00_setup.R` | Packages, paths, and the list of cities |
| `R/functions.R` | Loading, cleaning, crime counts, and the models |
| `R/01_build_data.R` | Builds one precinct-level data set per city |
| `R/02_regressions.R` | Runs the regressions and saves the tables |
| `R/03_maps.R` | Saves the maps |
| `run_all.R` | Runs all three steps |

## Limits

These are correlations, not causal effects. Precincts with more crime differ
in many ways (income, density, policing) that one control does not capture.
Rates use registered voters, not total population, so precincts with many
non-voters (for example, downtown or commercial areas) can show very high
crime rates.
