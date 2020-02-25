# Aim: create dataset representing region within which bikeshare scheme operates

library(dplyr)

# stations = sf::read_sf("stations.geojson")
# stations_sf = readd(stations_sf)
stations_concave = concaveman::concaveman(points = stations_sf, 1)

stations_buff_300 = stations_concave %>% stplanr::geo_buffer(dist = 300)
stations_buff = stations_concave %>% stplanr::geo_buffer(dist = 500)
stations_buff_1000 = stations_concave %>% stplanr::geo_buffer(dist = 1000)
stations_buff_3000 = stations_concave %>% stplanr::geo_buffer(dist = 3000)

d = rev(c(3, 5, 10, 30) * 100)
s = lapply(d, function(x) stations_concave %>% stplanr::geo_buffer(dist = x))
sdf = do.call(what = rbind, args = s)
sdf$Distance = d

plot(sdf["Distance"])
tmap_mode("view")
m = tm_shape(sdf) + tm_polygons("Distance", alpha = 0.2) +
  tm_basemap(leaflet::providers$OpenStreetMap)
m
tmap_save(m, "basemap_distances.html")
mapview::mapshot(file = "basemap_distances.html")
webshot::webshot("basemap_distances.html")
magick::image_read("webshot.png")
file.rename("webshot.png", "figures/test-plots/basemap-distances.png")
sf::write_sf(sdf, "sdf.geojson")
sf::write_sf(stations_buff, "stations_buff.geojson")
piggyback::pb_upload("sdf.geojson")
piggyback::pb_upload("stations_buff.geojson")

mapview::mapview(stations_buff) +
  mapview::mapview(stations)
