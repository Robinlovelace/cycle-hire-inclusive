# Chart showing rolling 365 day trip counts by trip type within borough.

# library(tidyverse)
# library(sf)
# library(fst)
# theme_void makes view composition easier.
# theme_set(theme_void(base_family="Avenir Book"))


# Rescale for charting
map_scale <- function(value, min1, max1, min2, max2) {
  return  (min2+(max2-min2)*((value-min1)/(max1-min1)))
}

# Add as context trips by borough -- rectangle fill.
trips_by_borough <- trip_types %>% 
  left_join(stations_boroughs %>% mutate(id=as.character(id)), by=c("o_station"="id")) %>%
  group_by(BOR) %>%
  summarise(count=n()) %>% ungroup()
london_squared <- london_squared %>% left_join(trips_by_borough) %>% mutate(count=replace_na(count, 0))

daily_hires_bor <- trip_types %>%
  left_join(stations_boroughs %>% mutate(id=as.character(id)), by=c("o_station"="id")) %>%
  mutate(
    date=as_date(start_time)
  ) %>%
  filter(!is.na(date)) %>%
  group_by(date, BOR, fX, fY) %>%
  summarise_at(vars(am_peak:weekend),sum) %>% ungroup() %>%
  gather(key="trip_type", value="trip_count", -c(date, BOR, fX, fY)) %>%
  group_by(BOR, trip_type) %>%
  mutate(rolling_year=RcppRoll::roll_mean(trip_count,n = 365, fill = NA, align="right")) %>%
  ungroup() %>% filter(!is.na(rolling_year), !is.na(BOR)) %>%
  group_by(BOR) %>%
  # generate max across all trip types
  mutate(max=max(rolling_year), rescaled=rolling_year/max) %>%  ungroup() %>%
  # Rescale the rescaled values for charting
  mutate(rescaled_rescaled=map_scale(rescaled, 0,1,0,0.8))

plot <- ggplot() +
  # Facet background.
  geom_rect(data=london_squared, aes(xmin=as_date("2012-01-04"), xmax=as_date("2019-12-31"), ymin=0, ymax=1, alpha=count), fill="#bdbdbd", colour="#d9d9d9")+
  geom_line(data=daily_hires_bor, aes(x=date, y=rescaled, colour=trip_type, group=trip_type), alpha=0.7) +
  geom_text(data=london_squared, aes(x=as_date("2019-06-11"), y=0.05, label=BOR), family="Avenir Book", alpha=0.9, hjust="right", vjust="bottom", size=6)+
  scale_colour_manual(values=c("#33a02c","#6a3d9a","#ff7f00","#e31a1c","#1f78b4"))+
  scale_alpha(range=c(0,1))+
  facet_grid(fY~fX)+
  guides(alpha=FALSE)+
  theme(
    legend.position=c(0.05, 0.95),
    legend.text = element_text(size = 14),
    strip.text=element_blank(),
    panel.spacing=unit(-0.2, "lines"),
  )

ggsave("./figures/trip_types_by_borough_minor.png", plot=plot, width = 12, height = 9.2, dpi=300) 
