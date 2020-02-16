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




# Create plan -------------------------------------------------------------

plan = drake_plan(
  raw_data = get_london_cycle_hire_data(),
  data = raw_data %>%
    mutate(Species = forcats::fct_inorder(Species)),
  hist = create_plot(data),
  fit = lm(Sepal.Width ~ Petal.Width + Species, data),
  report = rmarkdown::render(
    knitr_in("report.Rmd"),
    output_file = file_out("report.html"),
    quiet = TRUE
  )
)

