# Packages used for preprocessing
remotes::install_github("ropensci/bikedata")
remotes::install_github("tidyverse/dtplyr")
library(bikedata)
library(dtplyr)


# Download data -----------------------------------------------------------

# system("mkdir -p data/london")
# dl_bikedata(city = "london", data_dir = "data/london")
# ntrips = store_bikedata(bikedb = "data/london/london_bike_hire.sqlite", data_dir = "data/london")
# file.size("data/london/london_bike_hire.sqlite") / 1e9 # 5GB file
# # Total trips read = 68,421,761
# 
# # Generating test data + preprocessing
# # Import data (code from Roger Beecham)
# bikes_data = DBI::dbConnect(RSQLite::SQLite(), "data/london/london_bike_hire.sqlite")
# file.size("data/london/london_bike_hire.sqlite") / 1e9 # a 5 gb file
# DBI::dbListTables(bikes_data)
# 
# # Disconnect 
# # DBI::dbDisconnect(bikes_data)
# 
# # Query using dplyr syntax.
# # Select table to work on.
# trips = tbl(bikes_data, "trips")
# 
# 
# # Warning: takes several minutes and 10+ GB RAM ---------------------------
# trips_df = trips %>% collect() 
# vroom::vroom_write(trips_df, "london_bike_hire.csv.gz") # a 1 gb file

# Clean data from Roger - to further clean
# Less than 1 minute to load 68 million rows:
system.time({
  trips_df = vroom::vroom("london_bike_hire.csv.gz")
})
pryr::object_size(trips_df) # 5.2 GB
trips_df


summary(trips_df$start_time)

# head(trips)
# trips_dt = lazy_dt(trips_df)

trips_df$id[1:9]
# trips_df$id = trips_df %>% mutate_at(contains("id"), str_remove(., "lo"))

# what % are in station ids
trips_df$start_station_id[1:9]
sum(trips_df$start_station_id %in% stations$id)

# benchmark mutate
lubridate::year(trips_df$start_time[1:9])

trips_df$year = lubridate::year(trips_df$start_time)
system.time({ # error
  trips_df = trips_df %>% mutate(year = lubridate::year(start_time))
})
# system.time({
#   trips_dt = trips_dt %>% mutate(year = lubridate::year(start_time))
# })

# We will want all station data (and to work on this in-memory).
stations = tbl(bikes_data, "stations") %>% collect()
stations
stations_sf = st_as_sf(stations, coords = c("longitude", "latitude"))
sf::write_sf(stations_sf, "stations.geojson")
vroom::vroom_write(stations, "bike-hire-stations-london.csv")
# Let's generate a random sample of trips data to work with
start_date = as.Date("2019-06-01")
end_date = as.Date("2019-06-30")
sample_2019 = trips %>% 
  filter(start_time > start_date, stop_time < end_date) %>%
  mutate(start_station_id = gsub(pattern = "lo", replacement = "", x = start_station_id)) %>% 
  mutate(end_station_id = gsub(pattern = "lo", replacement = "", x = end_station_id)) %>% 
  collect()
# vroom::vroom_write(sample_2019, "sample-trips-london-june-2019.csv")
vroom::vroom_write(sample_2019, "sample-trips-london-june-2019.csv.gz")

# Get and further clean OD data (not evaluated)

piggyback::pb_list()
piggyback::pb_download("london_bike_hire_cleaned.csv.gz")
trips_df = vroom::vroom("london_bike_hire_cleaned.csv.gz")
trips_df
pryr::object_size(trips_df) # 5.45 GB
names(trips_df) # do we really need "city"? no
head(trips_df$trip_duration, 9)
head(trips_df$user_type, 9) # not needed
head(trips_df$birth_year, 9) 
head(trips_df$gender, 9) 
trips_df = trips_df %>% select(-city, -user_type, -birth_year, -gender)
pryr::object_size(trips_df) # 4.02 GB, much smaller
trips_df

# test that the station ids match - ucl data is better
# sum(trips_df$start_station_id %in% ids_in_bikedata_not_in_clean_ucl_data) / nrow(trips_df) # 0.2%
# sum(trips_df$start_station_id %in% ids_in_bikedata_not_in_ucl_data) / nrow(trips_df) # 0.2%
# sum(trips_df$start_station_id %in% ids_in_ucl_data_not_in_bikedata) / nrow(trips_df) # 2%

trips_with_origin_station_ids = trips_df$start_station_id %in% stations$id
trips_with_destination_station_ids = trips_df$end_station_id %in% stations$id
sum(trips_with_origin_station_ids) / nrow(trips_df)
sum(trips_with_origin_station_ids) / nrow(trips_df) # 99.76% have origin id
sum(trips_with_destination_station_ids) / nrow(trips_df) # 99.37% have destination id
trips_with_ids = trips_with_origin_station_ids & trips_with_destination_station_ids
# trips_df$with_ids = trips_with_ids
sum(trips_with_ids) / nrow(trips_df) # 96% have id
yrs_without_ids = lubridate::year(trips_df$start_time[!trips_with_ids])
table(yrs_without_ids)
# 1900   1901   2012   2013   2014   2015   2016   2017   2018   2019 
#  753    420 125218 150010    130    196 434829 731076 905495 447993 
years_int = lubridate::year(trips_df$start_time)
trips_df$year = years_int
# summary(as.factor(trips_df$year))

# Yearly analysis

trips_per_year = trips_df %>% 
  group_by(year) %>% 
  summarise(
    total = n(),
    with_matching_ids = sum(with_ids)
  ) %>% 
  filter(year > 2000)

g = ggplot(trips_per_year) +
  geom_line(aes(year, total), col = "grey") +
  geom_line(aes(year, with_matching_ids), col = "blue")
g
library(plotly)
ggplotly(g)

trips_df = trips_df %>% filter(trips_with_ids)
head(trips_df$start_station_id)
trips_by_origin_station = trips_df %>% 
  group_by(id = start_station_id) %>% 
  summarise(total_n_trips_start = n())

trips_match_stations = trips_by_origin_station$id %in% stations$id
(nrow(trips_df) - nrow(trips_df_with_matching_ids)) / nrow(trips_df) # 0.8%
ncol(trips_df) - ncol(trips_df_with_matching_ids)

sum(is.na(trips_df$year)) / nrow(trips_df) # 0.2% with no year
trips_df = trips_df %>% filter(!is.na(year))
has_sane_year = trips_df$year > 2009
sum(has_sane_year) / nrow(trips_df)
summary(trips_df$year)
trips_df
trips_df = trips_df %>% select(-bike_id)
pryr::object_size(trips_df) # sub 4 GB!
data.table::fwrite(trips_df, "london_bike_hire_cleaned2.csv") # 4.5 GB file - no problem!
R.utils::gzip("london_bike_hire_cleaned2.csv", "london_bike_hire_cleaned2.csv.gz")

vroom::vroom_write(trips_df, "london_bike_hire_cleaned2.csv.gz")
fst::write_fst(trips_df, "trips_df.fst")
piggyback::pb_upload("trips_df.fst")

# cleaning data_clean.fst
trips_df = fst::read_fst("data_clean.fst")
sapply(trips_df, class)
start_date = lubridate::ymd_hms("2010-01-01 00:00:01")
summary({sel_time_right = trips_df$start_time > start_date})
sel_time_right[is.na(sel_time_right)] = FALSE
summary(sel_time_right)
trips_df = trips_df[sel_time_right, ]
fst::write_fst(trips_df, "data_clean_no_na_dates.fst")
piggyback::pb_upload("data_clean_no_na_dates.fst")
