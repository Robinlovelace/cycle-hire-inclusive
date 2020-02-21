# Master script to ensure reproducibility of, and enable updating of, paper results
# See https://books.ropensci.org/drake/projects.html#code-files


# Loads packages ----------------------------------------------------------

pkgs = c(
  "drake",
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
  download_data = lchs_download(data_dir, sqf),
  rename_data = lchs_rename(data_dir, sqf, files_to_rename = "2020"),
  data_raw = lchs_read_raw(data_dir, sqf)
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

make(plan)
