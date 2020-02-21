plan = drake_plan(
  # download_data = lchs_download(data_dir, sqf),
  # rename_data = lchs_rename(data_dir, sqf, files_to_rename = "2020"),
  # data_raw = target(lchs_read_raw(data_dir, sqf), format = "fst"),
  # save_raw_data = fst::write_fst(data_raw, "data_raw.fst", compress = 80), # commented to be faster
  # data_raw = target(fst::read.fst("data_raw.fst"), format = "fst"),        # comment out for full dataset
  data_raw = target(fst::read.fst("data_raw_5pc.fst"), format = "fst"),      # run on a 5% sample for reproducibility
  data_filtered = target(
    lchs_filter_select(data_raw)
    , format = "fst"),
  data_filtered_clean = lchs_clean(data_filtered)
  # check_raw_data = 
  # data = raw_data %>%
  #   mutate(Species = forcats::fct_inorder(Species)),
  # hist = create_plot(data),
  # fit = lm(Sepal.Width ~ Petal.Width + Species, data),
  # report = rmarkdown::render(
  #   knitr_in("report.Rmd"),
  #   output_file = file_out("report.html"),
  #   quiet = TRUE
  # )
)