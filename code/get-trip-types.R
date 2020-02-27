# Derive df of trip types based on time of day and day of week trip was made.

# library(tidyverse)
# library(lubridate)

# Download trips data
# piggyback::pb_download("trips_df_all.fst")
# trips <- fst::read_fst("trips_df_all.fst")

# Trip type time bins.
am_peak_int <- interval(hms::as_hms("06:00:00"), hms::as_hms("09:59:59"))
pm_peak_int <- interval(hms::as_hms("16:00:00"), hms::as_hms("20:59:59"))
interpeak_int <- interval(hms::as_hms("10:00:00"), hms::as_hms("15:59:59"))
night_int <- interval(hms::as_hms("21:00:00"), as.POSIXct(hms::as_hms("05:59:59"))+days(1))

# Label with temporal trip types.
trip_types <- trips %>%
  mutate(
    # Calculate trip duration in minutes.    
    start_time=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    stop_time=as.POSIXct(stop_time, format="%Y-%m-%d %H:%M:%S"),
    duration=as.numeric(as.duration(stop_time-start_time),"minutes"),
    # Label day-of-week
    day=wday(start_time, label=TRUE),
    wkday=as.numeric(!day %in% c("Sat", "Sun")),
    month=month(start_time, label=TRUE),
    year=year(start_time),
    # Label temporal trip type
    t=as.POSIXct(hms::as_hms(start_time)),
    am_peak=if_else(wkday==1, 
                    as.numeric(t %within% am_peak_int),0),
    pm_peak=if_else(wkday==1, 
                    as.numeric(t %within% pm_peak_int),0),
    interpeak=if_else(wkday==1, 
                      as.numeric(t %within% interpeak_int),0),
    night=as.numeric(t %within% night_int),
    weekend=if_else(wkday==0, as.numeric(!t %within% night_int),0),
    o_station=start_station_id,
    d_station=end_station_id
  ) %>% 
  select(start_time, am_peak, pm_peak, interpeak, night, weekend, o_station, d_station)

trip_types <- fst::write_fst(trip_types,"./data/trips_types.fst")
