# Chart showing rolling 365 day trip counts by docking station within borough.

# library(tidyverse)
# library(sf)
# library(fst)
# theme_void makes view composition easier.
# theme_set(theme_void(base_family="Avenir Book"))

# Requires trip types df from "get-trip-types.R"
# piggyback::pb_download("stations_pop.Rds")
# stations <- readRDS("stations_pop.Rds")

# gb_boundaries <- st_read("./data/boundaries_gb/Local_Authority_Districts_December_2015_Super_Generalised_Clipped_Boundaries_in_Great_Britain.shp")
# region_lookup <- st_read("https://opendata.arcgis.com/datasets/c457af6314f24b20bb5de8fe41e05898_0.geojson")
# # Remove geometry data.
# st_geometry(region_lookup) <- NULL
# # Join on name.
# london_boundaries <- gb_boundaries %>%
#   left_join(region_lookup, by=c("lad15cd"="LAD17CD")) %>%
#   rename("ladcd"="lad15cd", "ladnm"="lad15nm", "region"="RGN17NM") %>%
#   select(ladcd, ladnm, region) %>%
#   filter(region=="London")
# london_boundaries <- london_boundaries %>% st_transform(crs=27700)
# rm(gb_boundaries)


# london_squared <- read_csv("./data/london_squared.csv")
# stations <- readRDS("stations_pop.Rds") %>% st_transform(crs=27700)
# # Attach borough to stations data.
stations <- st_join(stations, london_boundaries %>% select(ladnm)) %>%
   left_join(london_squared, by=c("ladnm"="authority"))
# Manually recode three stations
# stations %>% filter(is.na(ladnm))
# # A tibble: 3 x 33
# system ucl_id operator_intid operator_altid operator_name notes initial_bikes initial_size curr_bikes curr_size
# * <chr>   <dbl>          <dbl>          <dbl> <chr>         <chr>         <dbl>        <dbl>      <dbl>     <dbl>
#   1 london    376            376            376 Millbank Hou… NA               20           24         17        24
# 2 london    454            454            454 Napier Avenu… NA               12           20         20        20
# 3 london    821            821            821 Battersea Po

# ladnm fX fY BOR 
# ucl_id 376 (Millbank House) > Westminster	4	4	WST	
# ucl_id 821 Napier Avenue, Millwall Tower Hamlets	6	4	TOW	
# ucl_id 454  (Battersea Power station) Wandworth Wandsworth	3	5	WNS	

stations <- stations %>% 
  mutate(
    ladnm=if_else(ucl_id==376, "Westminster", 
                  if_else(ucl_id==821, "Tower Hamlets",
                          if_else(ucl_id==454, "Wandsworth", ladnm))),
    fX=if_else(ucl_id==376, 4, 
                  if_else(ucl_id==821, 6,
                          if_else(ucl_id==454, 3, fX))),
    fY=if_else(ucl_id==376, 4, 
               if_else(ucl_id==821, 4,
                       if_else(ucl_id==454, 5, fY))),
    BOR=if_else(ucl_id==376, "WST", 
               if_else(ucl_id==821, "TOW",
                       if_else(ucl_id==454, "WNS", BOR)))
  )

stations_boroughs <- stations %>% mutate(id=ucl_id) %>% select(id, fX, fY, BOR)
st_geometry(stations_boroughs) <- NULL

daily_hires <- trip_types %>% 
  mutate(
    start_time=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    date=as_date(start_time)
  ) %>% 
  left_join(stations_boroughs %>% mutate(id=as.character(id)) , by=c("o_station"="id")) %>% 
  group_by(o_station, date) %>%
  summarise(count=n(), fY=first(fY), fX=first(fX), BOR=first(BOR)) %>% filter(!is.na(date)) %>% ungroup()

daily_hires_bor <- daily_hires %>%
  group_by(date, BOR) %>%
  summarise(count=sum(count), fY=first(fY), fX=first(fX)) %>% filter(!is.na(date)) %>% ungroup() %>% group_by(BOR) %>%
  mutate(yearly = RcppRoll::roll_mean(x = count, n = 365, fill = NA, align="right"), max_count=max(yearly, na.rm=TRUE)) %>% ungroup() %>% filter(!is.na(BOR)) %>% 
  group_by(date, BOR) %>% 
  mutate(rescaled_count=max(yearly/max_count, 0.5)) 

daily_hires_station <- daily_hires %>%
  group_by(o_station) %>%
  mutate(yearly = RcppRoll::roll_mean(x = count, n = 365, fill = NA, align="right"),
         max_count=max(yearly, na.rm=TRUE)) %>% 
  filter(!is.na(BOR)) %>%
  group_by(o_station, date) %>%
  mutate(rescaled_count=max(yearly/max_count, 0.5))

# Add as context trips by borough -- rectangle fill.
trips_by_borough <- trip_types %>% 
  mutate(
    start_time=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    date=as_date(start_time)
  ) %>% 
  left_join(stations_boroughs %>% mutate(id=as.character(id)), by=c("o_station"="id")) %>%
  group_by(BOR) %>%
  summarise(count=n()) %>% ungroup()
london_squared <- london_squared %>% 
  left_join(trips_by_borough, by=c("BOR"="BOR")) %>% mutate(count=replace_na(count, 0))

plot <- 
  ggplot() +
  # Facet background.
  geom_rect(data=london_squared, aes(xmin=as_date("2012-01-04"), xmax=as_date("2019-12-31"), ymin=0.5, ymax=1, alpha=count), fill="#bdbdbd", colour="#d9d9d9")+
  geom_line(data=daily_hires_station, aes(date, rescaled_count, group=o_station), colour="#252525", lwd = 0.3, alpha=0.2) +
  geom_line(data=daily_hires_bor, aes(date, rescaled_count), colour = "#99000d", lwd = 0.8) +
  xlab("Year") +
  geom_text(data=london_squared, aes(x=as_date("2019-06-11"), y=0.52, label=BOR), family="Avenir Book", alpha=0.9, hjust="right", vjust="bottom", size=6)+
  scale_alpha(range=c(0,1))+
  facet_grid(fY~fX)+
  guides(alpha=FALSE)+
  theme(
    strip.text=element_blank(),
    panel.spacing=unit(-0.2, "lines"),
    axis.title=element_blank(), 
    axis.text.y=element_blank(),
    axis.text.x = element_blank(),
    panel.grid=element_blank(),
  )
ggsave("./figures/daily_hires_station_bor_minor.png", plot=plot, width = 12, height = 9.2, dpi=300) 
