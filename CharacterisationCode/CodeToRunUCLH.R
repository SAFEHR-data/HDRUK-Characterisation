
renv::restore()

# acronym to identify the database
# beware dbName identifies outputs, dbname is UCLH db
# here different outputs can be created for each UCLH schema which is a different omop extract

# TO RUN choose a dbName,cdmSchema pair, comment out others, source script

#dbName <- "UCLH-EHDEN"
#cdmSchema <- "ehden_001"
#2025-01-20 completed in ~2.5 hours

# dbName <- "UCLH-6months"
# cdmSchema <- "data_catalogue_003" #6 months
# put brief progress here

# dbName <- "UCLH-2years"
# cdmSchema <- "data_catalogue_004" #2 years
# put brief progress here

# create a DBI connection to UCLH database
# using credentials in .Renviron or you can replace with hardcoded values here
user <- Sys.getenv("user")
host <- Sys.getenv("host")
port <- Sys.getenv("port")
dbname <- Sys.getenv("dbname")
# schema in database where you have writing permissions
writeSchema <- "_other_andsouth"

if("" %in% c(user, host, port, dbname, writeSchema))
  stop("seems you don't have (all?) db credentials stored in your .Renviron file, use usethis::edit_r_environ() to create")
pwd <- rstudioapi::askForPassword("Password for omop_db")


con <- DBI::dbConnect(RPostgres::Postgres(),user = user, host = host, port = port, dbname = dbname, password=pwd)

#you get this if not connected to VPN
#Error: could not translate host name ... to address: Unknown host

# created tables will start with this prefix
prefix <- "uclh_hdruk_benchmark"

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

source("RunCharacterisation.R")
