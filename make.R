# Master script to ensure reproducibility of, and enable updating of, paper results
# See https://books.ropensci.org/drake/projects.html#code-files


# Loads packages + functions----------------------------------------------

devtools::load_all()

# Create plan -------------------------------------------------------------

data_dir = "data/london-new"
sqf = file.path(data_dir, "london_bike_hire_2020-02-21.sqlite")

source("R/plan.R")


# settings ----------------------------------------------------------------

theme_set(theme_minimal(base_family = "Avenir Book"))


# make plan ---------------------------------------------------------------

vis_drake_graph(plan, targets_only = T)
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
# nrow(trips_df)
# fst::write.fst(trips_df, "trips_df_all.fst")
# system("ls -hl *.fst") # 1.2 GB
# piggyback::pb_upload("trips_df_all.fst")
# trips_df$date = as.Date(trips_df$start_time)
# most_recent_day = max(trips_df$date)
# most_recent_day
# trips_df_2019_12_31 = trips_df %>% filter(date == most_recent_day)
# readr::write_csv(trips_df_2019_12_31, "trips_df_2019_12_31.csv")
# piggyback::pb_upload("trips_df_2019_12_31.csv")
# system("ls -hal trips*") # 1 mb
# trips_df_1000 = sample_n(trips_df, 1000)
# readr::write_csv(trips_df_1000, "trips_df_1000.csv")
# piggyback::pb_upload("trips_df_1000.csv")
# lchs_recode(trips_df = trips_df_1000, stations = stations) # for quickfire results
# usethis::use_data(trips_df_1000)

# stations = readd(stations)
# saveRDS(stations)