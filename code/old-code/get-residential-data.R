centroids_lsoa = pct::get_pct_centroids(region = "london", geography = "lsoa")
centroids = centroids_lsoa[stations_buff, ]
nrow(centroids)

tm_shape(centroids) +
  tm_dots() +
  tm_shape(stations) +
  tm_dots(col = "green")

mapview::mapview(centroids) +
  mapview::mapview(stations, col = stations$id)

# start with a single centroid
c1 = centroids[1, ]

# todo get oa data in there

# classify OAs by provision


# get wpz


# classify docking stations by residential overall and then measure of deprivation/wealth

# Capacity vs potential per occupation band

