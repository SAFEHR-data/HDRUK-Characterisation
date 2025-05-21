# uclh_lsoa_person_count.R
# andy south 2025-05-14

library(dplyr)
library(readr)

# this is freq of locations, to do by patient I should join to the person table
freqlsoa <- cdm$location |> 
  count(zip, sort=TRUE) |> 
  collect()

freq_person_lsoa <- cdm$person |> 
  left_join(cdm$location, by=join_by(location_id)) |> 
  count(zip, sort=TRUE) |> 
  collect()

#save locally & export, download from RStudio
outfilename <- "uclh_freq_person_lsoa2.csv"

write_csv(freq_person_lsoa, file=outfilename)

# seems to be a problem with this 
# it gives 97% of patients with lsoa==NA

# I wonder if it could be because
# there is more than one location_id per lsoa
# (because lsoa came from postcode that is finer)

freq_loc_id <- cdm$person |> count(location_id, sort=TRUE) |>  collect()

freq_loc_id |> filter(is.na(location_id))
# location_id       n
#   1          NA 1353708

freq_loc_id_na <- cdm$person |> count(is.na(location_id), sort=TRUE) |>  collect()

head(freq_person_lsoa,10)

# previous extract
# 1 99AA0IUK    26403
# 2 99AA0OUK    26212
# 3 99AA0NFA     4499
# 4 E01000953    4089
# 5 E01002702    3244

# new extract
# 1 NA        1353708
# 2 99AA0IUK    21541
# 3 99AA0NFA     1473
# 4 E01003960     274
# 5 E01002713     265

#1.3 million patients had no location_id in the new extract
#but they did in a previous one used here

# to test the lsoa freqs with a map
# 
remotes::install_github("humaniverse/geographr")

library(geographr)
library(sf)
library(tidyr)
library(ggplot2)

#lsoas are in geographr::boundaries_lsoa11
#names(geographr::boundaries_lsoa11)
#[1] "lsoa11_name" "lsoa11_code" "geometry" 

lsoamapdata <- cdm$person |> 
  left_join(cdm$location, by="location_id") |> 
  # #zip is column containing lsoa codes
  count(zip, sort =TRUE, name="npatients") |> 
  collect() |> 
  left_join(geographr::boundaries_lsoa11, by=join_by(zip==lsoa11_code))

#seem to need geometry=geometry below - even though I think it should be found by default
#to avoid : error in `compute_layer()`:! `stat_sf()` requires the following missing aesthetics: geometry
bb <- sf::st_bbox(st_as_sf(lsoamapdata))

lsoamapdata |> 
  filter(!is.na(lsoa11_name)) |> 
  ggplot() +
  geom_sf(aes(fill=npatients, geometry=geometry),colour=NA,linewidth=0) +
  #scale_color_viridis_b(direction = -1) +
  #scale_fill_viridis_b(direction = -1) +
  scale_fill_viridis_b(transform="log10") + 
  #scale_fill_gradient() +   
  #scale_fill_gradient(transform="log10") +  
  #scale_fill_continuous(transform="log10") +    
  #theme_minimal() +
  theme_void() +
  geom_sf(data=geographr::boundaries_countries20,colour="lightgrey", fill=NA) +
  coord_sf(xlim=c(bb$xmin,bb$xmax), ylim=c(bb$ymin,bb$ymax))

