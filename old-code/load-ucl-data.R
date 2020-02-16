# aim: load csv files provided by UCL

library(tidyverse)
library(tmap)

# piggyback::pb_download("bikelocations_london.csv")
bikelocations = readr::read_csv("bikelocations_london.csv")
locations = bikelocations %>% 
  group_by(ucl_id) %>% 
  summarise(lat = median(lat), lon = median(lon))

summary(locations)

bikelocations = bikelocations %>% select(-lat, -lon)
bikelocations = inner_join(bikelocations, locations)
bikelocations = bikelocations %>% filter(lat != 0) # removes dodgy data
bikelocations %>% filter(lon == 0) # birkenhead
lon_lat = tmaptools::geocode_OSM("birkenhead street london")
bikelocations$lon[bikelocations$lon == 0] = lon_lat$coords[1]
bikelocations$lon[bikelocations$lat == 0] = lon_lat$coords[2]

bikelocations$lon[bikelocations$ucl_id == 304] 
bikelocations$lon[bikelocations$ucl_id == 304] = -0.15904
bikelocations$lat[bikelocations$ucl_id == 304] = 51.512354

bikelocations %>% filter(grepl(pattern = "Pop Up Dock", x = operator_name)) %>%
  select(ucl_id, initial_size, lat, lon) # 19 pop ups
bikelocations = bikelocations %>% filter(!grepl(pattern = "Pop Up Dock", x = operator_name) & ucl_id != 304)

summary(bikelocations %>% select(matches("lat|lon")))
bikelocations %>% filter(lon > 1) # Houndsditch
bikelocations %>% filter(lat < 50) # Forestreet
bikelocations = bikelocations %>% filter(lon <= 1) # rm Houndsditch
bikelocations = bikelocations %>% filter(lat >= 50) 
plot(bikelocations$lon, bikelocations$lat)

# this bit is failing (RL)
# ind_monthly = vroom::vroom("network-science-bikeshare/data/ind_london_monthly_hist.csv")
# length(unique(ind_monthly$timestamp))
# ind_yearly = ind_monthly %>% 
#   mutate(year = lubridate::round_date(timestamp, unit = "year")) %>% 
#   group_by(tfl_id, year) %>% 
#   summarise(bikes = mean(bikes))

# ind_yearly %>% 
#   ggplot() +
#   geom_line(aes(x = year, y = bikes, group = tfl_id, col = tfl_id), alpha = 0.1) 



summary(bikelocations$curr_bikes)
summary(bikelocations$initial_size)
summary(bikelocations$curr_size) # shows number of bikes
summary(bikelocations$updated_dt)
summary(bikelocations$created_dt)
unique(bikelocations$created_dt)
bikelocations = bikelocations %>% mutate(created_year = lubridate::round_date(created_dt, "year"), year = NA)

saveRDS(bikelocations, "bikelocations-df-initial-clean.Rds")


bikelocations
library(sf)
bikelocations_sf = st_as_sf(bikelocations, coords = c("lon", "lat"), crs = 4326)
summary(bikelocations_sf$created_year)
s = readRDS("stations-clean.Rds") # 820 obs, 19 vars, needs to be duplicated for each year...
mapview::mapview(s)

m1 = tm_shape(bikelocations_sf) + tm_dots(alpha = 0.5, scale = 3)
m2 = tm_shape(s) + tm_dots(alpha = 0.5, scale = 3)
tmap_arrange(m1, m2)

bikelocations = readRDS("stations-clean.Rds")
bikelocations$created_year = bikelocations$created_dt
bikelocations_year = NULL

i = 2010
for(i in 2010:2019) {
  i_date = lubridate::ydm(paste0(i + 1, "0101"))
  created_before = bikelocations[bikelocations$created_year <= i_date, ]
  created_before$year = i
  bikelocations_year = rbind(bikelocations_year, created_before)
}

# how many locations are there?
bikelocations_year %>% 
  group_by(year) %>% 
  summarise(n())

# remove duplicates
bikelocations_year %>% 
  group_by(year) %>% 
  summarise(n())

# remove duplicates
bikelocations_year = bikelocations_year %>% 
  group_by(year, ucl_id) %>% 
  slice(which.max(year))

# test duplicates have been removed
bikelocations_year %>% 
  group_by(year) %>% 
  summarise(n())

# summary(bikelocations_year$lon) 
# bikelocations_sf = sf::st_as_sf(bikelocations_year, coords = c("lon", "lat"), crs = 4326)
bikelocations_sf = bikelocations_year

# check for outliers
stations_2019 = bikelocations_sf %>% filter(year == 2019)
mapview::mapview(stations_2019) # issue with id 304
# bikelocations %>% filter(ucl_id == 304) %>% select(lat, lon)

# # save bikedata
# sf::st_write(bikelocations_sf, "bikelocs_yearly.geojson", delete_dsn = TRUE)
# saveRDS(bikelocations_sf, "bikelocations_sf.Rds")
# saveRDS(stations_2019, "stations_2019.Rds")
# piggyback::pb_upload("bikelocations_sf.Rds")
# piggyback::pb_upload("stations_2019.Rds.Rds")

# basemap = tmaptools::read_osm(x = st_bbox(bikelocations_sf))
bb = stplanr::geo_projected(bikelocations_sf, sf::st_buffer, dist = 1000)
basemap = ceramic::cc_casey(bb)

qtm(basemap)
qtm(basemap, bbox = bb)
# m = qtm(basemap, bbox = ) +
#   tm_shape(bikelocations_sf) +
#   tm_dots(size = "curr_size") +
#   tm_facets(along = "year", ncol = 1, nrow = 1, free.coords = FALSE) 
# m
# tmap_animation(m, width = 1500, height = 1000, filename = "out.gif")
# magick::image_read("out.gif")

m = tm_shape(basemap) +
  tm_rgb() +
  tm_shape(bikelocations_sf %>% filter(year == 2019)) +
  tm_dots(size = "curr_size", title.size = "Bikes", alpha = 0.3) +
  tm_facets(along = "year", ncol = 1, nrow = 1, free.coords = FALSE) +
  tm_layout(scale = 1.5) +
  tm_scale_bar()
tmap_save(tm = m, filename = "clean-figures/overview-2019.png", width = 7, height = 5)
magick::image_read("clean-figures/overview-2019.png")
m = tm_shape(basemap) +
  tm_rgb() +
  tm_shape(bikelocations_sf) +
  tm_dots(size = "curr_size", title.size = "Bikes", alpha = 0.3) +
  tm_facets(along = "year", ncol = 1, nrow = 1, free.coords = FALSE) +
  tm_layout(scale = 1) +
  tm_scale_bar()
tmap_animation(m, width = 1500, height = 1000, filename = "out-clean.gif", delay = 100)
magick::image_read("out-clean.gif")

# create facet map with 4 key stages for paper
bikelocations_sf4 = bikelocations_sf %>% 
  filter(year %in% c(2010, 2012, 2014, 2019))
m4 = tm_shape(basemap) +
  tm_rgb() +
  tm_shape(bikelocations_sf4) +
  tm_dots(size = "curr_size", title.size = "Bikes", alpha = 0.3) +
  tm_facets(by = "year", free.coords = FALSE) +
  tm_layout(scale = 1, legend.show = F)
m4
# outtakes ----------------------------------------------------------------

# create data frame with n. bikes per year per docking station
# bikelocations_yr = bikelocations %>% 
#   mutate(year = lubridate::round_date(timestamp, unit = "year"))
#   group_by(operator_intid, )


# # clean lat/lon pairs - old way
# bikelocations[which.min(bikelocations$lat), ]
# old_lon_lats = bikelocations[which.min(bikelocations$lat), ] %>% 
#   select(matches("lat|lon")) %>% 
#   as.numeric()
# bikelocations[which.min(bikelocations$lat), c("lat", "lon")] = rev(old_lon_lats)
# bikelocations %>% filter(ucl_id == 779)
# bikelocations %>% filter(ucl_id == 790)
# new_lon_lats = bikelocations %>% 
#   filter(ucl_id == 790) %>% 
#   select(matches("lat|lon")) %>% 
#   slice(2)
# bikelocations[which.min(bikelocations$lat), c("lat", "lon")] = new_lon_lats
# 
# bikelocations[bikelocations$lon > 1, ] 
# bikelocations %>% filter(ucl_id == 501)
# new_lon_lats = bikelocations %>% 
#   filter(ucl_id == 501) %>% 
#   select(matches("lat|lon")) %>% 
#   slice(2)
# bikelocations[which.max(bikelocations$lon), c("lat", "lon")] = new_lon_lats
# 
# bikelocations[which.min(bikelocations$lat), ] 
# bikelocations %>% filter(ucl_id == 780)
# new_lon_lats = bikelocations %>% 
#   filter(ucl_id == 780) %>% 
#   select(matches("lat|lon")) %>% 
#   slice(2)
# bikelocations[which.min(bikelocations$lat), c("lat", "lon")] = new_lon_lats
# 
# bad_ids = bikelocations[bikelocations$lat == 0, ] %>% # View()
#   pull(ucl_id)
# for(i in bad_ids) {
#   bikelocations %>% filter(ucl_id == 780)
#   new_lon_lats = bikelocations %>% 
#     filter(ucl_id == 780) %>% 
#     select(matches("lat|lon")) %>% 
#     slice(2)
#   bikelocations[which.min(bikelocations$lat), c("lat", "lon")] = new_lon_lats
#   
# }
# 
# summary(bikelocations %>% select(matches("lat|lon")))
# 
# bikelocations$lat[bikelocations$lat > 52] = bikelocations$lat[bikelocations$lat > 52] / 10
# 
# 
# na_ll = is.na(bikelocations$lon)
# bikelocations = bikelocations[!na_ll, ]


# data from yuanxuan ------------------------------------------------------

# in bash
# git clone git@github.com:rogerbeecham/network-science-bikeshare.git

# load("network-science-bikeshare/data/Preprocess/station_trip_clean_part1.Rdata")
# load("network-science-bikeshare/data/Preprocess/station_trip")
# trips_df <- vroom("london_bike_hire_cleaned.csv.gz")

