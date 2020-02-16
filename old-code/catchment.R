library(dplyr)

stations = sf::read_sf("stations.geojson")
stations_concave = concaveman::concaveman(points = stations, 1)

stations_buff_300 = stations_concave %>% stplanr::geo_buffer(dist = 300)
stations_buff = stations_concave %>% stplanr::geo_buffer(dist = 500)
stations_buff_1000 = stations_concave %>% stplanr::geo_buffer(dist = 1000)
stations_buff_3000 = stations_concave %>% stplanr::geo_buffer(dist = 3000)

d = rev(c(3, 5, 10, 30) * 100)
s = lapply(d, function(x) stations_concave %>% stplanr::geo_buffer(dist = x))
sdf = do.call(what = rbind, args = s)
sdf$Distance = d

plot(sdf["Distance"])
sf::write_sf(sdf, "sdf.geojson")
sf::write_sf(stations_buff, "stations_buff.geojson")
piggyback::pb_upload("sdf.geojson")
piggyback::pb_upload("stations_buff.geojson")

mapview::mapview(stations_buff) +
  mapview::mapview(stations)
