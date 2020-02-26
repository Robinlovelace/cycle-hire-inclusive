# remotes::install_github("DavisVaughan/slide")
# library(ggplot2)
# u = "https://data.london.gov.uk/download/number-bicycle-hires/ac29363e-e0cb-47cc-a97a-e216d900a6b0/tfl-daily-cycle-hires.xls"
# download.file(u, "tfl-daily-cycle-hires.xls")
# daily_hires_schema = readxl::read_excel("tfl-daily-cycle-hires.xls")
# daily_hires = readxl::read_excel("tfl-daily-cycle-hires.xls", sheet = 2) # fails
# file.size("tfl-daily-cycle-hires.xls") / 1e6
# system("xlsx2csv -s 2 tfl-daily-cycle-hires.xls > tfl-daily-cycle-hires.csv")
# See https://github.com/dilshod/xlsx2csv
# daily_hires = readr::read_csv("tfl-daily-cycle-hires.csv")
# daily_hires
# class(daily_hires$Day)
# daily_hires$Day = lubridate::mdy(daily_hires$Day)
# range(daily_hires$Day)
# daily_hires = dplyr::filter(daily_hires, Day <= "2019-12-31")
# names(daily_hires)[2] = "Number of hires"
# daily_hires$Monthly = slide::slide_dbl(daily_hires$`Number of hires`, ~mean(.x), .before = 30)
# daily_hires$Yearly = slide::slide_dbl(daily_hires$`Number of hires`, ~mean(.x), .before = 365)
# daily_hires$Day = as.Date(daily_hires$Day)
# class(daily_hires$Day)



drake::loadd(trips_df)
trips_per_year = trips_df %>%
  group_by(year_month) %>%
  summarise(
    total = n()
  )
g = ggplot(trips_per_year) +
  geom_line(aes(year_month, total), col = "grey")
g

trips_per_day = trips_df %>%
  mutate(Day = as.Date(start_time)) %>%
  group_by(Day) %>%
  summarise(
    total_csvs = n()
  )

if(!file.exists("daily_hires.Rds")) {
  message("Download the daily hires file, from the releases. Trying with piggyback")
  piggyback::pb_download("daily_hires.Rds")
}
trips_per_day_xls = readRDS("daily_hires.Rds")
trips_daily = left_join(trips_per_day_xls, trips_per_day)

trips_daily$Monthly_raw = slide::slide_dbl(trips_daily$total_csvs, ~mean(.x, na.rm = TRUE), .before = 30)
trips_daily$Yearly_raw = slide::slide_dbl(trips_daily$total_csvs, ~mean(.x), .before = 365)


g = ggplot(trips_daily, aes(Day, `Number of hires`)) +
  geom_point(alpha = 0.1, colour = "blue") +
  geom_line(aes(Day, Monthly), lwd = 0.3, colour = "blue") +
  geom_line(aes(Day, Yearly), colour = "blue", lwd = 0.3, linetype = 2) +
  # csv data
  geom_point(aes(y = total_csvs), colour = "black", alpha = 0.1) +
  geom_line(aes(Day, Monthly_raw), colour = "black") +
  # geom_line(aes(Day, Yearly_raw), colour = "grey", lwd = 1) +
  ylim(c(0, 50000)) +
  xlim(as.POSIXlt(c("2010-01-01", "2019-10-01"))) +
  ylab("Number of cycle hire events per day") +
  # scale_x_continuous(breaks = 2010:2020)
  # scale_x_date(breaks = lubridate::ymd(paste0(2010:2020, "-01-01")))
  scale_x_date(date_breaks = "1 year", date_labels = "%Y", name = "Year")

g
ggsave("figures/cycle-hire-chart-daily.png", plot = g, width = 8, height = 3)
magick::image_read("figures/cycle-hire-chart-daily.png")

summary({na_trips = trips_daily$total_csvs})
summary(trips_daily$Day[is.na(na_trips)])

cor(trips_daily$`Number of hires`, trips_daily$total_csvs, use = "complete.obs")^2
# saveRDS(daily_hires, "daily_hires.Rds")

# monthly_hires = daily_hires %>% 
#   group_by(month_floor) %>% 
#   summarise(n = n())
# 
# ggsave("figures/cycle-hire-chart-daily.png", width = 6, height = 3)
