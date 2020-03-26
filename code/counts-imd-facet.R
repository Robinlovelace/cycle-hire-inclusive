# Chart showing rolling 365 day trip counts by docking station within IMD decile.

# library(tidyverse)
# library(sf)
# library(fst)
# theme_void makes view composition easier.
# theme_set(theme_void(base_family="Avenir Book"))

# Requires trip types df from "get-trip-types.R"
# piggyback::pb_download("stations_pop.Rds")
stations <- readRDS("stations_pop.Rds")

# Calculate daily hires for each station.
daily_hires <- trip_types %>%
  mutate(
    start_time=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    date=as_date(start_time)
  ) %>% 
  left_join(stations %>% mutate(id=as.character(ucl_id), imd=Income.decile) %>% select(id, imd) %>% st_drop_geometry(), by=c("o_station"="id")) %>%
  group_by(date, o_station) %>%
  summarise(count=n(), imd=first(imd)) %>% filter(!is.na(date), !is.na(imd)) %>% ungroup()

# Summarise over imd for charting.
daily_hires_imd <- daily_hires %>%
  group_by(date, imd) %>%
  summarise(count=sum(count)) %>% ungroup() %>%
  group_by(imd) %>%
  mutate(yearly = RcppRoll::roll_mean(x = count, n = 365, fill = NA, align="right"), max_count=max(yearly, na.rm=TRUE)) %>% ungroup() %>% 
  group_by(date, imd) %>% 
  mutate(rescaled_count=max(yearly/max_count, 0.5)) 

# Summarise over imd and station for charting.
daily_hires_imd_station <- daily_hires %>%
  group_by(o_station) %>%
  mutate(yearly = RcppRoll::roll_mean(x = count, n = 365, fill = NA, align="right"),
         max_count=max(yearly, na.rm=TRUE)) %>% ungroup() %>%
  group_by(o_station, date) %>%
  mutate(rescaled_count=max(yearly/max_count, 0.5))

# Recode and label imd variable for charting.
daily_hires_imd <- daily_hires_imd %>% ungroup() %>%
  mutate(
    imd=case_when(imd == 1 ~ "1 - most deprivation", imd == 2 ~ "2", imd == 3 ~ "3", imd == 4 ~ "4", imd == 5 ~ "5 - mid deprivation", imd == 6 ~ "6 - mid deprivation", imd == 7 ~ "7", imd == 8 ~ "8", 
                  imd == 9 ~ "9", TRUE ~ "10 - least deprivation"),
    imd=factor(imd, levels=c("1 - most deprivation", "2", "3", "4", "5 - mid deprivation",
                             "6 - mid deprivation", "7", "8", "9", "10 - least deprivation"))
  )
daily_hires_imd_station <- daily_hires_imd_station %>%
  mutate(
    imd=case_when(imd == 1 ~ "1 - most deprivation", imd == 2 ~ "2", imd == 3 ~ "3", imd == 4 ~ "4", imd == 5 ~ "5 - mid deprivation", imd == 6 ~ "6 - mid deprivation", imd == 7 ~ "7", imd == 8 ~ "8", 
                  imd == 9 ~ "9", TRUE ~ "10 - least deprivation"),
    imd=factor(imd, levels=c("1 - most deprivation", "2", "3", "4", "5 - mid deprivation",
                             "6 - mid deprivation", "7", "8", "9", "10 - least deprivation")))
imd_count <- daily_hires_imd %>% group_by(imd) %>% summarise(count=sum(count))
imd_count <- imd_count %>%
  mutate(
    imd=case_when(imd == 1 ~ "1 - most deprivation", imd == 2 ~ "2", imd == 3 ~ "3", imd == 4 ~ "4", imd == 5 ~ "5 - mid deprivation", imd == 6 ~ "6 - mid deprivation", imd == 7 ~ "7", imd == 8 ~ "8", 
                  imd == 9 ~ "9", TRUE ~ "10 - least deprivation"),
    imd=factor(imd, levels=c("1 - most deprivation", "2", "3", "4", "5 - mid deprivation",
                             "6 - mid deprivation", "7", "8", "9", "10 - least deprivation"))
  )


plot <- 
  ggplot() +
  # Facet background.
  geom_rect(data=imd_count, 
            aes(xmin=as_date("2012-01-04"), xmax=as_date("2019-12-31"), ymin=0.5, ymax=1, alpha=count), 
            fill="#bdbdbd", colour="#d9d9d9")+
  geom_line(data=daily_hires_imd_station, 
             aes(date, rescaled_count, group=o_station), colour="#252525", lwd = 0.3, alpha=0.2) +
  geom_line(data=daily_hires_imd, 
            aes(date, rescaled_count), colour = "#99000d", lwd = 0.8) +
  xlab("Year") +
  scale_alpha(range=c(0,1))+
  facet_wrap(~imd, nrow=2)+
  guides(alpha=FALSE)+
  theme(
    strip.text.x=element_text(size = 12),
    axis.title=element_blank(), 
    axis.text.y=element_blank(),
    panel.grid=element_blank(),
  )
ggsave("./figures/daily_hires_station_imd_minor.png", plot=plot, width = 14, height = 6, dpi=300) 

