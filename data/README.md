# Data

The raw data is not included in this repo. To run the code, put the files
below in this folder (or point the `CRIME_VOTING_DATA` environment variable
at a folder with the same layout).

```
data/
├── Statewide Database 2024/
│   ├── c{county}_g24_sov_data_by_g24_srprec.csv   # votes by precinct
│   ├── c{county}_g24_srprec_to_city.csv           # precinct -> city crosswalk
│   └── srprec_{county}_g24_v01_shp/               # precinct shapefile
│       └── srprec_{county}_g24_v01.shp (+ .dbf, .shx, .prj)
└── Crime data/
    └── crimes_all.Rds
```

County codes used: 001 Alameda (Oakland), 037 Los Angeles, 067 Sacramento,
073 San Diego, 075 San Francisco, 085 Santa Clara (San Jose).

## Election data

2024 general election, "SR" (statewide registration) precinct level, from the
[California Statewide Database](https://statewidedatabase.org/) at UC Berkeley:
the statement of vote file, the precinct-to-city conversion file, and the
SR precinct shapefile for each county.

Columns used: `srprec`, `TOTREG`, `TOTVOTE`, `PRSDEM01`, `PRSREP01`,
`PR_36_Y`, `PR_36_N`.

## Crime data

`crimes_all.Rds` is a named list of `sf` point data frames, one per city:
`crimes_sf`, `crimes_sj`, `crimes_la`, `crimes_oak`, `crimes_scto`, `crimes_sd`.
It was put together by our research group from each city's public crime
incident data. Each row is one incident with these columns:

| column          | type        | meaning                     |
|-----------------|-------------|-----------------------------|
| `date`          | Date        | incident date               |
| `year`          | integer     | incident year               |
| `crime_violent` | 0/1         | violent crime               |
| `crime_theft`   | 0/1         | theft                       |
| `crime_drug`    | 0/1         | drug offense                |
| `crime_other`   | 0/1         | anything else               |
| `geometry`      | POINT       | incident location           |
