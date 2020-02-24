# Aim: get and visualise global summary data on cycle hire schemes

library(rvest)
library(tidyverse)

h = read_html("https://en.wikipedia.org/wiki/List_of_bicycle-sharing_systems")
# h = read_html("https://oobrien.com/2019/07/then-there-were-eight/")
(h_tables = h %>% html_nodes("table")) 
(bikeshare_tables = h_tables %>% html_table(fill = TRUE))
length(bikeshare_tables)
lapply(bikeshare_tables, class)
lapply(bikeshare_tables, ncol)
lapply(bikeshare_tables, row)
lapply(bikeshare_tables, names)
head(bikeshare_tables[[2]]) # it's the second table
bikeshare_table = bikeshare_tables[[2]] %>% as_tibble()
lapply(bikeshare_table, class) # all character
bikeshare_table = bikeshare_table %>%  mutate_at(vars(matches("Stations|Bicycles|riders")), .funs = as.numeric)
readr::write_csv(bikeshare_table, "bikeshare_table.csv")

# cleaning
bikeshare_table = bikeshare_table %>% 
  mutate(Launched = as.numeric(str_extract(string = Launched, pattern = "[0-9]{4}"))) %>% # extract year
  mutate(City = str_replace_all(City, '\\[|\\]|[0-9]+|\"|\\(|\\)|England', "")) %>% # remove notes
  mutate(City = str_trim(City)) %>% # remove trailing whitespace
  filter(Stations > 10) %>% 
  filter(!City == "Paris") %>% 
  mutate(City = str_replace_all(City, 'Grand ', "")) %>% # Grand Paris > Paris
  arrange(desc(Stations))

table(bikeshare_table$Country)

bikeshare_table %>% filter(is.na(Launched))

country_continent_table = spData::world %>% 
  sf::st_drop_geometry() %>% 
  select(name_long, continent) %>% 
  rename(Country = name_long, Continent = continent)

bikeshare_table = left_join(bikeshare_table, country_continent_table)
bikeshare_table$Continent[is.na(bikeshare_table$Continent)] = "Asia"

# which are the biggest?
bikeshare_table %>% 
  slice(1:10)

# sample bikeshare schemes
set.seed(1)
bikeshare_labels = bind_rows(
  bikeshare_table %>% top_n(n = 10, wt = Stations),
  bikeshare_table %>% sample_n(size = 10)
) %>% 
  mutate(col = case_when(str_detect(City, "London") ~ "red", TRUE ~ "white"))
bikeshare_table %>% 
  ggplot(aes(Stations, Bicycles)) +
  geom_point(aes(colour = Continent)) +
  scale_x_log10() +
  scale_y_log10(labels = scales::comma) +
  ggrepel::geom_label_repel(data = bikeshare_labels, aes(Stations, Bicycles, label = City, fill = col), alpha = 0.5, show.legend = FALSE) +
  scale_fill_manual(values = c("yellow", NA)) +
  theme(legend.position = c(.9, .2))
ggsave("figures/bikehshare-global-stations-bicycles.png")

bikeshare_core = bikeshare_table %>% 
  select(Country, City, Launched, Stations, Bicycles, Continent)

readr::write_csv(bikeshare_core, "bikeshare_table_clean.csv")
bikeshare_growth = bikeshare_core %>%
  filter(!is.na(Launched)) %>% 
  group_by(Launched) %>%
  summarise(Stations = sum(Stations), Bicycles = sum(Bicycles, na.rm = TRUE)) %>% 
  mutate(`Total stations` = cumsum(Stations)) %>% 
  ungroup()  
bikeshare_growth_continent = bikeshare_core %>%
  filter(!is.na(Launched)) %>% 
  group_by(Continent, Launched) %>%
  summarise(Stations = sum(Stations), Bicycles = sum(Bicycles, na.rm = TRUE)) %>% 
  mutate(`Total stations` = cumsum(Stations)) %>% 
  ungroup() 

g1 = bikeshare_growth_continent %>% ggplot(aes(Launched, `Total stations`)) +
  theme(legend.position = c(0.1, 0.8)) +
  geom_line(aes(colour = Continent, group = Continent), size = 2) +
  xlim(c(2005, 2020)) +
  ylab("Number of docking stations") +
  theme(legend.position = c(0.1, 0.8))
g1

ggsave("figures/bikehshare-global-stations-growth.png")
g2 = bikeshare_growth %>% ggplot(aes(Launched, `Total stations`)) +
  geom_line(size = 3) +
  theme(legend.position = c(0.1, 0.8)) +
  geom_line(aes(colour = Continent, group = Continent), data = bikeshare_growth_continent, size = 2) +
  xlim(c(2005, 2020)) +
  theme(legend.position = c(0.1, 0.8))
g2

g2 = bikeshare_growth_continent %>% ggplot(aes(Launched, `Total stations`)) +
  geom_line(aes(colour = Continent, group = Continent)) +
  xlim(c(2005, 2020)) +
  theme(legend.position = c(0.1, 0.8))
g2
ggsave("figures/bikehshare-global-stations-growth2.png")


# biggest countries for bikeshare
bikeshare_countries = bikeshare_table %>% 
  group_by(Country) %>% 
  summarise(n = n()) %>% 
  arrange(desc(n)) 
bikeshare_top_10_countries = bikeshare_countries$Country[1:10]
# bikeshare_table = bikeshare_table %>% rename(Country_all = Country) %>% 
#   mutate(Country = case_when(Country_all %in% bikeshare_top_10_countries ~ Country_all,
#                              TRUE ~ "Other"))
# top countries: best as a table
