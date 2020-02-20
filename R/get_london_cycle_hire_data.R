# Aim get initial dataset - 

# file.edit("old-code/preprocess.R") # based on that original file


# get and save raw data from bikedata -------------------------------------

# data_dir = "data/london"
# sqf = file.path(data_dir, "london_bike_hire_2020-02.sqlite")
# list.files(data_dir)
# bikedata::dl_bikedata(city = "london", data_dir = data_dir)
# ntrips = bikedata::store_bikedata(bikedb = sqf, data_dir = "data/london")
# file.size(sqf) # 6.5 GB
# 
# bikes_data = DBI::dbConnect(RSQLite::SQLite(), sqf)
# DBI::dbListTables(bikes_data)
# trips = tbl(bikes_data, "trips")
# system.time({trips_df = trips %>% collect()})
# # user  system elapsed 
# # 177.343   4.433 181.755 
# summary(trips_df$start_time) # char string in db...
# 
# system.time({
#   vroom::vroom_write(trips_df, "london_bike_hire_from_bikedata-2020-02.csv.gz")
# })
# user  system elapsed 
# 286.760 194.904 438.305 
# file.size("london_bike_hire_from_bikedata-2020-02.csv.gz") / 1e9
# 1.4 GB

# Clean raw data... -------------------------------------------------------

# # Less than 1 minute to load 68 million rows:
# system.time({
#   trips_df = vroom::vroom("london_bike_hire_from_bikedata-2020-02.csv.gz")
# })
# # user  system elapsed 
# # 53.546  10.961  37.546 
# trips_df
# 
# trips_df$year = lubridate::year(trips_df$start_time)
# 
# # year-month 
# lubridate::floor_date(trips_df$start_time[sample(nrow(trips_df), size = 10)], unit = "month")
# trips_df$year_month = lubridate::floor_date(trips_df$start_time, unit = "month")
# 
# # pryr::object_size(trips_df) # 7.87 GB
# names(trips_df) # do we really need "city"? no
# head(trips_df$trip_duration, 9)
# head(trips_df$user_type, 9) # not needed
# head(trips_df$birth_year, 9) 
# head(trips_df$gender, 9) 
# trips_df = trips_df %>% select(-city, -user_type, -birth_year, -gender)
# pryr::object_size(trips_df) # 6.16 GB smaller
# trips_df

# very slow to write...
# system.time({
#   vroom::vroom_write(trips_df, "london_bike_hire_from_bikedata-2020-02-clean-1.csv.gz")
# })
# user  system elapsed 
# 503.784   3.107 435.412 


# Cleaning stage II find missing/duplicate data ----------------------

trips_df = vroom::vroom("london_bike_hire_from_bikedata-2020-02-clean-1.csv.gz")

# trips_df_1pct = trips_df %>% sample_frac(size = 0.01)

# stations = readRDS("stations-clean.Rds")
# 
# trips_with_origin_station_ids = trips_df$start_station_id %in% stations$check_id # 
# sum(trips_with_origin_station_ids) / nrow(trips_df) # no matching ids!
# str_remove(trips_df$start_station_id[1:9], "lo")
# trips_df$start_station_id = str_remove(trips_df$start_station_id, "lo")
# trips_df$end_station_id = str_remove(trips_df$end_station_id, "lo")
# 
# trips_with_origin_station_ids = trips_df$start_station_id %in% stations$ucl_id
# trips_with_destination_station_ids = trips_df$end_station_id %in% stations$operator_intid
# sum(trips_with_origin_station_ids) / nrow(trips_df) # 99.2% have origin id
# sum(trips_with_destination_station_ids) / nrow(trips_df) # 98.1% have destination id
# trips_with_ids = trips_with_origin_station_ids & trips_with_destination_station_ids
# # trips_df$with_ids = trips_with_ids
# sum(trips_with_ids) / nrow(trips_df) # 97% have id
# yrs_without_ids = lubridate::year(trips_df$start_time[!trips_with_ids])
# table(yrs_without_ids)
# # original:
# # 1900   1901   2012   2013   2014   2015   2016   2017   2018   2019 
# #  753    420 125218 150010    130    196 434829 731076 905495 447993 
# # with latest bikedata data:
# # 1900   1901   2012   2013   2014   2015   2016   2017   2018   2019 
# # 753    420 342285 285146 445611 288976 228780 171672 206601 268226


# trips_df = trips_df %>% filter(trips_with_ids)
# head(trips_df$start_station_id)
# trips_by_origin_station = trips_df %>% 
#   group_by(id = start_station_id) %>% 
#   summarise(total_n_trips_start = n())
# 
# sum(is.na(trips_df$year)) / nrow(trips_df) # 0.2% with no year
# trips_df = trips_df %>% filter(!is.na(year))
# has_sane_year = trips_df$year > 2009
# sum(has_sane_year) / nrow(trips_df)
# summary(trips_df$year)
# trips_df
# trips_df = trips_df %>% select(-bike_id)
# pryr::object_size(trips_df)
# # 5.32 GB

system.time(fst::write_fst(trips_df, "trips_df.fst"))
# user  system elapsed  # 100 times faster!
# 6.993   1.046   4.464
system.time(fst::write_fst(trips_df, "trips_df.fst", 80))
# user  system elapsed  
# 37.238   1.218  15.196 
file.size("trips_df.fst") / 1e9 # 1.3 GB
piggyback::pb_upload("trips_df.fst", repo = "itsleeds/tds")


# identify duplicate/missing months ---------------------------------------

trips_df = fst::read.fst("trips_df.fst")

# time analysis
trips_per_year = trips_df %>% 
  group_by(year_month) %>% 
  summarise(
    total = n()
  ) 
g = ggplot(trips_per_year) +
  geom_line(aes(year_month, total), col = "grey") 
g

trips_df$date = as.Date(trips_df$start_time)
trips_per_day = trips_df %>% 
  group_by(date) %>% 
  summarise(
    total_csvs = n()
  ) 

trips_per_day_xls = readRDS("daily_hires.Rds")
trips_per_day_xls$date = trips_per_day_xls$Day
trips_daily = left_join(trips_per_day_xls, trips_per_day)

ggplot(trips_daily, aes(Day, `Number of hires`)) +
  geom_point(alpha = 0.1) +
  geom_line(aes(Day, Monthly), lwd = 1) +
  geom_line(aes(Day, Yearly), colour = "blue", lwd = 1) +
  # csv data
  geom_point(aes(y = total_csvs), colour = "red", alpha = 0.1) 
# finding: there are duplicate trips in the csv files

trips_df_duplicated = duplicated(trips_df %>% select(id))
summary(trips_df_duplicated) # but there are no duplicated duplicate ids!
trips_df_duplicated = distinct(trips_df %>% select(id))
nrow(trips_df_duplicated) / nrow(trips_df) # verified in tidyverse...
head(trips_df$start_time) # to nearest minute...
trips_df_duplicated = distinct(trips_df %>% select(start_time, stop_time, start_station_id))
nrow(trips_df_duplicated) / nrow(trips_df) # 82%
trips_df_distinct = trips_df %>% 
  distinct(start_time, stop_time, start_station_id, end_station_id)
nrow(trips_df_distinct) / nrow(trips_df) # 82.7 %
trips_df = trips_df_distinct

trips_per_day = trips_df %>% 
  mutate(date = as.Date(start_time)) %>% 
  group_by(date) %>% 
  summarise(
    total_csvs = n()
  ) 

trips_daily = left_join(trips_per_day_xls, trips_per_day)

ggplot(trips_daily, aes(Day, `Number of hires`)) +
  geom_point(alpha = 0.1) +
  geom_line(aes(Day, Monthly), lwd = 1) +
  geom_line(aes(Day, Yearly), colour = "blue", lwd = 1) +
  # csv data
  geom_point(aes(y = total_csvs), colour = "red", alpha = 0.1) +
  xlab("Year") +
  ylim(c(0, 50000)) +
  xlim(as.POSIXlt(c("2010-01-01", "2019-10-01"))) +
  ylab("Number of cycle hire events per day") +
  # scale_x_continuous(breaks = 2010:2020)
  # scale_x_date(breaks = lubridate::ymd(paste0(2010:2020, "-01-01")))
  scale_x_date(date_breaks = "1 year", date_labels = "%Y")

cor(trips_daily$`Number of hires`, trips_daily$total_csvs, use = "complete.obs") ^ 2 # 97.5

fst::write_fst(trips_df, "trips_df.fst")

# with bikedata internal functions ----------------------------------------

# aws_url <- "https://s3-eu-west-1.amazonaws.com/cycling.data.tfl.gov.uk/"
# doc <- httr::content (httr::GET (aws_url), encoding  =  'UTF-8')
# nodes <- xml2::xml_children(doc)
# 
# flist_zip <- getflist (nodes, type = 'zip')
# flist_zip <- flist_zip [which (grepl ('usage', flist_zip))]
# flist_csv <- getflist (nodes, type = 'csv')
# flist_xlsx <- getflist (nodes, type = 'xlsx')

# with rvest --------------------------------------------------------------

# library(rvest)
# html_data = xml2::read_html("https://cycling.data.tfl.gov.uk/")
# lnd_urls = html_data %>% 
#   rvest::html_nodes(css = "#tbody-content a") %>% 
#   html_text()


# old cleaning code -------------------------------------------------------
# 
# # clean ids
# trips_df$id[1:9]
# sample_ids = sample(x = trips_df$id, 20000) # look OK
# sample_ids[1:9]
# summary(str_detect(string = sample_ids, "lo"))


# dtplyr test -------------------------------------------------------------

# library(dtplyr)
# trips_dt = dtplyr::lazy_dt(trips_df_1pct)
# system.time({
#   trips_agg = trips_dt %>% 
#     group_by(year_month) %>% 
#     summarise(n = n())
#   trips_agg_df = as.data.frame(trips_agg)
# })
# user  system elapsed 
# 0.167   0.000   0.060 

# system.time({
#   trips_agg = trips_df_1pct %>% 
#     group_by(year_month) %>% 
#     summarise(n = n())
# })
# user  system elapsed 
# 0.054   0.001   0.056

