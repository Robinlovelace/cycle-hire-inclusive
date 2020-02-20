remotes::install_github("DavisVaughan/slide")
library(ggplot2)
u = "https://data.london.gov.uk/download/number-bicycle-hires/ac29363e-e0cb-47cc-a97a-e216d900a6b0/tfl-daily-cycle-hires.xls"
download.file(u, "tfl-daily-cycle-hires.xls")
# daily_hires_schema = readxl::read_excel("tfl-daily-cycle-hires.xls")
# daily_hires = readxl::read_excel("tfl-daily-cycle-hires.xls", sheet = 2) # fails
# file.size("tfl-daily-cycle-hires.xls") / 1e6
system("xlsx2csv -s 2 tfl-daily-cycle-hires.xls > tfl-daily-cycle-hires.csv")
# See https://github.com/dilshod/xlsx2csv
daily_hires = readr::read_csv("tfl-daily-cycle-hires.csv")
daily_hires
class(daily_hires$Day)
daily_hires$Day = lubridate::mdy(daily_hires$Day)
range(daily_hires$Day)
daily_hires = dplyr::filter(daily_hires, Day <= "2019-12-31")
names(daily_hires)[2] = "Number of hires"
daily_hires$Monthly = slide::slide_dbl(daily_hires$`Number of hires`, ~mean(.x), .before = 30)
daily_hires$Yearly = slide::slide_dbl(daily_hires$`Number of hires`, ~mean(.x), .before = 365)
daily_hires$Day = as.Date(daily_hires$Day)
class(daily_hires$Day)
ggplot(daily_hires, aes(Day, `Number of hires`)) +
  geom_point(alpha = 0.1) +
  geom_line(aes(Day, Monthly), lwd = 1) +
  geom_line(aes(Day, Yearly), colour = "blue", lwd = 1) +
  xlab("Year") +
  ylim(c(0, 50000)) +
  xlim(as.POSIXlt(c("2010-01-01", "2019-10-01"))) +
  ylab("Number of cycle hire events per day") +
  # scale_x_continuous(breaks = 2010:2020)
  # scale_x_date(breaks = lubridate::ymd(paste0(2010:2020, "-01-01")))
  scale_x_date(date_breaks = "1 year", date_labels = "%Y")
daily_hires$month_floor = lubridate::floor_date(daily_hires$Day, unit = "month")

saveRDS(daily_hires, "daily_hires.Rds")

monthly_hires = daily_hires %>% 
  group_by(month_floor) %>% 
  summarise(n = n())

ggsave("figures/cycle-hire-chart-daily.png", width = 6, height = 3)
