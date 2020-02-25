# Aim: get and visualise London summary data on cycle hire schemes

library(rvest)
library(tidyverse)

h = read_html("https://oobrien.com/2019/07/then-there-were-eight/")
(h_tables = h %>% html_nodes("table")) 
(lnd_bikeshare = h_tables %>% html_table(fill = TRUE))
lnd_bikeshare = lnd_bikeshare[[1]]
bike_companies = tibble::tibble(
  Company = as.character(lnd_bikeshare[1, ])[-1],
  Year = as.character(lnd_bikeshare[2, ])[-1],
  N_bikes = as.numeric(lnd_bikeshare[3, ])[-1]
  )
ggplot(bike_companies) +
  geom_col(aes(reorder(Company, -N_bikes), N_bikes, fill = Year)) +
  xlab("")
ggsave("figures/london-bike-hire-players.png")

bike_companies$N_bikes[1] / sum(bike_companies$N_bikes)
