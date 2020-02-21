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

plan = drake_plan(
  # download_data = lchs_download(data_dir, sqf),
  # rename_data = lchs_rename(data_dir, sqf, files_to_rename = "2020"),
  # data_raw = lchs_read_raw(data_dir, sqf),
  # data_raw = target(lchs_read_raw(data_dir, sqf), format = "fst"), # fast version
  # save_raw_data = fst::write_fst(data_raw, "data_raw.fst", compress = 80), # commented to be faster
  data_raw = target(fst::read.fst("data_raw.fst"), format = "fst"),
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



# make plan ---------------------------------------------------------------

# vis_drake_graph(plan)
make(plan)
# 84950285 rows...
# make(plan, parallelism = "future", jobs = 2) # worked
# make(plan, parallelism = "clustermq", jobs = 2) # failed

# # debug(lchs_rename) # to debug
# undebug(lchs_rename)


# upload results ----------------------------------------------------------

# data_raw = readd(data_raw) 
# data_filtered = readd(data_filtered, verbose = T)
# data_filtered_clean = readd(data_filtered_clean, verbose = T)
# fst::write_fst(data_raw, "data_raw.fst", compress = 80)
# file.size("data_raw.fst") # 2.3 GB = too big!
# data_raw = fst::read.fst("data_raw.fst")
