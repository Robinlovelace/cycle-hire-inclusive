# lchs_get_stations() # get input stations data 
lchs_get_stations = function() {
  if(!file.exists("bikelocations_london.csv")) {
    message("Download the stations file from releases")
    piggyback::pb_download("bikelocations_london.csv")
  }
  readr::read_csv("bikelocations_london.csv")
}

lchs_get_stations_sf = function(stations = lchs_get_stations()) {
  sf::st_as_sf(stations, coords = c("lon", "lat"), crs = 4326)
  # mapview::mapview(.Last.value)
}

# lchs_get_stations_buffered = function(stations = lchs::)