# Yuanxuan's and Roger's treatment of stations and hires data for cleaning ----

# EDIT : start with CDRC stations dataset
# piggyback::pb_download(file="bikelocations_london.csv",repo="Robinlovelace/cycle-hire-inclusive", dest="./data/")
# piggyback::pb_upload(file="./data/bikelocations_london.csv", name="bikelocations_london.csv", repo="Robinlovelace/cycle-hire-inclusive")
# stations <- read_csv("./data/bikelocations_london.csv")

# Start with 77.7m trips data



# Data Cleaning:

library(tidyverse)
library(fst)
library(sf)
library(tmap)
library(lubridate)

stations <- read_csv("./data/bikelocations_london.csv")
trips_df <- read_fst("data/trips-2020-02.fst")

trips_df$start_time<-lubridate::ymd_hms(trips_df$start_time)
trips_df$stop_time<-lubridate::ymd_hms(trips_df$stop_time) 


# Remove duplicates records and records without time info.
trips_df <- trips_df %>% 
  distinct(start_time, stop_time, start_station_id, end_station_id) %>%
  filter(!(is.na(start_time)|is.na(stop_time))) 
trips_df$id=c(1:nrow(trips_df)) # adding a trip id column, it will be used for modifying start and end stations later

# Identify how many stations (same ID) have multiple locations (different lat/lon)
station_locations_check<-stations %>% distinct(ucl_id,lat,lon) %>%
  group_by(ucl_id) %>% summarise(num_loc=n())
print(paste0("There are ",station_locations_check %>% filter(num_loc>=2) %>% nrow," stations (stationID) have multiple locations (coordinates):"))


#derive these multi-location stations records from raw CDRC station data
station_multi_locations <- station_locations_check %>% filter(num_loc>=2)
station_multi_locations.vector <- station_multi_locations$ucl_id
station_multi_locations<- stations %>% filter(ucl_id %in% station_multi_locations.vector)
station_single_location<- stations %>% filter(!ucl_id %in% station_multi_locations.vector) %>%
  filter(!ucl_id %in% c(824,822,791))  %>% # the three stations are for test/workshop purpose and need to be deleted
  dplyr::distinct(ucl_id,.keep_all=T)  # Some stations, although have only one location (coordinate), may still have multiple data records
                                       # E.g. THE station (ucl id - 540), have two records, one's operator_name is "Albany Street, Regent's Park",  and another is "Albany Street, The Regent's Park"
                                       # These similar (duplicated ) records are removed by using distict function

# convert dataframe to sf
station_single_location_sf<-st_as_sf(station_single_location,coords=c("lon","lat")) %>% st_set_crs(4326)

station_multi_locations_sf<-st_as_sf(station_multi_locations,coords = c("lon","lat")) %>% st_set_crs(4326)




# plot multi-location stations
tmap_mode("view")
tm_shape(station_multi_locations_sf)+tm_dots()
# Some stations records are found to be located outside of London, they are wrong  and will be removed
tmap_mode("plot")

#Firstly, delete stations that locate outside of London, they have wrong coordinates information


station_multi_locations_sf<-station_multi_locations %>% 
  filter(lon<=0.002342,lon>=-0.216573,lat<=51.549369,lat>=51.450531) %>% # remove wrong records outside of London
  st_as_sf(coords = c("lon","lat")) %>% st_set_crs(4326) %>% 
  filter(!operator_name %in% c("Pop Up Dock 1",
                               "Pop Up Dock 2")) %>% # Remove Pop Up Docks
  dplyr::arrange(ucl_id,created_dt)
  

# Check the station data - as shown in the map, wrong records (outside of London) has been removed
tmap_mode("view")
tm_shape(station_multi_locations_sf)+tm_dots()+
  tm_shape(station_single_location_sf)+tm_dots(col="red")
# Some stations records are found to be located outside of London, they are wrong  and will be removed
tmap_mode("plot")

# Because of service/system upgrade etc., Station may move to a nearby location that is very close to the original place
# In this case they can be regarded as "no significant changes had happened spatially", and we will keep only one of them and remove other redundant records.
# The examination and decision on which to delete was done manually, by checking the walking ditance using google maps.
# Here we start to remove the redundant records:


station_multi_locations_sf <- station_multi_locations_sf %>% 
  filter((!((ucl_id==20)&(created_dt==as.POSIXct("2010-08-06 01:00:00",tz = "UTC")))), # for ucl_id 20
         (!((ucl_id==33)&(created_dt %in% as.POSIXct(c("2010-08-06 01:00:00",
                                                       "2016-02-23 16:04:01",
                                                       "2016-04-20 10:08:07"),tz="UTC")))), # for ucl_id 33
         (!((ucl_id==41)&(created_dt==as.POSIXct("2010-08-06 01:00:00", tz = "UTC")))), # for ucl_id 41
         (!((ucl_id==45)&(created_dt==as.POSIXct("2010-08-06 01:00:00", tz = "UTC")))), # for ucl_id 45
         (!((ucl_id==134)&(created_dt==as.POSIXct("2010-08-06 01:00:00", tz = "UTC")))), # for ucl_id 134
         (!((ucl_id==153)&(created_dt==as.POSIXct("2010-08-06 01:00:00", tz = "UTC")))), # for ucl_id 153
         (!((ucl_id==173)&(created_dt %in% as.POSIXct(c("2011-06-29 15:40:02",
                                                        "2013-07-09 11:26:09"), tz = "UTC")))), # for ucl_id 173
         (!((ucl_id==174)&(created_dt==as.POSIXct("2011-06-29 15:40:02", tz = "UTC")))), # for ucl_id 174
         (!((ucl_id==175)&(created_dt %in% as.POSIXct(c("2010-08-06 01:00:00",
                                                        "2018-06-22 14:46:02",
                                                        "2018-08-29 11:00:03"), tz = "UTC")))), # for ucl_id 175
         (!((ucl_id==183)&(created_dt==as.POSIXct("2015-06-15 15:36:02", tz = "UTC")))), # for ucl_id 183
         (!((ucl_id==199)&(created_dt %in% as.POSIXct(c("2019-05-02 19:41:03",
                                                        "2019-05-02 20:10:02", # This record also contains wrong coordinates and needs to be removed
                                                        "2019-05-02 20:35:24",
                                                        "2019-05-02 20:36:10",
                                                        "2019-05-02 20:40:16",
                                                        "2019-05-02 20:45:16",
                                                        "2019-05-02 20:49:13",
                                                        "2019-05-02 20:50:24",
                                                        "2019-05-02 20:54:22",
                                                        "2019-05-02 21:09:19",
                                                        "2019-05-03 01:40:35",
                                                        "2019-05-03 02:44:16"), tz = "UTC")))), # for ucl_id 199
         (!((ucl_id==225)&(created_dt==as.POSIXct("2010-08-06 01:00:00", tz = "UTC")))), # for ucl_id 225
         (!((ucl_id==237)&(created_dt==as.POSIXct("2010-08-06 01:00:00", tz = "UTC")))), # for ucl_id 237
         (!((ucl_id==247)&(created_dt %in% as.POSIXct(c("2010-10-08 01:00:00",
                                                        "2010-08-06 01:00:00", # This record also contains wrong coordinates and needs to be removed
                                                        "2015-05-21 14:48:02"), tz = "UTC")))), # for ucl_id 247
         (!((ucl_id==251)&(created_dt==as.POSIXct("2010-08-06 01:00:00", tz = "UTC")))), # for ucl_id 251
         (!((ucl_id==259)&(created_dt %in% as.POSIXct(c("2018-04-12 11:16:02",
                                                        "2010-10-08 01:00:00", 
                                                        "2011-02-01 00:00:00"), tz = "UTC")))), # for ucl_id 259
         (!((ucl_id==300)&(created_dt==as.POSIXct("2010-08-06 01:00:00", tz = "UTC")))), # for ucl_id 300
         (!((ucl_id==322)&(created_dt %in% as.POSIXct(c("2011-06-29 15:40:02",
                                                        "2011-11-29 17:01:06"), tz = "UTC")))), # for ucl_id 322
         (!((ucl_id==327)&(created_dt==as.POSIXct("2010-08-06 01:00:00", tz = "UTC")))), # for ucl_id 327
         (!((ucl_id==328)&(created_dt==as.POSIXct("2010-08-06 01:00:00", tz = "UTC")))), # for ucl_id 328
         (!((ucl_id==352)&(created_dt==as.POSIXct("2011-02-01 00:00:00", tz = "UTC")))), # for ucl_id 352
         (!((ucl_id==358)&(created_dt==as.POSIXct("2011-06-29 15:40:02", tz = "UTC")))), # for ucl_id 352
         (!((ucl_id==405)&(created_dt %in% as.POSIXct(c("2019-05-02 20:10:04",
                                                        "2019-05-02 20:20:12", 
                                                        "2019-05-03 04:18:13",
                                                        "2019-05-02 17:24:04",
                                                        "2019-05-03 02:52:08",
                                                        "2019-05-03 04:15:10",
                                                        "2019-05-02 18:42:28"), tz = "UTC")))), # for ucl_id 405
         (!((ucl_id==406)&(created_dt==as.POSIXct("2011-06-29 15:40:02", tz = "UTC")))), # for ucl_id 406
         (!(ucl_id==407)), # for ucl_id 407 ; it should be noted that the station 406 and 407 have the same coord, so they are merged into one. we removed 407 and only keeped 406.
         (!((ucl_id==410)&(created_dt %in% as.POSIXct(c("2011-06-29 15:40:02",
                                                        "2011-11-29 17:01:06"), tz = "UTC")))), # for ucl_id 410
         (!((ucl_id==428)&(created_dt %in% as.POSIXct(c("2018-04-26 23:00:03",
                                                        "2011-11-29 17:01:06", 
                                                        "2012-03-12 11:20:17",
                                                        "2018-04-26 23:02:03",
                                                        "2018-05-08 16:50:03",
                                                        "2013-07-09 11:26:09"), tz = "UTC")))), # for ucl_id 428
         (!((ucl_id==432)&(created_dt %in% as.POSIXct(c("2013-07-09 11:26:09",
                                                        "2018-04-26 23:00:03"), tz = "UTC")))), # for ucl_id 432
         (!((ucl_id==443)&(created_dt==as.POSIXct("2012-03-12 11:20:17", tz = "UTC")))), # for ucl_id 443
         (!((ucl_id==497)&(created_dt %in% as.POSIXct(c("2012-03-12 11:20:17",
                                                        "2019-07-08 10:08:02", 
                                                        "2016-06-15 09:10:02"), tz = "UTC")))), # for ucl_id 497
         (!((ucl_id==501)&(created_dt %in% as.POSIXct(c("2019-05-02 18:42:40",
                                                        "2019-05-02 18:45:08", 
                                                        "2019-05-02 20:00:42"), tz = "UTC")))), # for ucl_id 501
         (!((ucl_id==551)&(created_dt %in% as.POSIXct(c("2012-03-12 11:20:17",
                                                        "2018-07-19 15:02:04"), tz = "UTC")))), # for ucl_id 551
         (!((ucl_id==557)&(created_dt==as.POSIXct("2012-03-12 11:20:17", tz = "UTC")))), # for ucl_id 557
         (!((ucl_id==558)&(created_dt==as.POSIXct("2013-07-09 11:26:09", tz = "UTC")))), # for ucl_id 558
         (!((ucl_id==562)&(created_dt==as.POSIXct("2012-03-12 11:20:17", tz = "UTC")))), # for ucl_id 562
         (!((ucl_id==568)&(created_dt==as.POSIXct("2012-03-12 11:20:17", tz = "UTC")))), # for ucl_id 568
         (!((ucl_id==569)&(created_dt==as.POSIXct("2012-03-12 11:20:17", tz = "UTC")))), # for ucl_id 569
         (!((ucl_id==588)&(created_dt==as.POSIXct("2012-03-12 11:20:17", tz = "UTC")))), # for ucl_id 588
         (!((ucl_id==592)&(created_dt==as.POSIXct("2012-03-12 11:20:17", tz = "UTC")))), # for ucl_id 592
         (!((ucl_id==629)&(created_dt %in% as.POSIXct(c("2019-05-02 16:08:11", "2019-05-02 16:38:18", "2019-05-02 16:42:16", 
                                                        "2019-05-02 16:54:27", "2019-05-02 17:28:07", "2019-05-02 17:38:16", 
                                                        "2019-05-02 17:43:06", "2019-05-02 22:12:06", "2019-05-02 22:25:40",
                                                        "2019-05-02 22:41:47", "2019-05-03 02:02:17", "2019-05-03 02:36:40", 
                                                        "2019-05-03 02:52:08", "2019-05-03 03:29:12", "2019-05-03 03:40:03", 
                                                        "2019-05-03 04:14:16", "2019-05-03 04:20:06", "2019-05-03 05:26:14"), tz = "UTC")))), # for ucl_id 629
         (!((ucl_id==707)&(created_dt %in% as.POSIXct(c("2019-05-02 19:04:20", "2019-05-02 19:28:46", "2019-05-02 19:58:02",
                                                        "2019-05-02 20:00:35", "2019-05-02 22:41:46", "2019-05-03 03:30:28", 
                                                        "2019-05-03 03:30:51", "2019-05-03 03:36:01"), tz = "UTC")))), # for ucl_id 707
         (!((ucl_id==725)&(created_dt==as.POSIXct("2014-02-19 18:15:01", tz = "UTC")))), # for ucl_id 725
         (!((ucl_id==780)&(created_dt==as.POSIXct("2015-08-14 18:26:08", tz = "UTC")))), # for ucl_id 780
         (!((ucl_id==781)&(created_dt %in% as.POSIXct(c("2015-11-24 15:22:02",
                                                        "2016-04-01 11:50:01",
                                                        "2017-03-28 12:14:02"), tz = "UTC")))), # for ucl_id 781
         (!((ucl_id==782)&(created_dt==as.POSIXct("2015-11-24 15:24:01", tz = "UTC")))), # for ucl_id 782
         (!((ucl_id==783)&(created_dt %in% as.POSIXct(c("2015-11-26 09:26:01",
                                                        "2016-01-12 14:50:02",
                                                        "2016-01-21 10:02:02"), tz = "UTC")))), # for ucl_id 783
         (!((ucl_id==784)&(created_dt %in% as.POSIXct(c("2016-01-11 14:18:02",
                                                        "2016-01-21 10:02:02"), tz = "UTC")))), # for ucl_id 784
         (!((ucl_id==786)&(created_dt %in% as.POSIXct(c("2016-01-20 21:42:02",
                                                        "2016-01-21 10:02:02"), tz = "UTC")))), # for ucl_id 786
         (!((ucl_id==787)&(created_dt %in% as.POSIXct(c("2016-01-20 22:00:01",
                                                        "2016-01-21 10:02:02"), tz = "UTC")))), # for ucl_id 787
         (!((ucl_id==788)&(created_dt %in% as.POSIXct(c("2016-01-20 20:32:02",
                                                        "2016-01-21 10:00:02",
                                                        "2016-01-27 12:40:02"), tz = "UTC")))), # for ucl_id 788
         (!((ucl_id==789)&(created_dt %in% as.POSIXct(c("2016-01-20 20:02:02",
                                                        "2016-01-21 10:02:02",
                                                        "2016-01-26 14:30:02"), tz = "UTC")))), # for ucl_id 789
         (!((ucl_id==790)&(created_dt==as.POSIXct("2016-03-03 18:06:02", tz = "UTC")))), # for ucl_id 790
         (!((ucl_id==794)&(created_dt==as.POSIXct("2016-04-13 13:00:02", tz = "UTC")))), # for ucl_id 794
         (!((ucl_id==795)&(created_dt %in% as.POSIXct(c("2016-02-22 11:24:06",
                                                        "2016-03-31 14:02:02",
                                                        "2016-04-03 03:44:02"), tz = "UTC")))), # for ucl_id 795
         (!((ucl_id==820)&(created_dt==as.POSIXct("2016-12-19 19:36:02", tz = "UTC")))), # for ucl_id 820
         (!((ucl_id==829)&(created_dt %in% as.POSIXct(c("2018-01-16 11:58:03",
                                                        "2019-05-02 18:52:34",
                                                        "2019-05-02 19:59:48"), tz = "UTC")))), # for ucl_id 829
         (!((ucl_id==833)&(created_dt==as.POSIXct("2018-02-07 14:12:02", tz = "UTC")))), # for ucl_id 833
         (!((ucl_id==839)&(created_dt==as.POSIXct("2018-08-29 11:58:04", tz = "UTC")))) # for ucl_id 820 , this record contains wrong coords info, needs to be removed
         
         )



# Combine single location station and mult-location stations - as station location clean for later processing

station_locations_clean<-rbind(station_single_location_sf,station_multi_locations_sf) %>%
  arrange(ucl_id,operator_intid)

#Check 
station_location_summarise<-station_locations_clean %>% 
  group_by(ucl_id) %>% dplyr::summarise(num=n()) %>%
  arrange(desc(num),ucl_id)

print(station_location_summarise %>% filter(num>=2))


# There are also some station (identified by the "ucl_id") significantly changed their locations
# They need further investigation and should be examined saperatly.
# Their ucl_id is listed as follows:

# ucl_id 5
# ucl_id 8
# ucl_id 29
# ucl_id 46
# ucl_id 79
# ucl_id 82
# ucl_id 131
# ucl_id 148
# ucl_id 154
# ucl_id 173
# ucl_id 174
# ucl_id 183
# ucl_id 302
# ucl_id 259
# ucl_id 316
# ucl_id 322
# ucl_id 323
# ucl_id 360
# ucl_id 502
# ucl_id 725



# ucl id 5-----------------------------
station_5_start_trips<-trips_df %>% filter(start_station_id==5)

station_5_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2011-01")&
           (year_month <="2020-01")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2012/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )


# The bike trip number seems right and consistent over the whole period
# google street view : Both locations have docking stations
# https://www.google.com/maps/place/51%C2%B031'00.8%22N+0%C2%B009'29.7%22W/@51.5169514,-0.1584859,3a,75y,176.33h,75.9t/data=!3m7!1e1!3m5!1stU4FLFeQg8V98FDjeVheGA!2e0!5s20180101T000000!7i16384!8i8192!4m5!3m4!1s0x0:0x0!8m2!3d51.516893!4d-0.15825
# https://www.google.com/maps/place/51%C2%B029'35.3%22N+0%C2%B009'24.8%22W/@51.493309,-0.1568413,3a,75y,201.39h,61.29t/data=!3m7!1e1!3m5!1soL4scRTillgJcgAAyVJCHw!2e0!6s%2F%2Fgeo2.ggpht.com%2Fmaps%2Fphotothumb%2Ffd%2Fv1%3Fbpb%3DCicKJXNlYXJjaC5nd3MtcHJvZC9tYXBzL3Jldmdlb19hbmRfZmV0Y2gSIAoSCUs82iIWBXZIEQBk52CHTui3KgoNAAAAABUAAAAAGgQIVhBW%26gl%3DGB!7i16384!8i8192!4m5!3m4!1s0x0:0x0!8m2!3d51.49313!4d-0.156876
# Further investigation suggested that
# there is a wrong record of ucl_id 5, it acutally duplicated the information of station ucl_403, this should be deleted. 
# Solution as follows:
station_locations_clean<-station_locations_clean %>% filter(!((ucl_id==5)&(operator_name=="George Place Mews, Marylebone")))
rm(station_5_start_trips)
#-----Compeleted---end of ucl_id 5, 

# ucl id 8------------------------------------------------------------------------------
station_8_start_trips<-trips_df %>% filter(start_station_id==8)

plot_monthly_trips <- station_8_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2012-01")&
           (year_month <="2020-01")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2012/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )
plot_monthly_trips

# The bike trip number significantly changed as shown in the plot, and there is no bike trip during 2018/09/25 to 2018/10/24----------
# Therefore, the change time can be identified
# google street view
# https://www.google.com/maps/place/51%C2%B031'42.0%22N+0%C2%B010'12.5%22W/@51.5283934,-0.1699395,3a,75y,252.73h,90t/data=!3m8!1e1!3m6!1spvwD5xi-Wxro8rg-wabuyQ!2e0!5s20180101T000000!6s%2F%2Fgeo0.ggpht.com%2Fcbk%3Fpanoid%3DpvwD5xi-Wxro8rg-wabuyQ%26output%3Dthumbnail%26cb_client%3Dsearch.gws-prod%2Fmaps%2Frevgeo_and_fetch.gps%26thumb%3D2%26w%3D86%26h%3D86%26yaw%3D252.72705%26pitch%3D0%26thumbfov%3D100!7i16384!8i8192!4m5!3m4!1s0x0:0x0!8m2!3d51.528341!4d-0.170134
# https://www.google.com/maps/place/51%C2%B031'47.5%22N+0%C2%B011'00.6%22W/@51.5299428,-0.1833433,3a,75y,243.13h,85.72t/data=!3m8!1e1!3m6!1sorpfclfYrA-V2p9XEGT4cg!2e0!5s20190401T000000!6s%2F%2Fgeo1.ggpht.com%2Fcbk%3Fpanoid%3DorpfclfYrA-V2p9XEGT4cg%26output%3Dthumbnail%26cb_client%3Dsearch.gws-prod%2Fmaps%2Frevgeo_and_fetch.gps%26thumb%3D2%26w%3D86%26h%3D86%26yaw%3D224.13278%26pitch%3D0%26thumbfov%3D100!7i16384!8i8192!4m5!3m4!1s0x0:0x0!8m2!3d51.529857!4d-0.183486
# Solutions are as follows
# Change ucl_id 8 into 8001 and 8002 respetively, 
# 8001 is the station before 2018/09/25 ( using 2018/10/01 as the dividing point)
# 8002 is the station after 2018/10/24 ( using 2018/10/01 as the dividing point)

station_locations_clean[(station_locations_clean$ucl_id==8)&(station_locations_clean$created_dt<= as.POSIXct( "2018-10-01 00:00:00")),
                        "ucl_id"]<-8001
station_locations_clean[(station_locations_clean$ucl_id==8)&(station_locations_clean$created_dt>= as.POSIXct( "2018-10-01 00:00:00")),
                        "ucl_id"]<-8002

# The trip_df should be modified accordingly
station_8_start_trips_id_1<-trips_df %>% filter(start_station_id==8) %>% 
  filter(start_time<as.POSIXct("2018-10-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 8001 trips and derive their trip id in trips_df
trips_df$start_station_id[station_8_start_trips_id_1$id]=8001 # change their start_station_id from 8 to 8001

station_8_start_trips_id_2<-trips_df %>% filter(start_station_id==8) %>%
  filter(start_time>as.POSIXct("2018-10-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 8002 trips and derive their trip id in trips_df
trips_df$start_station_id[station_8_start_trips_id_2$id]=8002 # change their start_station_id from 8 to 8002

station_8_end_trips_id_1<-trips_df %>% filter(end_station_id==8) %>% 
  filter(stop_time<as.POSIXct("2018-10-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 8001 trips and derive their trip id in trips_df
trips_df$end_station_id[station_8_end_trips_id_1$id]=8001 # change their end_station_id from 8 to 8001

station_8_end_trips_id_2<-trips_df %>% filter(end_station_id==8) %>%
  filter(stop_time>as.POSIXct("2018-10-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 8002 trips and derive their trip id in trips_df
trips_df$end_station_id[station_8_end_trips_id_2$id]=8002 # change their end_station_id from 8 to 8002

rm(station_8_start_trips)
#---Completed---end of ucl_id 8


# ucl id 29------------------------------------------------------------------------------
station_29_start_trips<-trips_df %>% filter(start_station_id==29)

plot_monthly_trips <- station_29_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2012-01")&
           (year_month <="2020-01")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2012/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )
plot_monthly_trips

# the trip num pattern seems consistent, 
# A further investigation suggested a faulty station record(ucl_id 29) duplicated with ucl_id 131, therefore, we can simply delete the wrong one
station_locations_clean<-station_locations_clean %>% filter(!((ucl_id==29)&(operator_name=="Eversholt Street , Camden Town")))

rm(station_29_start_trips)
# Completed ------ end of ucl_id 29


# ucl id 46------------------------------------------------------------------------------
station_46_start_trips<-trips_df %>% filter(start_station_id==46)

plot_monthly_trips <- station_46_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2011-01")&
           (year_month <="2020-01")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2011/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )
plot_monthly_trips

# A investigation suggested a faulty station record(ucl_id 46) duplicated the information of ucl_id 402, therefore, we can simply delete the wrong one
station_locations_clean<-station_locations_clean %>% filter(!((ucl_id==46)&(operator_name=="Penfold Street, Marylebone")))

rm(station_46_start_trips)
#----Completed------End of ucl_id 46

# ucl id 79------------------------------------------------------------------------------
station_79_start_trips<-trips_df %>% filter(start_station_id==79)

plot_monthly_trips <- station_79_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2011-01")&
           (year_month <="2020-01")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2011/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )
plot_monthly_trips

# The bike trip number pattern changed, and there is no bike trip during 2013/03/29 to 2018/02/20
# Solutions are as follows:
# Change ucl_id 79 into 79001 and 79002 respetively, 
# 079001 is the station before 2013/03/29 (using 2015-12-01 00:00:00 as the dividing point)
# 079002 is the station after 2018/02/20 (using 2015-12-01 00:00:00 as the dividing point)

station_locations_clean[(station_locations_clean$ucl_id==79)&(station_locations_clean$created_dt<="2015-12-01 00:00:00"),
                        "ucl_id"]<-79001
station_locations_clean[(station_locations_clean$ucl_id==79)&(station_locations_clean$created_dt>="2015-12-01 00:00:00"),
                        "ucl_id"]<-79002




# The trip_df should be modified accordingly
station_79_start_trips_id_1<-trips_df %>% filter(start_station_id==79) %>% 
  filter(start_time<as.POSIXct("2015-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 79001 trips and derive their trip id in trips_df
trips_df$start_station_id[station_79_start_trips_id_1$id]=79001 # change their start_station_id from 79 to 79001

station_79_start_trips_id_2<-trips_df %>% filter(start_station_id==79) %>%
  filter(start_time>as.POSIXct("2015-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 79001 trips and derive their trip id in trips_df
trips_df$start_station_id[station_79_start_trips_id_2$id]=79002 # change their start_station_id from 79 to 79002

station_79_end_trips_id_1<-trips_df %>% filter(end_station_id==79) %>% 
  filter(stop_time<as.POSIXct("2015-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 79001 trips and derive their trip id in trips_df
trips_df$end_station_id[station_79_end_trips_id_1$id]=79001 # change their end_station_id from 79 to 79001

station_79_end_trips_id_2<-trips_df %>% filter(end_station_id==79) %>%
  filter(stop_time>as.POSIXct("2015-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 79002 trips and derive their trip id in trips_df
trips_df$end_station_id[station_79_end_trips_id_2$id]=79002 # change their end_station_id from 79 to 79002

rm(station_79_start_trips)
#--Completed--end of ucl_id 79------



# ucl id 82------------------------------------------------------------------------------
station_82_start_trips<-trips_df %>% filter(start_station_id==82)

plot_monthly_trips <- station_82_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2011-01")&
           (year_month <="2020-01")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2011/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )
plot_monthly_trips



# The trips number pattern is consistent
# Further Investigation suggested that the wrong record(ucl_id 82) duplicated with ucl_id 405, it needs to be removed
station_locations_clean<-station_locations_clean %>% filter(!((ucl_id==82)&(operator_name=="Gloucester Road Station, South Kensington")))

rm(station_82_start_trips)
#-----Completed-----end of ucl_id 82



# ucl id 131------------------------------------------------------------------------------
station_131_start_trips<-trips_df %>% filter(start_station_id==131)

plot_monthly_trips <- station_131_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2011-01")&
           (year_month <="2020-01")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2011/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )
plot_monthly_trips

# The bike trip number pattern is relatively continuous, 
# Further Investigation suggested that the wrong record(ucl_id 131) duplicates ucl_id 378, it needs to be removed
station_locations_clean<-station_locations_clean %>% filter(!((ucl_id==131)&(operator_name=="Natural History Museum, South Kensington")))

rm(station_131_start_trips)
#----Completed---end of ucl_id 138


# ucl id 148------------------------------------------------------------------------------
station_148_start_trips<-trips_df %>% filter(start_station_id==148)

plot_monthly_trips <- station_148_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2011-01")&
           (year_month <="2020-01")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2011/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )
plot_monthly_trips

# The bike trip number pattern is relatively continuous
# Further Investigation suggested that the wrong record(ucl_id 148) duplicates ucl_id 379, it needs to be removed
station_locations_clean<-station_locations_clean %>% filter(!((ucl_id==148)&(operator_name=="Turquoise Island, Notting Hill")))

rm(station_148_start_trips)
#----Completed----end for ucl_id 148--------------------



# ucl id 154------------------------------------------------------------------------------
station_154_start_trips<-trips_df %>% filter(start_station_id==154)

plot_monthly_trips <- station_154_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2011-01")&
           (year_month <="2020-01")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2011/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )
plot_monthly_trips

# The bike trip number pattern is relatively continuous, 
# Further Investigation suggested that the wrong record(ucl_id 154) duplicates ucl_id 360, it needs to be removed
station_locations_clean<-station_locations_clean %>% filter(!((ucl_id==154)&(operator_name=="Howick Place, Westminster")))

rm(station_154_start_trips)
#---Completed----end of ucl_id 154



# ucl id 173------------------------------------------------------------------------------
station_173_start_trips<-trips_df %>% filter(start_station_id==173)

plot_monthly_trips <- station_173_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2011-01")&
           (year_month <="2020-01")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2011/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )
plot_monthly_trips


# The bike trip number pattern is relatively consistent
# Further Investigation suggested that the wrong record(ucl_id 173) duplicated with ucl_id 148, it needs to be deleted

station_locations_clean<-station_locations_clean %>% filter(!((ucl_id==173)&(operator_name=="Tachbrook Street, Victoria")))

rm(station_173_start_trips)
#---Completed----end of ucl_id 173


# ucl id 174------------------------------------------------------------------------------
station_174_start_trips<-trips_df %>% filter(start_station_id==174)

plot_monthly_trips <- station_174_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2011-01")&
           (year_month <="2020-01")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2011/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )
plot_monthly_trips

# The bike trip number pattern is relatively continuous,
# Further Investigation suggested that the wrong record(ucl_id 174) duplicates ucl_id 427, it needs to be removed
station_locations_clean<-station_locations_clean %>% filter(!((ucl_id==174)&(operator_name=="Cheapside, Bank")))

rm(station_174_start_trips)
#---Completed----end of ucl_id 174

# ucl id 183------------------------------------------------------------------------------
station_183_start_trips<-trips_df %>% filter(start_station_id==183)

plot_monthly_trips <- station_183_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2011-01")&
           (year_month <="2020-01")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2011/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )
plot_monthly_trips


# There is no bike trip during 2013/07/03 to 2015/06/15---------
# Further investigation is needed
# update: the change is supported by google street view:
# https://www.google.com/maps/place/51%C2%B030'43.2%22N+0%C2%B006'46.8%22W/@51.5120568,-0.1127823,3a,75y,292.17h,60.39t/data=!3m10!1e1!3m8!1sANaM30owYtwiUW1VoUYNCA!2e0!5s20140601T000000!7i13312!8i6656!9m2!1b1!2i41!4m5!3m4!1s0x0:0x0!8m2!3d51.51201!4d-0.112988
# https://www.google.com/maps/place/51%C2%B028'56.5%22N+0%C2%B008'10.1%22W/@51.4822183,-0.1361193,3a,75y,346.63h,88.41t/data=!3m7!1e1!3m5!1s7TgF5IXIKl_0CXQewEOO9g!2e0!5s20160501T000000!7i16384!8i8192!4m5!3m4!1s0x0:0x0!8m2!3d51.482362!4d-0.136124

# 183001 is the station before 2013/07/03 (using 2014-12-01 00:00:00 as the dividing point)
# 183002 is the station after 2015/06/15 (using 2014-12-01 00:00:00 as the dividing point)

station_locations_clean[(station_locations_clean$ucl_id==183)&(station_locations_clean$created_dt<="2014-12-01 00:00:00"),
                        "ucl_id"]<-183001
station_locations_clean[(station_locations_clean$ucl_id==183)&(station_locations_clean$created_dt>="2014-12-01 00:00:00"),
                        "ucl_id"]<-183002

# The trip_df should be modified accordingly
station_183_start_trips_id_1<-trips_df %>% filter(start_station_id==183) %>% 
  filter(start_time<as.POSIXct("2014-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 183001 trips and derive their trip id in trips_df
trips_df$start_station_id[station_183_start_trips_id_1$id]=183001 # change their start_station_id from 183 to 183001

station_183_start_trips_id_2<-trips_df %>% filter(start_station_id==183) %>%
  filter(start_time>as.POSIXct("2014-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 183002 trips and derive their trip id in trips_df
trips_df$start_station_id[station_183_start_trips_id_2$id]=183002 # change their start_station_id from 183 to 183002

station_183_end_trips_id_1<-trips_df %>% filter(end_station_id==183) %>% 
  filter(stop_time<as.POSIXct("2014-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 183001 trips and derive their trip id in trips_df
trips_df$end_station_id[station_183_end_trips_id_1$id]=183001 # change their end_station_id from 183 to 183001

station_183_end_trips_id_2<-trips_df %>% filter(end_station_id==183) %>%
  filter(stop_time>as.POSIXct("2014-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 183002 trips and derive their trip id in trips_df
trips_df$end_station_id[station_183_end_trips_id_2$id]=183002 # change their end_station_id from 183 to 183002

rm(station_183_start_trips)
#---Completed---end of ucl_id 183




# ucl id 259------------------------------------------------------------------------------
station_259_start_trips<-trips_df %>% filter(start_station_id==259)

plot_monthly_trips <- station_259_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2011-01")&
           (year_month <="2020-01")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2011/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )
plot_monthly_trips


# The bike trip number has a gap between 2015/06/30 to 2018/04/11---------
# Further investigation is needed
# update: the change is supported by google street view:
# https://www.google.com/maps/@51.5049121,-0.1231759,3a,75y,334.31h,73.03t/data=!3m7!1e1!3m5!1sEHNqUYNyeyauw_VeDmKwRw!2e0!5s20140701T000000!7i13312!8i6656
# https://www.google.com/maps/@51.4907983,-0.1531317,3a,75y,290.47h,80.15t/data=!3m11!1e1!3m9!1s_-pa3EiW1LL7vsZPBVeHQA!2e0!5s20181001T000000!6s%2F%2Fgeo3.ggpht.com%2Fcbk%3Fpanoid%3D_-pa3EiW1LL7vsZPBVeHQA%26output%3Dthumbnail%26cb_client%3Dmaps_sv.tactile.gps%26thumb%3D2%26w%3D203%26h%3D100%26yaw%3D339.46033%26pitch%3D0%26thumbfov%3D100!7i13312!8i6656!9m2!1b1!2i38

# 259001 is the station before 2015/06/30 (using 2015-12-01 00:00:00 as the dividing point)
# 259002 is the station after 2018/04/11 (using 2015-12-01 00:00:00 as the dividing point)



station_locations_clean[(station_locations_clean$ucl_id==259)&(station_locations_clean$created_dt<="2015-12-01 00:00:00"),
                        "ucl_id"]<-259001
station_locations_clean[(station_locations_clean$ucl_id==259)&(station_locations_clean$created_dt>="2015-12-01 00:00:00"),
                        "ucl_id"]<-259002


# The trip_df should be modified accordingly
station_259_start_trips_id_1<-trips_df %>% filter(start_station_id==259) %>% 
  filter(start_time<as.POSIXct("2015-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 259001 trips and derive their trip id in trips_df
trips_df$start_station_id[station_259_start_trips_id_1$id]=259001 # change their start_station_id from 259 to 259001

station_259_start_trips_id_2<-trips_df %>% filter(start_station_id==259) %>%
  filter(start_time>as.POSIXct("2015-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 259002 trips and derive their trip id in trips_df
trips_df$start_station_id[station_259_start_trips_id_2$id]=259002 # change their start_station_id from 259 to 259002

station_259_end_trips_id_1<-trips_df %>% filter(end_station_id==259) %>% 
  filter(stop_time<as.POSIXct("2015-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 259001 trips and derive their trip id in trips_df
trips_df$end_station_id[station_259_end_trips_id_1$id]=259001 # change their end_station_id from 259 to 259001

station_259_end_trips_id_2<-trips_df %>% filter(end_station_id==259) %>%
  filter(stop_time>as.POSIXct("2015-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 259002 trips and derive their trip id in trips_df
trips_df$end_station_id[station_259_end_trips_id_2$id]=259002 # change their end_station_id from 259 to 259002
#----Completed----end of ucl_id 259



# ucl id 302------------------------------------------------------------------------------
station_302_start_trips<-trips_df %>% filter(start_station_id==302)

plot_monthly_trips <- station_302_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2011-01")&
           (year_month <="2020-01")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2011/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )
plot_monthly_trips

# The bike trip number has a gap between 2012/04/10 to 2015/04/09---------
# station changed (two station used the same ucl_id, former one is cancelled)
# google street view support this finding
# The following link shows that a docking station appeared in the 2015 picture.
# https://www.google.com/maps/place/51%C2%B028'00.9%22N+0%C2%B012'59.7%22W/@51.4670288,-0.2165905,3a,75y,118.43h,69.44t/data=!3m7!1e1!3m5!1sqqPbX387ghvYQDVDVr83yw!2e0!5s20140801T000000!7i13312!8i6656!4m5!3m4!1s0x0:0x0!8m2!3d51.466907!4d-0.216573
# The bike trip number has a gap between 2012/04/10 to 2015/04/09---------
# 302001 is the station before 2012/04/10 (using 2014-12-01 00:00:00 as the dividing point)
# 302002 is the station after 2015/04/09 (using 2014-12-01 00:00:00 as the dividing point)



station_locations_clean[(station_locations_clean$ucl_id==302)&(station_locations_clean$created_dt<="2014-12-01 00:00:00"),
                        "ucl_id"]<-302001
station_locations_clean[(station_locations_clean$ucl_id==302)&(station_locations_clean$created_dt>="2014-12-01 00:00:00"),
                        "ucl_id"]<-302002

# The trip_df should be modified accordingly
station_302_start_trips_id_1<-trips_df %>% filter(start_station_id==302) %>% 
  filter(start_time<as.POSIXct("2014-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 302001 trips and derive their trip id in trips_df
trips_df$start_station_id[station_302_start_trips_id_1$id]=302001 # change their start_station_id from 302 to 302001

station_302_start_trips_id_2<-trips_df %>% filter(start_station_id==302) %>%
  filter(start_time>as.POSIXct("2014-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 302002 trips and derive their trip id in trips_df
trips_df$start_station_id[station_302_start_trips_id_2$id]=302002 # change their start_station_id from 302 to 302002

station_302_end_trips_id_1<-trips_df %>% filter(end_station_id==302) %>% 
  filter(stop_time<as.POSIXct("2014-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 302001 trips and derive their trip id in trips_df
trips_df$end_station_id[station_302_end_trips_id_1$id]=302001 # change their end_station_id from 302 to 302001

station_302_end_trips_id_2<-trips_df %>% filter(end_station_id==302) %>%
  filter(stop_time>as.POSIXct("2014-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 302002 trips and derive their trip id in trips_df
trips_df$end_station_id[station_302_end_trips_id_2$id]=302 # change their end_station_id from 302 to 302002

rm(station_302_start_trips)
#---Completed------end of ucl_id 302




# ucl id 316------------------------------------------------------------------------------
station_316_start_trips<-trips_df %>% filter(start_station_id==316)

plot_monthly_trips <- station_316_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2011-01")&
           (year_month <="2020-01")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2011/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )
plot_monthly_trips


# Further Investigation suggested that the wrong record(ucl_id 316) duplicated with ucl_id 404, it needs to be removed
# Solution:
station_locations_clean<-station_locations_clean %>% filter(!((ucl_id==316)&(operator_name=="Palace Gate, Kensington Gardens")))

#---Completed----end of ucl_id 316



# ucl id 322------------------------------------------------------------------------------
station_322_start_trips<-trips_df %>% filter(start_station_id==322)

plot_monthly_trips <- station_322_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2011-01")&
           (year_month <="2020-01")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2011/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )
plot_monthly_trips


# google stree view:
# https://www.google.com/maps/place/51%C2%B031'34.7%22N+0%C2%B004'26.2%22W/@51.5263651,-0.0738097,3a,75y,315.34h,68.98t/data=!3m8!1e1!3m6!1sh6ejlyjEhPAnQn4YfGk1_Q!2e0!5s20120501T000000!6s%2F%2Fgeo0.ggpht.com%2Fcbk%3Fpanoid%3Dh6ejlyjEhPAnQn4YfGk1_Q%26output%3Dthumbnail%26cb_client%3Dsearch.gws-prod%2Fmaps%2Frevgeo_and_fetch.gps%26thumb%3D2%26w%3D86%26h%3D86%26yaw%3D335.73642%26pitch%3D0%26thumbfov%3D100!7i13312!8i6656!4m5!3m4!1s0x0:0x0!8m2!3d51.526293!4d-0.073955
# https://www.google.com/maps/place/51%C2%B030'44.0%22N+0%C2%B009'38.8%22W/@51.5123426,-0.1606554,3a,75y,156.85h,79.53t/data=!3m7!1e1!3m5!1s0KINr-YVTpsmhuvIYjIDmw!2e0!5s20151001T000000!7i13312!8i6656!4m5!3m4!1s0x0:0x0!8m2!3d51.51222!4d-0.160785
# Both locations all have docking stations
# Further Investigation suggested that the wrong record(ucl_id 322) duplicated  ucl_id 406/407
# Solution:
station_locations_clean<-station_locations_clean %>% filter(!((ucl_id==322)&(operator_name=="Speakers' Corner 1, Hyde Park")))

rm(station_322_start_trips)
#---Completed----end of ucl_id 322


# ucl id 323------------------------------------------------------------------------------
station_323_start_trips<-trips_df %>% filter(start_station_id==323)

plot_monthly_trips <- station_323_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2011-01")&
           (year_month <="2020-01")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2011/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )
plot_monthly_trips


# google stree view:
# https://www.google.com/maps/place/51%C2%B031'23.5%22N+0%C2%B004'59.0%22W/@51.5230183,-0.0831253,3a,75y,67.42h,65.66t/data=!3m7!1e1!3m5!1sYQLoBKoY6Syao22Om3LzPQ!2e0!6s%2F%2Fgeo3.ggpht.com%2Fcbk%3Fpanoid%3DYQLoBKoY6Syao22Om3LzPQ%26output%3Dthumbnail%26cb_client%3Dsearch.gws-prod%2Fmaps%2Frevgeo_and_fetch.gps%26thumb%3D2%26w%3D86%26h%3D86%26yaw%3D111.721344%26pitch%3D0%26thumbfov%3D100!7i16384!8i8192!4m5!3m4!1s0x0:0x0!8m2!3d51.523196!4d-0.083067
# https://www.google.com/maps/place/51%C2%B030'44.3%22N+0%C2%B009'36.0%22W/@51.5122787,-0.1603302,3a,75y,257.27h,70.49t/data=!3m7!1e1!3m5!1sbcUO7nVOIJmCPrtuu0Dpdg!2e0!6s%2F%2Fgeo0.ggpht.com%2Fmaps%2Fphotothumb%2Ffd%2Fv1%3Fbpb%3DCicKJXNlYXJjaC5nd3MtcHJvZC9tYXBzL3Jldmdlb19hbmRfZmV0Y2gSIAoSCSNiZl80BXZIES4-BXjQ75eHKgoNAAAAABUAAAAAGgQIVhBW%26gl%3DGB!7i13312!8i6656!4m5!3m4!1s0x0:0x0!8m2!3d51.512303!4d-0.159988
# Both place have docking stations
# Further Investigation suggested that the wrong record(ucl_id 323) duplicated ucl_id 406/407
# Solution:
station_locations_clean<-station_locations_clean %>% filter(!((ucl_id==323)&(operator_name=="Speakers' Corner 2, Hyde Park")))

rm(station_323_start_trips)
#---Completed----end of ucl_id 323

# ucl id 360------------------------------------------------------------------------------
station_360_start_trips<-trips_df %>% filter(start_station_id==360)

plot_monthly_trips <- station_360_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2011-01")&
           (year_month <="2020-01")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2011/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )
plot_monthly_trips


# google stree view:
# https://www.google.com/maps/place/51%C2%B029'48.3%22N+0%C2%B008'19.4%22W/@51.4967287,-0.1384167,3a,75y,281.61h,75.37t/data=!3m6!1e1!3m4!1svRdpdbmJscCMR73EeQGw0g!2e0!7i16384!8i8192!4m5!3m4!1s0x0:0x0!8m2!3d51.496753!4d-0.138734
# https://www.google.com/maps/place/51%C2%B030'13.7%22N+0%C2%B006'46.2%22W/@51.5037866,-0.1130201,3a,75y,15.36h,82.49t/data=!3m8!1e1!3m6!1scxBB5UqousgrtzBU_ZOPug!2e0!5s20120601T000000!6s%2F%2Fgeo0.ggpht.com%2Fmaps%2Fphotothumb%2Ffd%2Fv1%3Fbpb%3DCicKJXNlYXJjaC5nd3MtcHJvZC9tYXBzL3Jldmdlb19hbmRfZmV0Y2gSIAoSCTvLssK5BHZIEfDjS-CZkcg-KgoNAAAAABUAAAAAGgQIVhBW%26gl%3DGB!7i13312!8i6656!4m5!3m4!1s0x0:0x0!8m2!3d51.503792!4d-0.112824
# Both place have docking stations
# Further Investigation suggested that the wrong record(ucl_id 360) duplicated ucl_id 154
# Solution:
station_locations_clean<-station_locations_clean %>% filter(!((ucl_id==360)&(operator_name=="Waterloo Station 3, Waterloo")))

rm(station_360_start_trips)
#---Completed----end of ucl_id 360



# ucl id 502------------------------------------------------------------------------------
station_502_start_trips<-trips_df %>% filter(start_station_id==502)

plot_monthly_trips <- station_502_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2011-01")&
           (year_month <="2019-12")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2011/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )
plot_monthly_trips


# The bike trip number (identified by ucl_id) has a gap between 2015/08/20 to 2019/08/01---------
# The former one has been cancelled, and a new station using the same ucl_id was put into use from 2019, but moved to another place
# The new station can be found on google map (available by 2020-02-20)
# https://www.google.com/maps/place/Santander+Cycles/@51.5339222,-0.0502285,17z/data=!4m8!1m2!2m1!1scycle!3m4!1s0x0:0x32e1149bfbdcb960!8m2!3d51.5334098!4d-0.0495907
# 502001 is the station before 2015/08/20 (using 2015-12-01  as the dividing point)
# 502002 is the station after 2019/08/01 (using 2015-12-01  as the dividing point)
station_locations_clean[(station_locations_clean$ucl_id==502)&(station_locations_clean$created_dt<="2015-12-01 00:00:00"),
                        "ucl_id"]<-502001
station_locations_clean[(station_locations_clean$ucl_id==502)&(station_locations_clean$created_dt>="2015-12-01 00:00:07"),
                        "ucl_id"]<-502002

# The trip_df should be modified accordingly
station_502_start_trips_id_1<-trips_df %>% filter(start_station_id==502) %>% 
  filter(start_time<as.POSIXct("2015-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 502001 trips and derive their trip id in trips_df
trips_df$start_station_id[station_502_start_trips_id_1$id]=502001 # change their start_station_id from 502 to 502001

station_502_start_trips_id_2<-trips_df %>% filter(start_station_id==502) %>%
  filter(start_time>as.POSIXct("2015-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 502002 trips and derive their trip id in trips_df
trips_df$start_station_id[station_502_start_trips_id_2$id]=502002 # change their start_station_id from 502 to 502002

station_502_end_trips_id_1<-trips_df %>% filter(end_station_id==502) %>% 
  filter(stop_time<as.POSIXct("2015-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 502001 trips and derive their trip id in trips_df
trips_df$end_station_id[station_502_end_trips_id_1$id]=502001 # change their end_station_id from 502 to 502001

station_502_end_trips_id_2<-trips_df %>% filter(end_station_id==502) %>%
  filter(stop_time>as.POSIXct("2015-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 502002 trips and derive their trip id in trips_df
trips_df$end_station_id[station_502_end_trips_id_2$id]=502002 # change their end_station_id from 502 to 502002

rm(station_502_start_trips)
#---Completed----end of ucl_id 502

# ucl id 725------------------------------------------------------------------------------
station_725_start_trips<-trips_df %>% filter(start_station_id==725)

plot_monthly_trips <- station_725_start_trips %>%
  mutate(
    start_time_dt=as.POSIXct(start_time, format="%Y-%m-%d %H:%M:%S"),
    year=year(start_time_dt),
    month=month(start_time_dt), 
    year_month=format(start_time_dt, "%Y-%m")) %>%
  filter(!is.na(year_month)) %>% 
  group_by(year_month) %>%
  summarise(total=n(), month=first(month)) %>%
  filter((year_month >="2011-01")&
           (year_month <="2019-12")) %>%
  ggplot(aes(x=year_month, y=total, group=1)) +
  geom_line(colour="#3182bd", size=1.1) +
  #scale_y_continuous(limits=c(0,11000))+
  labs(title="Monthly trip counts 2011/01-2019/05, London Cycle Hire Scheme", x="", y="trip counts") +
  theme(
    axis.text.x=element_text(angle=90)
  )
plot_monthly_trips


# The bike trip number (identified by ucl_id) has a gap between 2018-04-29 to 2019-06-09---------
# The formor one was available until 2018, and then have heen removed in 2019, this can be found in google street view
# https://www.google.com/maps/@51.4772978,-0.1387294,3a,75y,81.17h,78.42t/data=!3m7!1e1!3m5!1sT30z2K5H1oWVnRaRrQ3f7A!2e0!5s20180301T000000!7i16384!8i8192

# The new station (using the same ucl_id - 725) can be found on google map (available by 2020-02-20)
# https://www.google.com/maps/place/Santander+Cycles/@51.5339222,-0.0502285,17z/data=!4m8!1m2!2m1!1scycle!3m4!1s0x0:0x32e1149bfbdcb960!8m2!3d51.5334098!4d-0.0495907


# 725001 is the station before 2018-04-29 (using 2018-12-01 00:00:00 as the dividing point)
# 723002 is the station after 2019-06-09 (using 2018-12-01 00:00:00 as the dividing point)
station_locations_clean[(station_locations_clean$ucl_id==725)&(station_locations_clean$created_dt<="2018-12-01 00:00:00"),
                        "ucl_id"]<-725001
station_locations_clean[(station_locations_clean$ucl_id==725)&(station_locations_clean$created_dt>="2018-12-01 00:00:00"),
                        "ucl_id"]<-725002

# The trip_df should be modified accordingly
station_725_start_trips_id_1<-trips_df %>% filter(start_station_id==725) %>% 
  filter(start_time<as.POSIXct("2018-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 725001 trips and derive their trip id in trips_df
trips_df$start_station_id[station_725_start_trips_id_1$id]=725001 # change their start_station_id from 725 to 725001

station_725_start_trips_id_2<-trips_df %>% filter(start_station_id==725) %>%
  filter(start_time>as.POSIXct("2018-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 725002 trips and derive their trip id in trips_df
trips_df$start_station_id[station_725_start_trips_id_2$id]=725002 # change their start_station_id from 725 to 725002

station_725_end_trips_id_1<-trips_df %>% filter(end_station_id==725) %>% 
  filter(stop_time<as.POSIXct("2018-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 725001 trips and derive their trip id in trips_df
trips_df$end_station_id[station_725_end_trips_id_1$id]=725001 # change their end_station_id from 725 to 725001

station_725_end_trips_id_2<-trips_df %>% filter(end_station_id==725) %>%
  filter(stop_time>as.POSIXct("2018-12-01 00:00:00")) %>% 
  dplyr::select(id) %>% as.vector() # identify the 725002 trips and derive their trip id in trips_df
trips_df$end_station_id[station_725_end_trips_id_2$id]=725002 # change their end_station_id from 725 to 725002

rm(station_725_start_trips)
#---Completed----end of ucl_id 725





#----------------------------------------------------------------------------
# The final part is to deal with a problem in the hyder park
# Hyde park had a large docking station (probably it was combined by two adjacent stations), it used two ucl_id(406 and 407)in the record
# The 406 and 407 station have the same coordinates, so they together represent that large docking station.
# We have deleted the station ucl_id 407 in previous cleaning process, and only keeped the 406 one.
# Now it is necessay to change 407-related bike trips to 406
station_407_start_trips_id<-trips_df %>% filter(start_station_id==407) %>%
  dplyr::select(id) %>% as.vector()

trips_df$start_station_id[station_407_start_trips_id$id]="406"

station_407_end_trips_id<-trips_df %>% filter(end_station_id==407) %>% 
  dplyr::select(id) %>% as.vector()

trips_df$end_station_id[station_407_end_trips_id$id]="406"


#-------------------------------------------------------------------------------------------------
# Check wether the mult-location stations have all been re-coded.
# This shoule gives a tibble contains 0 observations, and it suggests that they have all been re-coded.
station_locations_clean %>% group_by(ucl_id) %>%
  summarise(num=n()) %>% filter(num>=2)

# The data cleaning process is completed
# Now save/output the cleaned data.

save(station_locations_clean,file = "data/station_clean.Rdata")
#save(trips_df,file = "data/trip_clean.Rdata")
write.fst(trips_df, path = "data/trip_clean.fst")

