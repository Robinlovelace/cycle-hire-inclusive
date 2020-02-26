plan = drake::drake_plan(
  # download_data = lchs_download(data_dir, sqf),
  # rename_data = lchs_rename(data_dir, sqf, files_to_rename = "2020"),
  # data_raw = target(lchs_read_raw(data_dir, sqf), format = "fst"),
  # save_raw_data = fst::write_fst(data_raw, "data_raw.fst", compress = 80), # commented to be faster
  data_raw = target(fst::read.fst("data_raw.fst"), format = "fst"),        # uncomment out for full dataset
  # data_raw = target(fst::read.fst("data_raw_5pc.fst"), format = "fst"),      # run on a 5% sample for reproducibility
  data_filtered = target(
    lchs_filter_select(data_raw)
    , format = "fst"),
  data_filtered_clean = lchs_clean(data_filtered),
  recoded_data = lchs_recode(trips_df = data_filtered_clean, stations = lchs_get_stations()),
  trips_df = recoded_data[[1]],
  stations = recoded_data[[2]],
  stations_sf = lchs_get_stations_sf(stations = stations),
  check_raw_data = source("code/cycle-hires-excel.R"), # fails, commented
  get_global_stations = source("code/get-global-stations.R"),
  stations_region = lchs_get_stations_region(stations_sf),
  stations_yearly = lchs_stations_yearly(stations_sf),
  stations_classification = rmarkdown::render(
    knitr_in("stations-classification.Rmd"),
    output_file = file_out("stations-classification.md")
    )
  # hist = create_plot(data),
  # fit = lm(Sepal.Width ~ Petal.Width + Species, data),
  # report = rmarkdown::render(
  #   knitr_in("README.Rmd"),
  #   output_file = file_out("README.md"),
  #   quiet = TRUE
  # )
)