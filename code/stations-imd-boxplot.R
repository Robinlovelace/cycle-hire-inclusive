# Boxplots 
stations <- stations %>% 
  mutate(
    trips_per_person_yr=trips_per_year / Population / years_in_operation,
    trips_per_person_yr_am = trips_per_year_am / Population,
    trips_per_person_yr_pm = trips_per_year_pm / Population 
  )

stations <- stations %>%
  mutate(
  imd=Income.decile,
  imd=case_when(imd == 1 ~ "1 - most deprivation", imd == 2 ~ "2", imd == 3 ~ "3", imd == 4 ~ "4", imd == 5 ~ "5 - mid deprivation", imd == 6 ~ "6", imd == 7 ~ "7", imd == 8 ~ "8", 
                imd == 9 ~ "9", TRUE ~ "10 - least deprivation"),
  imd=factor(imd, levels=c("1 - most deprivation", "2", "3", "4", "5 - mid deprivation",
                           "6", "7", "8", "9", "10 - least deprivation"))
  )

theme_set(theme_minimal(base_family="Avenir Book"))
plot <- stations %>%
  st_drop_geometry() %>%
  select(imd, am=trips_per_person_yr_am, pm=trips_per_person_yr_pm) %>%
  pivot_longer(-imd, names_to="trip_type", values_to="count") %>% 
  # Create a ceiling on 40 counts
  mutate(
    count=pmin(count,50)
    #count=log(count)
    ) %>% 
  ggplot(aes(x=imd, y=count))+
  geom_boxplot(width=0.5, colour = "#969696", outlier.shape=NA)+
  geom_jitter(position=position_jitter(0.2), alpha=0.1)+
  facet_wrap(~trip_type, nrow=2, scales="free_y")+
  theme(
    strip.text.x=element_text(size = 10),
    axis.title.x = element_blank(),
    axis.title.y = element_blank()
  )
  
ggsave("./figures/income-decile-am-pm-boxplot_minor.png", plot=plot, width = 10, height = 8, dpi=300)
                

magick::image_read("figures/income-decile-am-pm-boxplot.pn