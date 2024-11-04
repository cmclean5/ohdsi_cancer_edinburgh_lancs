## libraries
library(here)
library(Capr)
library(CodelistGenerator)


## -------------------------------------------------------------------------- ##
## read-in cdm parameter file
## -------------------------------------------------------------------------- ##
params = read.csv(here("Params/cdm.params.csv"),header=T)


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
## Specify cdm_reference via DBI connection details 
## -------------------------------------------------------------------------- ##
db = DBI::dbConnect(odbc::odbc(),
                    server   = DB.VALUES[[which(names(DB.VALUES)=="server")]],
                    Database = DB.VALUES[[which(names(DB.VALUES)=="db.name")]],
                    driver   = DB.VALUES[[which(names(DB.VALUES)=="driver")]],
                    trusted_connection = "yes")


##---------------------------------------------------------------------------------------------------
## early Breast Cancer (eBC) concept set - defined through Capr
##---------------------------------------------------------------------------------------------------

## Set our Cohort Study Name:
cohort_name = "early_breast_cancer"


##---------------------------------------------------------------------------------------------------
## read in our eBC concept set 
##---------------------------------------------------------------------------------------------------
concept_ids = read.csv(here("Params/ebcr_concept_codes.csv"),header=T)[[1]]
cs_name     = "breast"


##---------------------------------------------------------------------------------------------------
## New definition for BrC patients
##---------------------------------------------------------------------------------------------------
cs0  = Capr::cs(concept_ids, name=cs_name) ## descendants(concept_ids), name=cs_name) 


##---------------------------------------------------------------------------------------------------
## Fill in concept Set details using a vocab
##---------------------------------------------------------------------------------------------------
CS0 = Capr::getConceptSetDetails(x=cs0, con=db, vocabularyDatabaseSchema=cdm_database_schema)


##---------------------------------------------------------------------------------------------------
## Build eBC cohort using our concept set from CONDITION TABLE
##---------------------------------------------------------------------------------------------------
capr_ch = Capr::cohort(
           entry = Capr::entry(Capr::conditionOccurrence(CS0),
                               primaryCriteriaLimit="First",
                               observationWindow = Capr::continuousObservation(priorDays=0L, postDays=0L)),
           attrition = Capr::attrition(
                         "Inclusion" = Capr::withAny(
                           Capr::exactly(1, Capr::conditionOccurrence(CS0), Capr::eventStarts(0L, 0L, index = "startDate")))),
                           exit  = Capr::exit(fixedExit(index="endDate",0L)))


##---------------------------------------------------------------------------------------------------
## Save cohort as JSON:
## OHDSI standard cohorts are represented as json files and can be copy and pasted into Atlas.
##---------------------------------------------------------------------------------------------------
cohortJsonFileName = "ECI_LANC_BreastCancer.json"
cohortJsonFilePath = here("InstantiateCohorts", "Cohorts", cohortJsonFileName)
Capr::writeCohort(capr_ch, cohortJsonFilePath)  


##---------------------------------------------------------------------------------------------------
## CodelistGenerator allows us to get concept codes from a key phrases. Capr can read in these 
## concept ids and save the concept set to json file. 
## Example, save an exclusion set to json file for key phrase "Secondary malignant neoplasm of breast"   
##---------------------------------------------------------------------------------------------------
exclude_codes <- CodelistGenerator::getCandidateCodes(
  cdm = cdm,
  keywords = c("Secondary malignant neoplasm of breast"),
  includeDescendants = TRUE,
  includeAncestor = TRUE,
  domains  = c("Condition")
)


##---------------------------------------------------------------------------------------------------
## New definition for our concept ids
##---------------------------------------------------------------------------------------------------
ex0 = Capr::cs(exclude_codes$concept_id, name="exclusion_set")


##---------------------------------------------------------------------------------------------------
## Fill in concept Set details using a vocab
##---------------------------------------------------------------------------------------------------
EX0 = Capr::getConceptSetDetails(x=ex0, con=db, vocabularyDatabaseSchema=cdm_database_schema)


##---------------------------------------------------------------------------------------------------
## Build Exclusion cohort using our concept set from CONDITION TABLE
##---------------------------------------------------------------------------------------------------
capr_ex = Capr::cohort(
    entry = Capr::entry(Capr::conditionOccurrence(EX0),
                        primaryCriteriaLimit="First",
                        observationWindow = Capr::continuousObservation(priorDays=0L, postDays=0L)),
    attrition = Capr::attrition(
                   "Inclusion" = Capr::withAny(
                      Capr::exactly(1, Capr::conditionOccurrence(EX0), Capr::eventStarts(0L, 0L, index = "startDate")))),
                      exit  = Capr::exit(fixedExit(index="endDate",0L)))


##---------------------------------------------------------------------------------------------------
## Save cohort as JSON:
## OHDSI standard cohorts are represented as json files and can be copy and pasted into Atlas.
##---------------------------------------------------------------------------------------------------
cohortJsonFileName = "ECI_LANC_Secondary_BrC.json"
cohortJsonFilePath = here("InstantiateCohorts", "Exclusion", cohortJsonFileName)
Capr::writeCohort(capr_ex, cohortJsonFilePath)  
