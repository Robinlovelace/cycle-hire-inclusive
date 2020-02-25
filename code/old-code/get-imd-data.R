# Aim: get imd data across london

# IMD data (at LSOA level)
lsoa = ukboundaries::lsoa2011_simple
lsoa_cents = sf::st_centroid(lsoa)
lsoa_lnd_cents = lsoa_cents[spData::lnd, ]
lsoa_lnd = lsoa %>% filter(lsoa11cd %in% lsoa_lnd_cents$lsoa11cd)

imd = readr::read_csv("imd2015eng.csv")
imd = imd %>% 
  rename(lsoa11cd = `LSOA code (2011)`) %>% 
  select(`Income decile` = `Income Decile (where 1 is most deprived 10% of LSOAs)`, lsoa11cd)
lsoa_lnd_joined = inner_join(lsoa_lnd, imd)

plot(lsoa_lnd_joined["Income decile"])
