# Aim get initial dataset - 

# file.edit("old-code/preprocess.R") # based on that original file


# get and save raw data from bikedata -------------------------------------


lchs_download = function(
  data_dir = "data/london",
  sqf = file.path(data_dir, "london_bike_hire_2020-02-21.sqlite")
){
  message("These files found: ")
  print(paste(list.files(data_dir), sep = "\n"))
  bikedata::dl_bikedata(city = "london", data_dir = data_dir)
  # bikedata::store_bikedata(bikedb = sqf)
}

lchs_rename = function(
  data_dir = "data/london",
  sqf = file.path(data_dir, "london_bike_hire_20-02-21.sqlite"),
  files_to_rename = "2020"
) {
  message("Changing file namesm removing ., _ and   to make file nemes clean")
  rename_pkg_version = system("rename --version", intern = TRUE)[1]
  if(nchar(rename_pkg_version) < 5) 
    message("Install rename on Mac with brew install rename or Linux with apt install rename or similar")
  message("Using rename version ", rename_pkg_version)
  msg = paste0("cd ./", data_dir, '; mkdir ', files_to_rename, "; mv -v *", files_to_rename, "* ", files_to_rename)
  message("Running: ", msg)
  system(msg)
  msg = paste0("cd ./", data_dir, '; rename -v "s/[- ]//g" *.csv')
  message("Running: ", msg)
  system(msg)
  
  system("pwd # no need to cd -")
  message("Updating the database")
  ntrips = bikedata::store_bikedata(bikedb = sqf, data_dir = data_dir)
  message(ntrips, " trips in the updated db")
}

lchs_read_raw = function(
  data_dir = "data/london",
  sqf = file.path(data_dir, "london_bike_hire_2020-02-21.sqlite")
) {
  bikes_data = DBI::dbConnect(RSQLite::SQLite(), sqf)
  dbi_tables = DBI::dbListTables(bikes_data)
  message("These tables found: ", dbi_tables)
  trips = tbl(bikes_data, "trips")
  collect(trips)
}

lchs_filter_select = function(data_raw) {
  data_raw %>% 
    select(-city, -user_type, -birth_year, -gender) %>% 
    distinct(start_time, stop_time, start_station_id, end_station_id) %>% 
    # remove crazy dates:
    filter(!str_detect(string = start_time, pattern = "1900|1901")) %>% 
    filter(!str_detect(string = stop_time, pattern = "1900|1901")) %>%
    filter(!(is.na(start_time) | is.na(stop_time))) 
}

lchs_clean = function(data_filtered) {
  data_filtered$start_time = lubridate::ymd_hms(data_filtered$start_time)
  data_filtered$stop_time = lubridate::ymd_hms(data_filtered$stop_time) 
  data_filtered$year_month = lubridate::floor_date(data_filtered$start_time, unit = "month")
  data_filtered$start_station_id = str_remove(data_filtered$start_station_id, "lo")
  data_filtered$end_station_id = str_remove(data_filtered$end_station_id, "lo")
  data_filtered %>% filter(!(is.na(start_time) | is.na(stop_time)))
}

lchs_check_dates = function(data_filtered_clean) {
  # time analysis
  trips_per_year = data_filtered_clean %>%
    group_by(year_month) %>%
    summarise(
      total = n()
    )
  g = ggplot(trips_per_year) +
    geom_line(aes(year_month, total), col = "grey")
  g
}

lchs_get_sations = function(){
  if(!file.exists("bikelocations_london.csv")) {
    message("Trying to downloading the stations file from the releases. See")
    message("https://github.com/Robinlovelace/cycle-hire-inclusive/releases/")
    piggyback::pb_download("bikelocations_london.csv")
  }
  readr::read_csv("bikelocations_london.csv")
}

# note: this function will recode the stations data for each year and return a data.frame with recoded ids
lchs_recode_data = function(trips_df, stations) {

  trips_df$id = c(1:nrow(trips_df)) # adding a trip id column, it will be used for modifying start and end stations later
  
  # Identify how many stations (same ID) have multiple locations (different lat/lon)
  station_locations_check <- stations %>% distinct(ucl_id,lat,lon) %>%
    group_by(ucl_id) %>% summarise(num_loc=n())
  print(paste0("There are ", station_locations_check %>% filter(num_loc>=2) %>% nrow," stations (stationID) have multiple locations (coordinates):"))
  
  
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
  
}

# test filtered dates, 0.2%, 160k records, empty!
# test1 = lubridate::ymd_hms(data_filtered$start_time)
# test2 = as.POSIXct(data_filtered$start_time, format="%Y-%m-%d %H:%M:%S")
# summary(test1)
# summary(test2)
# 
# failing_sample = sample(data_filtered$start_time[is.na(test1)], size = 3)
# lubridate::ymd_hms(failing_sample)
# as.POSIXct(failing_sample, format="%Y-%m-%d %H:%M:%S")
# 
# plot(test2)

# ntrips : 77694197 (2020-02-20)
# ntrips : 96592362 (2020-02-21)
# file.size("data/london/london_bike_hire_2020-02-21.sqlite") # 7.3 GB  (2020-02-21)
# file.size(sqf) 5.9 GB # old version

# bikes_data = DBI::dbConnect(RSQLite::SQLite(), sqf)
# DBI::dbListTables(bikes_data)
# trips = tbl(bikes_data, "trips")
# system.time({trips_df = trips %>% collect()})
# # user  system elapsed 
# # 177.343   4.433 181.755 
# summary(trips_df$start_time) # char string in db...
# 
# system.time({
#   vroom::vroom_write(trips_df, "london_bike_hire_from_bikedata-2020-02.csv.gz")
# })
# user  system elapsed 
# 286.760 194.904 438.305 
# file.size("london_bike_hire_from_bikedata-2020-02.csv.gz") / 1e9
# 1.4 GB

# Clean raw data... -------------------------------------------------------


# 
# trips_df$year = lubridate::year(trips_df$start_time)
# 
# # year-month 
# lubridate::floor_date(trips_df$start_time[sample(nrow(trips_df), size = 10)], unit = "month")
# trips_df$year_month = lubridate::floor_date(trips_df$start_time, unit = "month")
# 
# # pryr::object_size(trips_df) # 7.87 GB
# names(trips_df) # do we really need "city"? no
# head(trips_df$trip_duration, 9)
# head(trips_df$user_type, 9) # not needed
# head(trips_df$birth_year, 9) 
# head(trips_df$gender, 9) 
# trips_df = trips_df %>% select(-city, -user_type, -birth_year, -gender)
# pryr::object_size(trips_df) # 6.16 GB smaller
# trips_df


# Notes and test code -----------------------------------------------------



# # Less than 1 minute to load 68 million rows:
# system.time({
#   trips_df = vroom::vroom("london_bike_hire_from_bikedata-2020-02.csv.gz")
# })
# # user  system elapsed 
# # 53.546  10.961  37.546 
# trips_df
  
# 


# very slow to write...
# system.time({
#   vroom::vroom_write(trips_df, "london_bike_hire_from_bikedata-2020-02-clean-1.csv.gz")
# })
# user  system elapsed 
# 503.784   3.107 435.412 


# Cleaning stage II find missing/duplicate data ----------------------

# trips_df = vroom::vroom("london_bike_hire_from_bikedata-2020-02-clean-1.csv.gz")
# Explore trips/month to find missing/duplicate data ----------------------
# trips_df_1pct = trips_df %>% sample_frac(size = 0.01)
# stations = readRDS("stations-clean.Rds")
# stations <- read_csv("./data/bikelocations_london.csv")
# trips_with_origin_station_ids = trips_df$start_station_id %in% stations$check_id # 
# sum(trips_with_origin_station_ids) / nrow(trips_df) # no matching ids!
# str_remove(trips_df$start_station_id[1:9], "lo")
# trips_df$start_station_id = str_remove(trips_df$start_station_id, "lo")
# trips_df$end_station_id = str_remove(trips_df$end_station_id, "lo")

# EDIT : let's write current dataset out before editing on cleaning.
# ntrips : 77694197 -- with 2015 data properly uploaded
# fst::write_fst(trips_df, "./data/trips-2020-02.fst")
# EDIT : Struggling to upload.
# piggyback::pb_upload(file="./data/trips-2020-02.fst", name="trips-2020-02.fst", repo="Robinlovelace/cycle-hire-inclusive")

# trips_with_origin_station_ids = trips_df$start_station_id %in% stations$ucl_id
# trips_with_destination_station_ids = trips_df$end_station_id %in% stations$operator_intid
# sum(trips_with_origin_station_ids) / nrow(trips_df) # 99.2% have origin id
# sum(trips_with_destination_station_ids) / nrow(trips_df) # 98.1% have destination id
# trips_with_ids = trips_with_origin_station_ids & trips_with_destination_station_ids
# # trips_df$with_ids = trips_with_ids
# sum(trips_with_ids) / nrow(trips_df) # 97% have id
# table(lubridate::year(trips_df$start_time))
# yrs_without_ids = lubridate::year(trips_df$start_time[!trips_with_ids])
# table(yrs_without_ids)
# # original:
# # 1900   1901   2012   2013   2014   2015   2016   2017   2018   2019 
# #  753    420 125218 150010    130    196 434829 731076 905495 447993 
# # with latest bikedata data:
# # 1900   1901   2012   2013   2014   2015   2016   2017   2018   2019 
# # 753    420 342285 285146 445611 288976 228780 171672 206601 268226


# trips_df = trips_df %>% filter(trips_with_ids)
# head(trips_df$start_station_id)
# trips_by_origin_station = trips_df %>% 
#   group_by(id = start_station_id) %>% 
#   summarise(total_n_trips_start = n())
# 
# sum(is.na(trips_df$year)) / nrow(trips_df) # 0.2% with no year
# trips_df = trips_df %>% filter(!is.na(year))
# has_sane_year = trips_df$year > 2009
# sum(has_sane_year) / nrow(trips_df)
# summary(trips_df$year)
# trips_df
# trips_df = trips_df %>% select(-bike_id)
# pryr::object_size(trips_df)
# # 5.32 GB

# system.time(fst::write_fst(trips_df, "trips_df.fst"))
# # user  system elapsed  # 100 times faster!
# # 6.993   1.046   4.464
# system.time(fst::write_fst(trips_df, "trips_df.fst", 80))
# # user  system elapsed  
# # 37.238   1.218  15.196 
# file.size("trips_df.fst") / 1e9 # 1.3 GB
# piggyback::pb_upload("trips_df.fst", repo = "itsleeds/tds")
# 
# 
# # identify duplicate/missing months ---------------------------------------
# 
# trips_df = fst::read.fst("trips_df.fst")
# 
# # time analysis
# trips_per_year = trips_df %>%
#   group_by(year_month) %>%
#   summarise(
#     total = n()
#   )
# g = ggplot(trips_per_year) +
#   geom_line(aes(year_month, total), col = "grey")
# g
# 
# trips_df$date = as.Date(trips_df$start_time)
# trips_per_day = trips_df %>% 
#   group_by(date) %>% 
#   summarise(
#     total_csvs = n()
#   ) 
# 
# trips_per_day_xls = readRDS("daily_hires.Rds")
# trips_per_day_xls$date = trips_per_day_xls$Day
# trips_daily = left_join(trips_per_day_xls, trips_per_day)
# 
# ggplot(trips_daily, aes(Day, `Number of hires`)) +
#   geom_point(alpha = 0.1) +
#   geom_line(aes(Day, Monthly), lwd = 1) +
#   geom_line(aes(Day, Yearly), colour = "blue", lwd = 1) +
#   # csv data
#   geom_point(aes(y = total_csvs), colour = "red", alpha = 0.1) 
# # finding: there are duplicate trips in the csv files
# 
# trips_df_duplicated = duplicated(trips_df %>% select(id))
# summary(trips_df_duplicated) # but there are no duplicated duplicate ids!
# trips_df_duplicated = distinct(trips_df %>% select(id))
# nrow(trips_df_duplicated) / nrow(trips_df) # verified in tidyverse...
# head(trips_df$start_time) # to nearest minute...
# trips_df_duplicated = distinct(trips_df %>% select(start_time, stop_time, start_station_id))
# nrow(trips_df_duplicated) / nrow(trips_df) # 82%
# trips_df_distinct = trips_df %>% 
#   distinct(start_time, stop_time, start_station_id, end_station_id)
# nrow(trips_df_distinct) / nrow(trips_df) # 82.7 %
# trips_df = trips_df_distinct
# 
# trips_per_day = trips_df %>% 
#   mutate(date = as.Date(start_time)) %>% 
#   group_by(date) %>% 
#   summarise(
#     total_csvs = n()
#   ) 
# 
# trips_daily = left_join(trips_per_day_xls, trips_per_day)
# 
# ggplot(trips_daily, aes(Day, `Number of hires`)) +
#   geom_point(alpha = 0.1) +
#   geom_line(aes(Day, Monthly), lwd = 1) +
#   geom_line(aes(Day, Yearly), colour = "blue", lwd = 1) +
#   # csv data
#   geom_point(aes(y = total_csvs), colour = "red", alpha = 0.1) +
#   xlab("Year") +
#   ylim(c(0, 50000)) +
#   xlim(as.POSIXlt(c("2010-01-01", "2019-10-01"))) +
#   ylab("Number of cycle hire events per day") +
#   # scale_x_continuous(breaks = 2010:2020)
#   # scale_x_date(breaks = lubridate::ymd(paste0(2010:2020, "-01-01")))
#   scale_x_date(date_breaks = "1 year", date_labels = "%Y")
# 
# cor(trips_daily$`Number of hires`, trips_daily$total_csvs, use = "complete.obs") ^ 2 # 97.5
# 
# fst::write_fst(trips_df, "trips_df.fst")

# with bikedata internal functions ----------------------------------------

# aws_url <- "https://s3-eu-west-1.amazonaws.com/cycling.data.tfl.gov.uk/"
# doc <- httr::content (httr::GET (aws_url), encoding  =  'UTF-8')
# nodes <- xml2::xml_children(doc)
# 
# flist_zip <- getflist (nodes, type = 'zip')
# flist_zip <- flist_zip [which (grepl ('usage', flist_zip))]
# flist_csv <- getflist (nodes, type = 'csv')
# flist_xlsx <- getflist (nodes, type = 'xlsx')

# with rvest --------------------------------------------------------------

# library(rvest)
# html_data = xml2::read_html("https://cycling.data.tfl.gov.uk/")
# lnd_urls = html_data %>% 
#   rvest::html_nodes(css = "#tbody-content a") %>% 
#   html_text()


# old cleaning code -------------------------------------------------------
# 
# # clean ids
# trips_df$id[1:9]
# sample_ids = sample(x = trips_df$id, 20000) # look OK
# sample_ids[1:9]
# summary(str_detect(string = sample_ids, "lo"))


# dtplyr test -------------------------------------------------------------

# library(dtplyr)
# trips_dt = dtplyr::lazy_dt(trips_df_1pct)
# system.time({
#   trips_agg = trips_dt %>% 
#     group_by(year_month) %>% 
#     summarise(n = n())
#   trips_agg_df = as.data.frame(trips_agg)
# })
# user  system elapsed 
# 0.167   0.000   0.060 

# system.time({
#   trips_agg = trips_df_1pct %>% 
#     group_by(year_month) %>% 
#     summarise(n = n())
# })
# user  system elapsed 
# 0.054   0.001   0.056

# for   system('cd ./data/london; rename -v "s/[- ]//g" *.csv; cd -')
# I got: 

# 01aJourneyDataExtract10Jan16-23Jan16.csv renamed as 01aJourneyDataExtract10Jan1623Jan16.csv
# 01bJourneyDataExtract24Jan16-06Feb16.csv renamed as 01bJourneyDataExtract24Jan1606Feb16.csv
# 02aJourneyDataExtract07Fe16-20Feb2016.csv renamed as 02aJourneyDataExtract07Fe1620Feb2016.csv
# 02bJourneyDataExtract21Feb16-05Mar2016.csv renamed as 02bJourneyDataExtract21Feb1605Mar2016.csv
# 03JourneyDataExtract06Mar2016-31Mar2016.csv renamed as 03JourneyDataExtract06Mar201631Mar2016.csv
# 04JourneyDataExtract01Apr2016-30Apr2016.csv renamed as 04JourneyDataExtract01Apr201630Apr2016.csv
# 05JourneyDataExtract01May2016-17May2016.csv renamed as 05JourneyDataExtract01May201617May2016.csv
# 06JourneyDataExtract18May2016-24May2016.csv renamed as 06JourneyDataExtract18May201624May2016.csv
# 07JourneyDataExtract25May2016-31May2016.csv renamed as 07JourneyDataExtract25May201631May2016.csv
# 08JourneyDataExtract01Jun2016-07Jun2016.csv renamed as 08JourneyDataExtract01Jun201607Jun2016.csv
# 09JourneyDataExtract08Jun2016-14Jun2016.csv renamed as 09JourneyDataExtract08Jun201614Jun2016.csv
# 100JourneyDataExtract07Mar2018-13Mar2018.csv renamed as 100JourneyDataExtract07Mar201813Mar2018.csv
# 101JourneyDataExtract14Mar2018-20Mar2018.csv renamed as 101JourneyDataExtract14Mar201820Mar2018.csv
# 102JourneyDataExtract21Mar2018-27Mar2018.csv renamed as 102JourneyDataExtract21Mar201827Mar2018.csv
# 103JourneyDataExtract28Mar2018-03Apr2018.csv renamed as 103JourneyDataExtract28Mar201803Apr2018.csv
# 104JourneyDataExtract04Apr2018-10Apr2018.csv renamed as 104JourneyDataExtract04Apr201810Apr2018.csv
# 105JourneyDataExtract11Apr2018-17Apr2018.csv renamed as 105JourneyDataExtract11Apr201817Apr2018.csv
# 106JourneyDataExtract18Apr2018-24Apr2018.csv renamed as 106JourneyDataExtract18Apr201824Apr2018.csv
# 107JourneyDataExtract25Apr2018-01May2018.csv renamed as 107JourneyDataExtract25Apr201801May2018.csv
# 108JourneyDataExtract02May2018-08May2018.csv renamed as 108JourneyDataExtract02May201808May2018.csv
# 109JourneyDataExtract09May2018-15May2018.csv renamed as 109JourneyDataExtract09May201815May2018.csv
# 10JourneyDataExtract15Jun2016-21Jun2016.csv renamed as 10JourneyDataExtract15Jun201621Jun2016.csv
# 10a-Journey-Data-Extract-20Sep15-03Oct15.csv renamed as 10aJourneyDataExtract20Sep1503Oct15.csv
# 10b-Journey-Data-Extract-04Oct15-17Oct15.csv renamed as 10bJourneyDataExtract04Oct1517Oct15.csv
# 110JourneyDataExtract16May2018-22May2018.csv renamed as 110JourneyDataExtract16May201822May2018.csv
# 111JourneyDataExtract23May2018-29May2018.csv renamed as 111JourneyDataExtract23May201829May2018.csv
# 112JourneyDataExtract30May2018-05June2018.csv renamed as 112JourneyDataExtract30May201805June2018.csv
# 113JourneyDataExtract06June2018-12June2018.csv renamed as 113JourneyDataExtract06June201812June2018.csv
# 114JourneyDataExtract13June2018-19June2018.csv renamed as 114JourneyDataExtract13June201819June2018.csv
# 115JourneyDataExtract20June2018-26June2018.csv renamed as 115JourneyDataExtract20June201826June2018.csv
# 116JourneyDataExtract27June2018-03July2018.csv renamed as 116JourneyDataExtract27June201803July2018.csv
# 117JourneyDataExtract04July2018-10July2018.csv renamed as 117JourneyDataExtract04July201810July2018.csv
# 118JourneyDataExtract11July2018-17July2018.csv renamed as 118JourneyDataExtract11July201817July2018.csv
# 119JourneyDataExtract18July2018-24July2018.csv renamed as 119JourneyDataExtract18July201824July2018.csv
# 11JourneyDataExtract22Jun2016-28Jun2016.csv renamed as 11JourneyDataExtract22Jun201628Jun2016.csv
# 11a-Journey-Data-Extract-18Oct15-31Oct15.csv renamed as 11aJourneyDataExtract18Oct1531Oct15.csv
# 11b-Journey-Data-Extract-01Nov15-14Nov15.csv renamed as 11bJourneyDataExtract01Nov1514Nov15.csv
# 120JourneyDataExtract25July2018-31July2018.csv renamed as 120JourneyDataExtract25July201831July2018.csv
# 121JourneyDataExtract01Aug2018-07Aug2018.csv renamed as 121JourneyDataExtract01Aug201807Aug2018.csv
# 122JourneyDataExtract08Aug2018-14Aug2018.csv renamed as 122JourneyDataExtract08Aug201814Aug2018.csv
# 123JourneyDataExtract15Aug2018-21Aug2018.csv renamed as 123JourneyDataExtract15Aug201821Aug2018.csv
# 124JourneyDataExtract22Aug2018-28Aug2018.csv renamed as 124JourneyDataExtract22Aug201828Aug2018.csv
# 125JourneyDataExtract29Aug2018-04Sep2018.csv renamed as 125JourneyDataExtract29Aug201804Sep2018.csv
# 126JourneyDataExtract05Sep2018-11Sep2018.csv renamed as 126JourneyDataExtract05Sep201811Sep2018.csv
# 127JourneyDataExtract12Sep2018-18Sep2018.csv renamed as 127JourneyDataExtract12Sep201818Sep2018.csv
# 128JourneyDataExtract19Sep2018-25Sep2018.csv renamed as 128JourneyDataExtract19Sep201825Sep2018.csv
# 129JourneyDataExtract26Sep2018-02Oct2018.csv renamed as 129JourneyDataExtract26Sep201802Oct2018.csv
# 12JourneyDataExtract29Jun2016-05Jul2016.csv renamed as 12JourneyDataExtract29Jun201605Jul2016.csv
# 12aJourneyDataExtract15Nov15-27Nov15.csv renamed as 12aJourneyDataExtract15Nov1527Nov15.csv
# 12bJourneyDataExtract28Nov15-12Dec15.csv renamed as 12bJourneyDataExtract28Nov1512Dec15.csv
# 130JourneyDataExtract03Oct2018-09Oct2018.csv renamed as 130JourneyDataExtract03Oct201809Oct2018.csv
# 131JourneyDataExtract10Oct2018-16Oct2018.csv renamed as 131JourneyDataExtract10Oct201816Oct2018.csv
# 132JourneyDataExtract17Oct2018-23Oct2018.csv renamed as 132JourneyDataExtract17Oct201823Oct2018.csv
# 133JourneyDataExtract24Oct2018-30Oct2018.csv renamed as 133JourneyDataExtract24Oct201830Oct2018.csv
# 134JourneyDataExtract31Oct2018-06Nov2018.csv renamed as 134JourneyDataExtract31Oct201806Nov2018.csv
# 135JourneyDataExtract07Nov2018-13Nov2018.csv renamed as 135JourneyDataExtract07Nov201813Nov2018.csv
# 136JourneyDataExtract14Nov2018-20Nov2018.csv renamed as 136JourneyDataExtract14Nov201820Nov2018.csv
# 137JourneyDataExtract21Nov2018-27Nov2018.csv renamed as 137JourneyDataExtract21Nov201827Nov2018.csv
# 138JourneyDataExtract28Nov2018-04Dec2018.csv renamed as 138JourneyDataExtract28Nov201804Dec2018.csv
# 139JourneyDataExtract05Dec2018-11Dec2018.csv renamed as 139JourneyDataExtract05Dec201811Dec2018.csv
# 13JourneyDataExtract06Jul2016-12Jul2016.csv renamed as 13JourneyDataExtract06Jul201612Jul2016.csv
# 13aJourneyDataExtract13Dec15-24Dec15.csv renamed as 13aJourneyDataExtract13Dec1524Dec15.csv
# 13bJourneyDataExtract25Dec15-09Jan16.csv renamed as 13bJourneyDataExtract25Dec1509Jan16.csv
# 140JourneyDataExtract12Dec2018-18Dec2018.csv renamed as 140JourneyDataExtract12Dec201818Dec2018.csv
# 141JourneyDataExtract19Dec2018-25Dec2018.csv renamed as 141JourneyDataExtract19Dec201825Dec2018.csv
# 142JourneyDataExtract26Dec2018-01Jan2019.csv renamed as 142JourneyDataExtract26Dec201801Jan2019.csv
# 143JourneyDataExtract02Jan2019-08Jan2019.csv renamed as 143JourneyDataExtract02Jan201908Jan2019.csv
# 144JourneyDataExtract09Jan2019-15Jan2019.csv renamed as 144JourneyDataExtract09Jan201915Jan2019.csv
# 145JourneyDataExtract16Jan2019-22Jan2019.csv renamed as 145JourneyDataExtract16Jan201922Jan2019.csv
# 146JourneyDataExtract23Jan2019-29Jan2019.csv renamed as 146JourneyDataExtract23Jan201929Jan2019.csv
# 147JourneyDataExtract30Jan2019-05Feb2019.csv renamed as 147JourneyDataExtract30Jan201905Feb2019.csv
# 148JourneyDataExtract06Feb2019-12Feb2019.csv renamed as 148JourneyDataExtract06Feb201912Feb2019.csv
# 149JourneyDataExtract13Feb2019-19Feb2019.csv renamed as 149JourneyDataExtract13Feb201919Feb2019.csv
# 14JourneyDataExtract13Jul2016-19Jul2016.csv renamed as 14JourneyDataExtract13Jul201619Jul2016.csv
# 150JourneyDataExtract20Feb2019-26Feb2019.csv renamed as 150JourneyDataExtract20Feb201926Feb2019.csv
# 151JourneyDataExtract27Feb2019-05Mar2019.csv renamed as 151JourneyDataExtract27Feb201905Mar2019.csv
# 152JourneyDataExtract06Mar2019-12Mar2019.csv renamed as 152JourneyDataExtract06Mar201912Mar2019.csv
# 153JourneyDataExtract13Mar2019-19Mar2019.csv renamed as 153JourneyDataExtract13Mar201919Mar2019.csv
# 154JourneyDataExtract20Mar2019-26Mar2019.csv renamed as 154JourneyDataExtract20Mar201926Mar2019.csv
# 155JourneyDataExtract27Mar2019-02Apr2019.csv renamed as 155JourneyDataExtract27Mar201902Apr2019.csv
# 156JourneyDataExtract03Apr2019-09Apr2019.csv renamed as 156JourneyDataExtract03Apr201909Apr2019.csv
# 157JourneyDataExtract10Apr2019-16Apr2019.csv renamed as 157JourneyDataExtract10Apr201916Apr2019.csv
# 158JourneyDataExtract17Apr2019-23Apr2019.csv renamed as 158JourneyDataExtract17Apr201923Apr2019.csv
# 159JourneyDataExtract24Apr2019-30Apr2019.csv renamed as 159JourneyDataExtract24Apr201930Apr2019.csv
# 15JourneyDataExtract20Jul2016-26Jul2016.csv renamed as 15JourneyDataExtract20Jul201626Jul2016.csv
# 160JourneyDataExtract01May2019-07May2019.csv renamed as 160JourneyDataExtract01May201907May2019.csv
# 161JourneyDataExtract08May2019-14May2019.csv renamed as 161JourneyDataExtract08May201914May2019.csv
# 162JourneyDataExtract15May2019-21May2019.csv renamed as 162JourneyDataExtract15May201921May2019.csv
# 163JourneyDataExtract22May2019-28May2019.csv renamed as 163JourneyDataExtract22May201928May2019.csv
# 164JourneyDataExtract29May2019-04Jun2019.csv renamed as 164JourneyDataExtract29May201904Jun2019.csv
# 165JourneyDataExtract05Jun2019-11Jun2019.csv renamed as 165JourneyDataExtract05Jun201911Jun2019.csv
# 166JourneyDataExtract12Jun2019-18Jun2019.csv renamed as 166JourneyDataExtract12Jun201918Jun2019.csv
# 167JourneyDataExtract19Jun2019-25Jun2019.csv renamed as 167JourneyDataExtract19Jun201925Jun2019.csv
# 168JourneyDataExtract26Jun2019-02Jul2019.csv renamed as 168JourneyDataExtract26Jun201902Jul2019.csv
# 169JourneyDataExtract03Jul2019-09Jul2019.csv renamed as 169JourneyDataExtract03Jul201909Jul2019.csv
# 16JourneyDataExtract27Jul2016-02Aug2016.csv renamed as 16JourneyDataExtract27Jul201602Aug2016.csv
# 170JourneyDataExtract10Jul2019-16Jul2019.csv renamed as 170JourneyDataExtract10Jul201916Jul2019.csv
# 171JourneyDataExtract17Jul2019-23Jul2019.csv renamed as 171JourneyDataExtract17Jul201923Jul2019.csv
# 172JourneyDataExtract24Jul2019-30Jul2019.csv renamed as 172JourneyDataExtract24Jul201930Jul2019.csv
# 173JourneyDataExtract31Jul2019-06Aug2019.csv renamed as 173JourneyDataExtract31Jul201906Aug2019.csv
# 174JourneyDataExtract07Aug2019-13Aug2019.csv renamed as 174JourneyDataExtract07Aug201913Aug2019.csv
# 175JourneyDataExtract14Aug2019-20Aug2019.csv renamed as 175JourneyDataExtract14Aug201920Aug2019.csv
# 176JourneyDataExtract21Aug2019-27Aug2019.csv renamed as 176JourneyDataExtract21Aug201927Aug2019.csv
# 177JourneyDataExtract28Aug2019-03Sep2019.csv renamed as 177JourneyDataExtract28Aug201903Sep2019.csv
# 178JourneyDataExtract04Sep2019-10Sep2019.csv renamed as 178JourneyDataExtract04Sep201910Sep2019.csv
# 179JourneyDataExtract11Sep2019-17Sep2019.csv renamed as 179JourneyDataExtract11Sep201917Sep2019.csv
# 17JourneyDataExtract03Aug2016-09Aug2016.csv renamed as 17JourneyDataExtract03Aug201609Aug2016.csv
# 180JourneyDataExtract18Sep2019-24Sep2019.csv renamed as 180JourneyDataExtract18Sep201924Sep2019.csv
# 181JourneyDataExtract25Sep2019-01Oct2019.csv renamed as 181JourneyDataExtract25Sep201901Oct2019.csv
# 182JourneyDataExtract02Oct2019-08Oct2019.csv renamed as 182JourneyDataExtract02Oct201908Oct2019.csv
# 183JourneyDataExtract09Oct2019-15Oct2019.csv renamed as 183JourneyDataExtract09Oct201915Oct2019.csv
# 184JourneyDataExtract16Oct2019-22Oct2019.csv renamed as 184JourneyDataExtract16Oct201922Oct2019.csv
# 185JourneyDataExtract23Oct2019-29Oct2019.csv renamed as 185JourneyDataExtract23Oct201929Oct2019.csv
# 186JourneyDataExtract30Oct2019-05Nov2019.csv renamed as 186JourneyDataExtract30Oct201905Nov2019.csv
# 187JourneyDataExtract06Nov2019-12Nov2019.csv renamed as 187JourneyDataExtract06Nov201912Nov2019.csv
# 188JourneyDataExtract13Nov2019-19Nov2019.csv renamed as 188JourneyDataExtract13Nov201919Nov2019.csv
# 189JourneyDataExtract20Nov2019-26Nov2019.csv renamed as 189JourneyDataExtract20Nov201926Nov2019.csv
# 18JourneyDataExtract10Aug2016-16Aug2016.csv renamed as 18JourneyDataExtract10Aug201616Aug2016.csv
# 190JourneyDataExtract27Nov2019-03Dec2019.csv renamed as 190JourneyDataExtract27Nov201903Dec2019.csv
# 191JourneyDataExtract04Dec2019-10Dec2019.csv renamed as 191JourneyDataExtract04Dec201910Dec2019.csv
# 192JourneyDataExtract11Dec2019-17Dec2019.csv renamed as 192JourneyDataExtract11Dec201917Dec2019.csv
# 193JourneyDataExtract18Dec2019-24Dec2019.csv renamed as 193JourneyDataExtract18Dec201924Dec2019.csv
# 194JourneyDataExtract25Dec2019-31Dec2019.csv renamed as 194JourneyDataExtract25Dec201931Dec2019.csv
# 195JourneyDataExtract01Jan2020-07Jan2020.csv renamed as 195JourneyDataExtract01Jan202007Jan2020.csv
# 196JourneyDataExtract08Jan2020-14Jan2020.csv renamed as 196JourneyDataExtract08Jan202014Jan2020.csv
# 197JourneyDataExtract15Jan2020-21Jan2020.csv renamed as 197JourneyDataExtract15Jan202021Jan2020.csv
# 198JourneyDataExtract22Jan2020-28Jan2020.csv renamed as 198JourneyDataExtract22Jan202028Jan2020.csv
# 199JourneyDataExtract29Jan2020-04Feb2020.csv renamed as 199JourneyDataExtract29Jan202004Feb2020.csv
# 19JourneyDataExtract17Aug2016-23Aug2016.csv renamed as 19JourneyDataExtract17Aug201623Aug2016.csv
# 1a.JourneyDataExtract04Jan15-17Jan15.csv renamed as 1a.JourneyDataExtract04Jan1517Jan15.csv
# 1aJourneyDataExtract04Jan15-17Jan15.csv renamed as 1aJourneyDataExtract04Jan1517Jan15.csv
# 1b.JourneyDataExtract18Jan15-31Jan15.csv renamed as 1b.JourneyDataExtract18Jan1531Jan15.csv
# 1bJourneyDataExtract18Jan15-31Jan15.csv renamed as 1bJourneyDataExtract18Jan1531Jan15.csv
# 2. Journey Data Extract 03Feb14-01Mar14.csv renamed as 2.JourneyDataExtract03Feb1401Mar14.csv
# 200JourneyDataExtract05Feb2020-11Feb2020.csv renamed as 200JourneyDataExtract05Feb202011Feb2020.csv
# 201JourneyDataExtract12Feb2020-18Feb2020.csv renamed as 201JourneyDataExtract12Feb202018Feb2020.csv
# 20JourneyDataExtract24Aug2016-30Aug2016.csv renamed as 20JourneyDataExtract24Aug201630Aug2016.csv
# 21JourneyDataExtract31Aug2016-06Sep2016.csv renamed as 21JourneyDataExtract31Aug201606Sep2016.csv
# 22JourneyDataExtract07Sep2016-13Sep2016.csv renamed as 22JourneyDataExtract07Sep201613Sep2016.csv
# 23JourneyDataExtract14Sep2016-20Sep2016.csv renamed as 23JourneyDataExtract14Sep201620Sep2016.csv
# 24JourneyDataExtract21Sep2016-27Sep2016.csv renamed as 24JourneyDataExtract21Sep201627Sep2016.csv
# 25JourneyDataExtract28Sep2016-04Oct2016.csv renamed as 25JourneyDataExtract28Sep201604Oct2016.csv
# 26JourneyDataExtract05Oct2016-11Oct2016.csv renamed as 26JourneyDataExtract05Oct201611Oct2016.csv
# 27JourneyDataExtract12Oct2016-18Oct2016.csv renamed as 27JourneyDataExtract12Oct201618Oct2016.csv
# 28JourneyDataExtract19Oct2016-25Oct2016.csv renamed as 28JourneyDataExtract19Oct201625Oct2016.csv
# 29JourneyDataExtract26Oct2016-01Nov2016.csv renamed as 29JourneyDataExtract26Oct201601Nov2016.csv
# 2JourneyDataExtract03Feb14-01Mar14.csv renamed as 2JourneyDataExtract03Feb1401Mar14.csv
# 2a.JourneyDataExtract01Feb15-14Feb15.csv renamed as 2a.JourneyDataExtract01Feb1514Feb15.csv
# 2aJourneyDataExtract01Feb15-14Feb15.csv renamed as 2aJourneyDataExtract01Feb1514Feb15.csv
# 2b.JourneyDataExtract15Feb15-28Feb15.csv renamed as 2b.JourneyDataExtract15Feb1528Feb15.csv
# 2bJourneyDataExtract15Feb15-28Feb15.csv renamed as 2bJourneyDataExtract15Feb1528Feb15.csv
# 3. Journey Data Extract 02Mar14-31Mar14.csv renamed as 3.JourneyDataExtract02Mar1431Mar14.csv
# 30JourneyDataExtract02Nov2016-08Nov2016.csv renamed as 30JourneyDataExtract02Nov201608Nov2016.csv
# 31JourneyDataExtract09Nov2016-15Nov2016.csv renamed as 31JourneyDataExtract09Nov201615Nov2016.csv
# 32JourneyDataExtract16Nov2016-22Nov2016.csv renamed as 32JourneyDataExtract16Nov201622Nov2016.csv
# 33JourneyDataExtract23Nov2016-29Nov2016.csv renamed as 33JourneyDataExtract23Nov201629Nov2016.csv
# 34JourneyDataExtract30Nov2016-06Dec2016.csv renamed as 34JourneyDataExtract30Nov201606Dec2016.csv
# 35JourneyDataExtract07Dec2016-13Dec2016.csv renamed as 35JourneyDataExtract07Dec201613Dec2016.csv
# 36JourneyDataExtract14Dec2016-20Dec2016.csv renamed as 36JourneyDataExtract14Dec201620Dec2016.csv
# 37JourneyDataExtract21Dec2016-27Dec2016.csv renamed as 37JourneyDataExtract21Dec201627Dec2016.csv
# 38JourneyDataExtract28Dec2016-03Jan2017.csv renamed as 38JourneyDataExtract28Dec201603Jan2017.csv
# 39JourneyDataExtract04Jan2017-10Jan2017.csv renamed as 39JourneyDataExtract04Jan201710Jan2017.csv
# 3JourneyDataExtract02Mar14-31Mar14.csv renamed as 3JourneyDataExtract02Mar1431Mar14.csv
# 3a.JourneyDataExtract01Mar15-15Mar15.csv renamed as 3a.JourneyDataExtract01Mar1515Mar15.csv
# 3aJourneyDataExtract01Mar15-15Mar15.csv renamed as 3aJourneyDataExtract01Mar1515Mar15.csv
# 3b.JourneyDataExtract16Mar15-31Mar15.csv renamed as 3b.JourneyDataExtract16Mar1531Mar15.csv
# 3bJourneyDataExtract16Mar15-31Ma8aJourneyDataExtract20Jul14-31Jul14.csv not renamed: 8aJourneyDataExtract20Jul1431Jul14.csv already exists
# 8bJourneyDataExtract01Aug14-16Aug14.csv not renamed: 8bJourneyDataExtract01Aug1416Aug14.csv already exists
# 9aJourneyDataExtract17Aug14-31Aug14.csv not renamed: 9aJourneyDataExtract17Aug1431Aug14.csv already exists
# 9bJourneyDataExtract01Sep14-13Sep14.csv not renamed: 9bJourneyDataExtract01Sep1413Sep14.csv already exists
# r15.csv renamed as 3bJourneyDataExtract16Mar1531Mar15.csv
# 4. Journey Data Extract 01Apr14-26Apr14.csv renamed as 4.JourneyDataExtract01Apr1426Apr14.csv
# 40JourneyDataExtract11Jan2017-17Jan2017.csv renamed as 40JourneyDataExtract11Jan201717Jan2017.csv
# 41JourneyDataExtract18Jan2017-24Jan2017.csv renamed as 41JourneyDataExtract18Jan201724Jan2017.csv
# 42JourneyDataExtract25Jan2017-31Jan2017.csv renamed as 42JourneyDataExtract25Jan201731Jan2017.csv
# 43JourneyDataExtract01Feb2017-07Feb2017.csv renamed as 43JourneyDataExtract01Feb201707Feb2017.csv
# 44JourneyDataExtract08Feb2017-14Feb2017.csv renamed as 44JourneyDataExtract08Feb201714Feb2017.csv
# 45JourneyDataExtract15Feb2017-21Feb2017.csv renamed as 45JourneyDataExtract15Feb201721Feb2017.csv
# 46JourneyDataExtract22Feb2017-28Feb2017.csv renamed as 46JourneyDataExtract22Feb201728Feb2017.csv
# 47JourneyDataExtract01Mar2017-07Mar2017.csv renamed as 47JourneyDataExtract01Mar201707Mar2017.csv
# 48JourneyDataExtract08Mar2017-14Mar2017.csv renamed as 48JourneyDataExtract08Mar201714Mar2017.csv
# 49JourneyDataExtract15Mar2017-21Mar2017.csv renamed as 49JourneyDataExtract15Mar201721Mar2017.csv
# 4JourneyDataExtract01Apr14-26Apr14.csv renamed as 4JourneyDataExtract01Apr1426Apr14.csv
# 4a.JourneyDataExtract01Apr15-16Apr15.csv renamed as 4a.JourneyDataExtract01Apr1516Apr15.csv
# 4aJourneyDataExtract01Apr15-16Apr15.csv renamed as 4aJourneyDataExtract01Apr1516Apr15.csv
# 4b.JourneyDataExtract17Apr15-02May15.csv renamed as 4b.JourneyDataExtract17Apr1502May15.csv
# 4bJourneyDataExtract17Apr15-02May15.csv renamed as 4bJourneyDataExtract17Apr1502May15.csv
# 5. Journey Data Extract 27Apr14-24May14.csv renamed as 5.JourneyDataExtract27Apr1424May14.csv
# 50JourneyDataExtract22Mar2017-28Mar2017.csv renamed as 50JourneyDataExtract22Mar201728Mar2017.csv
# 51JourneyDataExtract29Mar2017-04Apr2017.csv renamed as 51JourneyDataExtract29Mar201704Apr2017.csv
# 52JourneyDataExtract05Apr2017-11Apr2017.csv renamed as 52JourneyDataExtract05Apr201711Apr2017.csv
# 53JourneyDataExtract12Apr2017-18Apr2017.csv renamed as 53JourneyDataExtract12Apr201718Apr2017.csv
# 54JourneyDataExtract19Apr2017-25Apr2017.csv renamed as 54JourneyDataExtract19Apr201725Apr2017.csv
# 55JourneyDataExtract26Apr2017-02May2017.csv renamed as 55JourneyDataExtract26Apr201702May2017.csv
# 56JourneyDataExtract03May2017-09May2017.csv renamed as 56JourneyDataExtract03May201709May2017.csv
# 57JourneyDataExtract10May2017-16May2017.csv renamed as 57JourneyDataExtract10May201716May2017.csv
# 58JourneyDataExtract17May2017-23May2017.csv renamed as 58JourneyDataExtract17May201723May2017.csv
# 59JourneyDataExtract24May2017-30May2017.csv renamed as 59JourneyDataExtract24May201730May2017.csv
# 5JourneyDataExtract27Apr14-24May14.csv renamed as 5JourneyDataExtract27Apr1424May14.csv
# 5a.JourneyDataExtract03May15-16May15.csv renamed as 5a.JourneyDataExtract03May1516May15.csv
# 5aJourneyDataExtract03May15-16May15.csv renamed as 5aJourneyDataExtract03May1516May15.csv
# 5b.JourneyDataExtract17May15-30May15.csv renamed as 5b.JourneyDataExtract17May1530May15.csv
# 5bJourneyDataExtract17May15-30May15.csv renamed as 5bJourneyDataExtract17May1530May15.csv
# 6. Journey Data Extract 25May14-21Jun14.csv renamed as 6.JourneyDataExtract25May1421Jun14.csv
# 60JourneyDataExtract31May2017-06Jun2017.csv renamed as 60JourneyDataExtract31May201706Jun2017.csv
# 61JourneyDataExtract07Jun2017-13Jun2017.csv renamed as 61JourneyDataExtract07Jun201713Jun2017.csv
# 62JourneyDataExtract14Jun2017-20Jun2017.csv renamed as 62JourneyDataExtract14Jun201720Jun2017.csv
# 63JourneyDataExtract21Jun2017-27Jun2017.csv renamed as 63JourneyDataExtract21Jun201727Jun2017.csv
# 64JourneyDataExtract28Jun2017-04Jul2017.csv renamed as 64JourneyDataExtract28Jun201704Jul2017.csv
# 65JourneyDataExtract05Jul2017-11Jul2017.csv renamed as 65JourneyDataExtract05Jul201711Jul2017.csv
# 66JourneyDataExtract12Jul2017-18Jul2017.csv renamed as 66JourneyDataExtract12Jul201718Jul2017.csv
# 67JourneyDataExtract19Jul2017-25Jul2017.csv renamed as 67JourneyDataExtract19Jul201725Jul2017.csv
# 68JourneyDataExtract26Jul2017-31Jul2017.csv renamed as 68JourneyDataExtract26Jul201731Jul2017.csv
# 69JourneyDataExtract01Aug2017-07Aug2017.csv renamed as 69JourneyDataExtract01Aug201707Aug2017.csv
# 6JourneyDataExtract25May14-21Jun14.csv renamed as 6JourneyDataExtract25May1421Jun14.csv
# 6aJourneyDataExtract31May15-12Jun15.csv renamed as 6aJourneyDataExtract31May1512Jun15.csv
# 6bJourneyDataExtract13Jun15-27Jun15.csv renamed as 6bJourneyDataExtract13Jun1527Jun15.csv
# 7. Journey Data Extract 22Jun14-19Jul14.csv renamed as 7.JourneyDataExtract22Jun1419Jul14.csv
# 70JourneyDataExtract08Aug2017-14Aug2017.csv renamed as 70JourneyDataExtract08Aug201714Aug2017.csv
# 71JourneyDataExtract15Aug2017-22Aug2017.csv renamed as 71JourneyDataExtract15Aug201722Aug2017.csv
# 72JourneyDataExtract23Aug2017-29Aug2017.csv renamed as 72JourneyDataExtract23Aug201729Aug2017.csv
# 73JourneyDataExtract30Aug2017-05Sep2017.csv renamed as 73JourneyDataExtract30Aug201705Sep2017.csv
# 74JourneyDataExtract06Sep2017-12Sep2017.csv renamed as 74JourneyDataExtract06Sep201712Sep2017.csv
# 75JourneyDataExtract13Sep2017-19Sep2017.csv renamed as 75JourneyDataExtract13Sep201719Sep2017.csv
# 76JourneyDataExtract20Sep2017-26Sep2017.csv renamed as 76JourneyDataExtract20Sep201726Sep2017.csv
# 77JourneyDataExtract27Sep2017-03Oct2017.csv renamed as 77JourneyDataExtract27Sep201703Oct2017.csv
# 78JourneyDataExtract04Oct2017-10Oct2017.csv renamed as 78JourneyDataExtract04Oct201710Oct2017.csv
# 79JourneyDataExtract11Oct2017-17Oct2017.csv renamed as 79JourneyDataExtract11Oct201717Oct2017.csv
# 7JourneyDataExtract22Jun14-19Jul14.csv renamed as 7JourneyDataExtract22Jun1419Jul14.csv
# 7a.JourneyDataExtract28Jun15-11Jul15.csv renamed as 7a.JourneyDataExtract28Jun1511Jul15.csv
# 7aJourneyDataExtract28Jun15-11Jul15.csv renamed as 7aJourneyDataExtract28Jun1511Jul15.csv
# 7b.JourneyDataExtract12Jul15-25Jul15.csv renamed as 7b.JourneyDataExtract12Jul1525Jul15.csv
# 7bJourneyDataExtract12Jul15-25Jul15.csv renamed as 7bJourneyDataExtract12Jul1525Jul15.csv
# 80JourneyDataExtract18Oct2017-24Oct2017.csv renamed as 80JourneyDataExtract18Oct201724Oct2017.csv
# 81JourneyDataExtract25Oct2017-31Oct2017.csv renamed as 81JourneyDataExtract25Oct201731Oct2017.csv
# 82JourneyDataExtract01Nov2017-07Nov2017.csv renamed as 82JourneyDataExtract01Nov201707Nov2017.csv
# 83JourneyDataExtract08Nov2017-14Nov2017.csv renamed as 83JourneyDataExtract08Nov201714Nov2017.csv
# 84JourneyDataExtract15Nov2017-21Nov2017.csv renamed as 84JourneyDataExtract15Nov201721Nov2017.csv
# 85JourneyDataExtract22Nov2017-28Nov2017.csv renamed as 85JourneyDataExtract22Nov201728Nov2017.csv
# 86JourneyDataExtract29Nov2017-05Dec2017.csv renamed as 86JourneyDataExtract29Nov201705Dec2017.csv
# 87JourneyDataExtract06Dec2017-12Dec2017.csv renamed as 87JourneyDataExtract06Dec201712Dec2017.csv
# 88JourneyDataExtract13Dec2017-19Dec2017.csv renamed as 88JourneyDataExtract13Dec201719Dec2017.csv
# 89JourneyDataExtract20Dec2017-26Dec2017.csv renamed as 89JourneyDataExtract20Dec201726Dec2017.csv
# 8a Journey Data Extract 20Jul14-31Jul14.csv renamed as 8aJourneyDataExtract20Jul1431Jul14.csv
# 8a-Journey-Data-Extract-26Jul15-07Aug15.csv renamed as 8aJourneyDataExtract26Jul1507Aug15.csv
# 8b Journey Data Extract 01Aug14-16Aug14.csv renamed as 8bJourneyDataExtract01Aug1416Aug14.csv
# 8b-Journey-Data-Extract-08Aug15-22Aug15.csv renamed as 8bJourneyDataExtract08Aug1522Aug15.csv
# 90JourneyDataExtract27Dec2017-02Jan2018.csv renamed as 90JourneyDataExtract27Dec201702Jan2018.csv
# 91JourneyDataExtract03Jan2018-09Jan2018.csv renamed as 91JourneyDataExtract03Jan201809Jan2018.csv
# 92JourneyDataExtract10Jan2018-16Jan2018.csv renamed as 92JourneyDataExtract10Jan201816Jan2018.csv
# 93JourneyDataExtract17Jan2018-23Jan2018.csv renamed as 93JourneyDataExtract17Jan201823Jan2018.csv
# 94JourneyDataExtract24Jan2018-30Jan2018.csv renamed as 94JourneyDataExtract24Jan201830Jan2018.csv
# 95JourneyDataExtract31Jan2018-06Feb2018.csv renamed as 95JourneyDataExtract31Jan201806Feb2018.csv
# 96JourneyDataExtract07Feb2018-13Feb2018.csv renamed as 96JourneyDataExtract07Feb201813Feb2018.csv
# 97JourneyDataExtract14Feb2018-20Feb2018.csv renamed as 97JourneyDataExtract14Feb201820Feb2018.csv
# 98JourneyDataExtract21Feb2018-27Feb2018.csv renamed as 98JourneyDataExtract21Feb201827Feb2018.csv
# 99JourneyDataExtract28Feb2018-06Mar2018.csv renamed as 99JourneyDataExtract28Feb201806Mar2018.csv
# 9a Journey Data Extract 17Aug14-31Aug14.csv renamed as 9aJourneyDataExtract17Aug1431Aug14.csv
# 9a-Journey-Data-Extract-23Aug15-05Sep15.csv renamed as 9aJourneyDataExtract23Aug1505Sep15.csv
# 9b Journey Data Extract 01Sep14-13Sep14.csv renamed as 9bJourneyDataExtract01Sep1413Sep14.csv
# 9b-Journey-Data-Extract-06Sep15-19Sep15.csv renamed as 9bJourneyDataExtract06Sep1519Sep15.csv
# /mnt/57982e2a-2874-4246-a6fe-115c199bc6bd/atfutures/repos/cycle-hire-inclusive


