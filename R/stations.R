# lchs_get_stations() # get input stations data 
lchs_get_stations_raw = function() {
  if(!file.exists("bikelocations_london.csv")) {
    message("Download the stations file from releases")
    piggyback::pb_download("bikelocations_london.csv")
  }
  readr::read_csv("bikelocations_london.csv")
}

lchs_get_stations = function(stations = lchs_get_stations_raw(), trips_df = lchs_get_stations_1000()) {
  cleaned_data = lchs_recode(trips_df, stations)
  cleaned_data$stations
}

# stations_sf = lchs_get_stations_sf()
# mapview::mapview(stations_sf)
# saveRDS(stations_sf, "stations_sf.Rds") # master 
# piggyback::pb_upload("stations_sf.Rds")
# library(sf)
# plot(stations_sf)
# nrow(stations_sf)
# table(lubridate::year(stations_sf$created_dt))
lchs_get_stations_sf = function(stations = lchs_get_stations()) {
  sf::st_as_sf(stations, coords = c("lon", "lat"), crs = 4326)
  # mapview::mapview(.Last.value)
}

lchs_get_stations_region = function(stations_sf) {
  stations_concave = concaveman::concaveman(points = stations_sf, 1)
  stations_concave %>% stplanr::geo_buffer(dist = 500)
}

# tests
# bikelocations_year = lchs_stations_yearly(stations_sf)
# bikelocations_year %>% 
#   group_by(year) %>% 
#   summarise(n())
# 
# # test duplicates have been removed
# bikelocations_year %>% 
#   group_by(year) %>% 
#   summarise(n())
lchs_stations_yearly = function(stations_sf){
  i = 2010
  bikelocations_year = NULL
  for(i in 2010:2019) {
    i_date = lubridate::ydm(paste0(i + 1, "0101"))
    created_before = stations_sf[stations_sf$created_dt <= i_date, ]
    created_before$year = i
    bikelocations_year = rbind(bikelocations_year, created_before)
  }
  bikelocations_year
}


