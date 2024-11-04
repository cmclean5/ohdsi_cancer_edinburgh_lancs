# ============================================================================ #
#                           DB CONNECTION SCRIPT                               #
#                                                                              #
#                                Colin Mclean                                  #
#                            Colin.D.Mclean@ed.ac.uk                           #
#                                 08-09-2024                                   #
#                                                                              #
#             THIS SCRIPT DEPENDS ON YOU ENTERING YOUR                         #
#             DB CREDENTIALS USING THE KEYRING R PACKAGE                       #
#             ## install.packages("keyring")                                   #
#             library(keyring)                                                 #
#             keyring::key_set_with_value("db.name", password   = NULL)        #  
#             keyring::key_set_with_value("driver", password    = NULL)        #
#             keyring::key_set_with_value("server", password    = NULL)        #
#             keyring::key_set_with_value("port", password      = NULL)        #
#             keyring::key_set_with_value("host", password      = NULL)        #
#             keyring::key_set_with_value("user.name", password = NULL)        #
#             keyring::key_set_with_value("pass.word", password = NULL)        #
#                                                                              #
#             REPLACE NULL WITH YOUR VALUE BETWEEN QUOTES, IE "MY.VALUE"       #
#                                                                              #
#                                                                              #
#             AND YOUR CDM DETIALS INTO THE FOLLING FILE:                      # 
#             Params/cdm.params.csv                                            #
#             Name,Value                                                       #
#             "study.name","YOUR.STUDY.NAME"                                   #
#             "cdm_database_schema","OMOP_CDM"                                 #
#             "vocabulary_database_schema","omop_cdm"                          #
#             "results_database_schema","omop_results"                         #
#             "table_stem","YOUR.ANALYSIS.NAME"                                #
# ============================================================================ #


## -------------------------------------------------------------------------- ##
## Database connection object
## -------------------------------------------------------------------------- ##
db = NULL


## -------------------------------------------------------------------------- ##
## Set database details
## -------------------------------------------------------------------------- ##


## -------------------------------------------------------------------------- ##
## read-in cdm parameter file
## -------------------------------------------------------------------------- ##
params = read.csv(here("Params/cdm.params.csv"),header=T)


## -------------------------------------------------------------------------- ##
## get database connection details from keyring
## -------------------------------------------------------------------------- ##
keyring_name     = Sys.getenv("MY_KEYRING_NAME")
keyring_password = Sys.getenv("MY_KEYRING_PASSWORD") 
keyring::keyring_unlock(keyring = keyring_name, password = keyring_password)

SERVICES  = c("db.name","server","driver","port","host","user.name","pass.word")
DB.VALUES = list()

for( i in SERVICES){
  DB.VALUES[[i]] = keyring::key_get(keyring = keyring_name, service = i)
}


keyring::keyring_lock(keyring = keyring_name)


## -------------------------------------------------------------------------- ##
## replace empty valued strings with NULL
## -------------------------------------------------------------------------- ##
DB.VALUES = lapply(DB.VALUES, function(x) if (x=="") NULL else x)


## -------------------------------------------------------------------------- ##
## The name of the group that contains the OMOP CDM
## -------------------------------------------------------------------------- ##
group.name = params$Value[which(params$Name=="group.name")]

## -------------------------------------------------------------------------- ##
## The name of the schema that contains the OMOP CDM with patient-level data
## -------------------------------------------------------------------------- ##
cdm_database_schema = params$Value[which(params$Name=="cdm_database_schema")]


## -------------------------------------------------------------------------- ##
## The name of the schema that contains the vocabularies 
## (often this will be the same as cdm_database_schema)
## -------------------------------------------------------------------------- ##
vocabulary_database_schema = params$Value[which(params$Name=="vocabulary_database_schema")]


## -------------------------------------------------------------------------- ##
## The name of the schema where results tables will be created 
## -------------------------------------------------------------------------- ##
results_database_schema = params$Value[which(params$Name=="results_database_schema")]


## -------------------------------------------------------------------------- ##
## stem table description use something short and informative such as ehdenwp2 or your initials
## Note, if there is an existing table in your results schema with the same names it will be overwritten 
## needs to be in lower case and NOT more than 10 characters
## -------------------------------------------------------------------------- ##
table_stem = params$Value[which(params$Name=="table_stem")]


## -------------------------------------------------------------------------- ##
## Specify cdm_reference via DBI connection details 
## -------------------------------------------------------------------------- ##
db = DBI::dbConnect(odbc::odbc(),
                     server   = DB.VALUES[[which(names(DB.VALUES)=="server")]],
                     Database = DB.VALUES[[which(names(DB.VALUES)=="db.name")]],
                     driver   = DB.VALUES[[which(names(DB.VALUES)=="driver")]],
                     port     = DB.VALUES[[which(names(DB.VALUES)=="port")]],
                     host     = DB.VALUES[[which(names(DB.VALUES)=="host")]],
                     user     = DB.VALUES[[which(names(DB.VALUES)=="user.name")]],
                     password = DB.VALUES[[which(names(DB.VALUES)=="pass.word")]],
                     trusted_connection = "yes")


## -------------------------------------------------------------------------- ##
## create cdm reference ---- DO NOT REMOVE "PREFIX" ARGUMENT IN THIS CODE
## -------------------------------------------------------------------------- ##
cdm.tmp = CDMConnector::cdm_from_con(con           = db, 
                                      cdm_schema   = cdm_database_schema,
                                      write_schema = results_database_schema)


## -------------------------------------------------------------------------- ##
## 
## Since we're only interested in patients found in both covid and cancer db's 
## we can filter cdm.can for only these patients.
## -------------------------------------------------------------------------- ##
if( group.name == "ECI" ){

  ## -------------------------------------------------------------------------- ##
  ## First Get ID mappings Cancer & Covid dbs
  ## -------------------------------------------------------------------------- ##
  mapping.table = "patients_id_mapping"
  query1        = render("select * from @tab;", tab=mapping.table)
  id.map        = DBI::dbGetQuery(conn=db, query1)
  subset.ids    = id.map %>% filter(!is.na(covid_cdm_id)) %>% pull(person_id)


  ## -------------------------------------------------------------------------- ##
  ## create cdm on subset of patient ids which are found in both covid & cancer db's
  ## -------------------------------------------------------------------------- ##
  cdm = CDMConnector::cdmSubset(cdm.tmp, subset.ids)

} else {
  cdm = cdm.tmp
}

## -------------------------------------------------------------------------- ##
## test
## -------------------------------------------------------------------------- ##
#cdm$person %>% 
#  tally()


## -------------------------------------------------------------------------- ##
## delete redundant cdm.tmp reference
## -------------------------------------------------------------------------- ##
rm(cdm.tmp)