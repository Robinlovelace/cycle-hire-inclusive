# Aim: show shifting distribution of income groups served by cycle hire points over time
# Build on load-ucl-data.R and stations-classification.Rm

library(sf)
library(tidyverse)
library(tmap)

# read-in stations
s = st_read("bikelocs_yearly.geojson") # 7025 obs, 20 vars
s = readRDS("stations-clean.Rds") # 820 obs, 19 vars, needs to be duplicated for each year...

plot(s)
bikelocations_sf4 = s %>% 
  filter(year %in% c(2010, 2012, 2014, 2019))
m4 = tm_shape(bikelocations_sf4) +
  tm_dots(size = "curr_size", title.size = "Bikes", alpha = 0.3) +
  tm_facets(by = "year", free.coords = FALSE) +
  tm_layout(scale = 1, legend.show = F)
m4

# IMD data (at LSOA level)
lsoa_lnd = st_read("lsoa_bikeshare.geojson")
plot(lsoa_lnd["Income.Decile..where.1.is.most.deprived.10..of.LSOAs."])
oas_lnd_imd = sf::read_sf("oas_bikeshare_imd.geojson")

tm_shape(lsoa_lnd) + tm_polygons("Income.Decile..where.1.is.most.deprived.10..of.LSOAs.") +
tm_shape(oas_lnd_imd) + tm_dots("Income.Decile..where.1.is.most.deprived.10..of.LSOAs.", palette = "viridis") 

# tidy ready for plotting
# get wider view of london
boundary_lsoas = lsoa_lnd %>% st_union() %>% st_convex_hull() %>% st_sf
boundary_5k = stplanr::geo_projected(boundary_lsoas, st_buffer, dist = 5000)
plot(boundary_lsoas)

lsoa = ukboundaries::lsoa2011_simple
lsoa_lndb = lsoa[boundary_5k, ]

imd = readr::read_csv("imd2015eng.csv")
imd = imd %>% 
  rename(lsoa11cd = `LSOA code (2011)` )
lsoa_lnd_joined = inner_join(lsoa_lndb, imd)

lsoa_lnd_joined$`Income decile` = lsoa_lnd_joined$`Income Decile (where 1 is most deprived 10% of LSOAs)` # previously Income.Decile..where.1.is.most.deprived.10..of.LSOAs.
tm_shape(lsoa_lnd_joined) + tm_fill("Income decile", palette = "viridis") +
  qtm(bikelocations_sf4)

m4 = tm_shape(lsoa_lnd_joined, bbox = st_bbox(lsoa_lnd)) +
  tm_fill("Income decile", palette = "Blues", alpha = 0.8, legend.is.portrait = FALSE) +
  tm_shape(bikelocations_sf4) +
  tm_dots(size = 0.1, title.size = "Bikes") +
  tm_facets(by = "year", free.coords = FALSE) +
  # tm_layout(scale = 1, legend.show = F) # works
  # tm_layout(scale = 1, legend.outside.position = c("right"), legend.stack = "horizontal")
  tm_layout(scale = 1, legend.outside.position = "bottom")
m4
tmap_save(m4, "figures/facet-imd.png", width = 6, height = 7)

