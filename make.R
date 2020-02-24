# Master script to ensure reproducibility of, and enable updating of, paper results
# See https://books.ropensci.org/drake/projects.html#code-files


# Loads packages ----------------------------------------------------------

pkgs = c(
  "drake",
  "fasttime",
  "leaflet",
  "lubridate",
  "patchwork",
  "sf",
  "stplanr",
  "tidyverse",
  "tmap",
  "vroom"
)
lapply(pkgs, library, character.only = TRUE)


# Load functions ----------------------------------------------------------

source("R/get_london_cycle_hire_data.R")

# Create plan -------------------------------------------------------------

data_dir = "data/london-new"
sqf = file.path(data_dir, "london_bike_hire_2020-02-21.sqlite")

source("R/plan.R")

# make plan ---------------------------------------------------------------

vis_drake_graph(plan)
make(plan)
# 84950285 rows...
# make(plan, parallelism = "future", jobs = 2) # worked
# make(plan, parallelism = "clustermq", jobs = 2) # failed

# # debug(lchs_rename) # to debug
# undebug(lchs_rename)


# upload results ----------------------------------------------------------

# data_raw = readd(data_raw) 
# fst::write_fst(data_raw, "data_raw.fst", compress = 80)
# file.size("data_raw.fst") # 2.3 GB = too big!
# data_raw = fst::read.fst("data_raw.fst")
# piggyback::pb_upload("data_raw_5pc.fst")
# piggyback::pb_upload("data_raw.fst")
# piggyback::pb_download_url("data_raw_5pc.fst")

# data_filtered = readd(data_filtered, verbose = T)
# data_filtered_clean = readd(data_filtered_clean, verbose = T)
# fst::write_fst(data_filtered_clean, "data_filtered_clean.fst", compress = 80)
# piggyback::pb_upload("data_filtered_clean.fst")
# piggyback::pb_download_url("data_filtered_clean.fst")
# trips_df = readd(trips_df)
