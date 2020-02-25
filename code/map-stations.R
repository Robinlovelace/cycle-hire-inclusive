stations_yearly = readd(stations_yearly)
bb = stplanr::geo_projected(stations_yearly, sf::st_buffer, dist = 1000)
basemap = ceramic::cc_casey(bb)

tmap_mode("plot")
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
  tm_shape(stations_yearly %>% filter(year == 2019)) +
  tm_dots(size = "curr_size", title.size = "Bikes", alpha = 0.3) +
  tm_facets(along = "year", ncol = 1, nrow = 1, free.coords = FALSE) +
  tm_layout(scale = 1.5) +
  tm_scale_bar()
tmap_save(tm = m, filename = "figures/overview-2019.png", width = 7, height = 5)
magick::image_read("figures/overview-2019.png")
m = tm_shape(basemap) +
  tm_rgb() +
  tm_shape(stations_yearly) +
  tm_dots(size = "curr_size", title.size = "Bikes", alpha = 0.3) +
  tm_facets(along = "year", ncol = 1, nrow = 1, free.coords = FALSE) +
  tm_layout(scale = 1) +
  tm_scale_bar()
tmap_animation(m, width = 1500, height = 1000, filename = "out-clean.gif", delay = 100)
magick::image_read("out-clean.gif")
file.rename("out-clean.gif", "figures/out-clean.gif")

# create facet map with 4 key stages for paper
bikelocations_sf4 = stations_yearly %>% 
  filter(year %in% c(2010, 2012, 2014, 2019))
m4 = tm_shape(basemap) +
  tm_rgb() +
  tm_shape(bikelocations_sf4) +
  tm_dots(size = "curr_size", title.size = "Bikes", alpha = 0.3) +
  tm_facets(by = "year", free.coords = FALSE) +
  tm_layout(scale = 1, legend.show = F)
m4
