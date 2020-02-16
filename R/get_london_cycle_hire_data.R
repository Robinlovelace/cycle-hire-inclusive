
data_dir = "data/london"
sqf = file.path(data_dir, "london_bike_hire_2020-02.sqlite")
list.files(data_dir)
bikedata::dl_bikedata(city = "london", data_dir = data_dir)
ntrips = bikedata::store_bikedata(bikedb = sqf, data_dir = "data/london")
file.size(sqf) # 6.5 GB

bikes_data = DBI::dbConnect(RSQLite::SQLite(), sqf)
DBI::dbListTables(bikes_data)
system.time({trips = tbl(bikes_data, "trips")})

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
