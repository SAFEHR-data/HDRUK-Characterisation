
renv::restore()

## START OF SETTINGS copied between benchmarking, characterisation & antibiotics study

########################
# omop_reservoir version
# older extract, but more up to date postgres
# beware dbName identifies outputs, dbname is UCLH db
dbName <- "UCLH-from-2019-v2"
cdmSchema <- "data_catalogue_007" #from 2019
user <- Sys.getenv("user")
host <- Sys.getenv("host")
port <- Sys.getenv("port")
dbname <- Sys.getenv("dbname")
pwd <- Sys.getenv("pwd")
writeSchema <- "_other_andsouth"

if("" %in% c(user, host, port, dbname, pwd, writeSchema))
  stop("seems you don't have (all?) db credentials stored in your .Renviron file, use usethis::edit_r_environ() to create")

#pwd <- rstudioapi::askForPassword("Password for omop_db")

con <- DBI::dbConnect(RPostgres::Postgres(),user = user, host = host, port = port, dbname = dbname, password=pwd)

#you get this if not connected to VPN
#Error: could not translate host name ... to address: Unknown host

#list tables
DBI::dbListObjects(con, DBI::Id(schema = cdmSchema))
DBI::dbListObjects(con, DBI::Id(schema = writeSchema))

# created tables will start with this prefix
prefix <- "hdruk_characterisation"

# minimum cell counts used for suppression
minCellCount <- 5

# to create the cdm object
cdm <- CDMConnector::cdmFromCon(
  con = con,
  cdmSchema = cdmSchema,
  writeSchema =  writeSchema,
  writePrefix = prefix,
  cdmName = dbName,
  .softValidation = TRUE
)

#to drop tables, beware if no prefix also everything()
#cdm <- CDMConnector::dropSourceTable(cdm = cdm, name = dplyr::starts_with("hdruk"))


# a patch to remove records where drug_exposure_start_date > drug_exposure_end_date
# ~2.5k rows in 2019 extract
#defail <- cdm$drug_exposure |> dplyr::filter(drug_exposure_start_date > drug_exposure_end_date) |>  collect()
cdm$drug_exposure <- cdm$drug_exposure |> dplyr::filter(drug_exposure_start_date <= drug_exposure_end_date)


########################
# fix observation_period that got messed up in latest extract
op2 <- cdm$visit_occurrence |>
  group_by(person_id) |> 
  summarise(minvis = min(coalesce(date(visit_start_datetime), visit_start_date), na.rm=TRUE),
            maxvis = max(coalesce(date(visit_end_datetime), visit_end_date), na.rm=TRUE)) |> 
  left_join(select(cdm$death,person_id,death_date), by=join_by(person_id)) |> 
  #set maxvisit to death_date if before
  #mutate(maxvis=min(maxvis, death_date, na.rm=TRUE))
  mutate(maxvis = if_else(!is.na(death_date) & maxvis > death_date, death_date, maxvis))

cdm$observation_period <- cdm$observation_period |>    
  left_join(op2, by=join_by(person_id)) |>
  select(-observation_period_start_date) |> 
  select(-observation_period_end_date) |> 
  rename(observation_period_start_date=minvis,
         observation_period_end_date=maxvis)


# 1752 patients to remove 
persremove <- cdm$observation_period |> 
  filter(observation_period_end_date < observation_period_start_date) |> 
  pull(person_id)

cdm$person              <- cdm$person |> filter(! person_id %in% persremove)
cdm$observation_period  <- cdm$observation_period |> filter(! person_id %in% persremove)
cdm$visit_occurrence    <- cdm$visit_occurrence |> filter(! person_id %in% persremove)
cdm$drug_exposure        <- cdm$drug_exposure |> filter(! person_id %in% persremove)

# cdm$condition_occurrence <- cdm$condition_occurrence |> filter(! person_id %in% persremove)
# cdm$procedure_occurrence <- cdm$procedure_occurrence |> filter(! person_id %in% persremove)
# cdm$device_exposure     <- cdm$device_exposure |> filter(! person_id %in% persremove)
# cdm$observation         <- cdm$observation |> filter(! person_id %in% persremove)
# cdm$measurement         <- cdm$measurement |> filter(! person_id %in% persremove)

cdm$person <- cdm$person |> mutate(location_id = ifelse(is.na(location_id),1,location_id))

#trying compute & save to temporary table (will appear in db with pre) 
cdm$observation_period <- cdm$observation_period |> 
  select(-death_date) |> 
  compute("observation_period")

cdm$person <- cdm$person |> 
  compute("person")  

# 2025-02-04
# a patch to cope with records where drug_exposure_start_date > drug_exposure_end_date
# this causes error in benchmarking with 2 year extract (only 577 rows)
cdm$drug_exposure <- cdm$drug_exposure |> dplyr::filter(drug_exposure_start_date <= drug_exposure_end_date)


## END OF SETTINGS copied between benchmarking, characterisation & antibiotics study

source("RunCharacterisation.R")
