
piggyback::pb_download("lsoa_bikeshare.geojson")
lsoa <- read_sf("lsoa_bikeshare.geojson")

stations_yearly_lsoa %>%  
  filter(year %in% c(2010, 2012, 2014, 2019)) %>%
  # mutate(n_year = sum(year == year)) %>% View()
  ggplot(aes(`Income decile`)) +
  geom_bar(aes(y=..count../sum(..count..)), fill = "blue") +
  scale_y_continuous(labels = scales::percent_format()) +
  facet_wrap(~year) +
  ggthemes::theme_clean()

stations_yearly_lsoa %>%  
  filter(year %in% c(2010, 2012, 2014, 2019)) %>%
  # mutate(n_year = sum(year == year)) %>% View()
  ggplot(aes(`Income decile`)) +
  geom_bar(data = lsoa_lnd_joined, aes(`Income decile`, y=..count../sum(..count..)), fill = "grey", width = .95) +
  geom_bar(aes(y=..count../sum(..count..)), fill = "blue", width = .60, alpha = 0.7) +
  scale_y_continuous(labels = scales::percent_format()) +
  facet_wrap(~year) 

stations_yearly_4 = stations_yearly_lsoa %>% 
  filter(year %in% c(2010, 2012, 2014, 2019)) %>%
  sf::st_drop_geometry() %>% 
  group_by(year) %>% 
  mutate(n_year = n()) %>% 
  ungroup() %>% 
  group_by(year, `Income decile`) %>% 
  summarise(
    n_decile_year = n(),
    n_year = unique(n_year),
    s = diff(range(n_year)),
  ) %>% 
  mutate(p = n_decile_year / n_year) %>% 
  group_by(year) %>% 
  mutate(t = sum(p))

stations_yearly_4 %>% ggplot() +
  geom_bar(data = lsoa_lnd_joined, aes(`Income decile`, y=..count../sum(..count..) * 4), fill = "grey", width = .95) +
  geom_bar(aes(`Income decile`, p), stat = "identity", fill = "blue", width = .60, alpha = 0.7) +
  scale_y_continuous(labels = scales::percent_format()) +
  facet_wrap(~year) +
  ylab("Proportion of docking stations in each income decile") 

ggsave("figures/stations-imd-facet-4-grey.png", width = 6, height = 5.5)
magick::image_read("figures/stations-imd-facet-4-grey.png")