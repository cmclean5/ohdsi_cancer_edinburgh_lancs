# ============================================================================ #
#              CODE TO RUN EARLY BREAST CANCER/COVID  STUDY                    #
#                                                                              #
#                                Colin Mclean                                  #
#                            Colin.D.Mclean@ed.ac.uk                           #
#                                 08-09-2024                                   #
#                                                                              #
#             THIS SHOULD BE THE ONLY FILE YOU NEED TO INTERACT WITH           #
#                                                                              #
# ============================================================================ #


## -------------------------------------------------------------------------- ##
## LOAD PACKAGES
## -------------------------------------------------------------------------- ##

## base packages
library(here)
library(usethis)
library(dplyr)
library(log4r)
library(broom)
library(tictoc)
library(lubridate)

## plot packages
library(DiagrammeR)
##remotes::install_github("nbarrowman/vtree@v5.6.2")
library(vtree)
## install.packages("gt")
library(gt)

## survival
library(survival)

## db connection packages
library(DBI)
library(dbplyr)
library(SqlRender)

## OHDSI/Darwin R Packages
library(omopgenerics)
library(CDMConnector)
library(CohortConstructor)
library(CodelistGenerator)
library(CohortCharacteristics)
library(PatientProfiles)
library(CohortSurvival)

## -------------------------------------------------------------------------- ##
## statistical disclosure count minimum
## -------------------------------------------------------------------------- ##
dis_count_min = 10

## -------------------------------------------------------------------------- ##
## load utility functions
## -------------------------------------------------------------------------- ##
source(here("utils/utils.R"))


## -------------------------------------------------------------------------- ##
## Set DB connection                                                       
## -------------------------------------------------------------------------- ##
source(here("utils/db_connect.R"))


## -------------------------------------------------------------------------- ##
## test cdm connection
## -------------------------------------------------------------------------- ##
cdm$person %>% 
  tally() %>%
  print()


## -------------------------------------------------------------------------- ##
## Set output folder locations 
## the path to a folder where the results from this analysis will be saved
## -------------------------------------------------------------------------- ##
output.dir = here("Results", group.name)
if( !file.exists(output.dir) ){ dir.create(output.dir, recursive=TRUE) }


## -------------------------------------------------------------------------- ##
## Set Figures folder locations 
## the path to a folder where the  from this analysis will be saved
## -------------------------------------------------------------------------- ##
figure.dir = here("Results", group.name, "Figures")
if( !file.exists(figure.dir) ){ dir.create(figure.dir, recursive=TRUE) }


## -------------------------------------------------------------------------- ##
## Create logging object
## -------------------------------------------------------------------------- ##
log_file        = paste0(output.dir, "/log.txt")
logger          = create.logger()
logfile(logger) = log_file
level(logger)   = "INFO"


## -------------------------------------------------------------------------- ##
## create study cohorts 
## -------------------------------------------------------------------------- ##
info(logger, "> CREATE STUDY COHORTS")
source(here("InstantiateCohorts","buildStudyCohorts.R"))
info(logger, "> CREATED STUDY COHORTS")  


## -------------------------------------------------------------------------- ##
## add study covariates
## -------------------------------------------------------------------------- ##
#info(logger, "> ADD STUDY COVARIATES")
#source(here("InstantiateCohorts","addStudyCovariates.R"))
#info(logger, "> ADDED STUDY COVARIATES") 


## -------------------------------------------------------------------------- ##
## run study analysis
## -------------------------------------------------------------------------- ##
#info(logger, "> RUN STUDY ANALYSIS")
#source(here("Analysis","runStudyAnalysis.R"))
#info(logger, "> RAN STUDY ANALYSIS") 

