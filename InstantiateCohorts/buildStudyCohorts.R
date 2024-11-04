## -------------------------------------------------------------------------- ##
## Set study options
## -------------------------------------------------------------------------- ##
filter_prior_cancers  = FALSE
plot_cohort_attrition = TRUE
save_cohort_summary   = TRUE


## -------------------------------------------------------------------------- ##
## Set study requirements
## Dates must be in format YYYY-MM-DD ie. 20XX-01-01
## -------------------------------------------------------------------------- ##
startDate = as.Date("2013-06-30")
endDate   = as.Date("2021-03-31")
ageRange  = list(c(18, 150))
#sex       = c("Female","Male")


print("> load cancer cohort")
  
log4r::info(logger, "> getting concept sets from cohort")


## -------------------------------------------------------------------------- ##
## Reset, drop cohort tables
## -------------------------------------------------------------------------- ##
cdm = CDMConnector::dropTable(cdm, name="outcome")
cdm = CDMConnector::dropTable(cdm, name="cancer")


## -------------------------------------------------------------------------- ##
## get eBrC code list to build our cohort
## -------------------------------------------------------------------------- ##
ebrc_concepts = CodelistGenerator::codesFromCohort(
                       path = here("InstantiateCohorts", "Cohorts"), cdm = cdm)


logr4::info(logger, "> create ebrc cohort")


## -------------------------------------------------------------------------- ##
## Generate concept-based cohorts for eBrC code-list in table 'outcome' 
## -------------------------------------------------------------------------- ##
cdm$outcome = cdm %>%
              CohortConstructor::conceptCohort(
                   conceptSet = ebrc_concepts,
                   name       = "outcome")


if( filter_prior_cancers ){


## -------------------------------------------------------------------------- ##
## get code-list containing concepts for any malignant neoplastic disease. 
## We can then exclude patients from our cohort who have had prior history 
## before their cancer diagnosis.
## -------------------------------------------------------------------------- ##
cancer_concepts = CodelistGenerator::codesFromConceptSet(here::here("InstantiateCohorts", "Exclusion"), cdm)
  
  
## -------------------------------------------------------------------------- ##
## combine code-list together
## -------------------------------------------------------------------------- ##
cancer_codes = omopgenerics::newCodelist(
  list("ebrc"          = ebrc_concepts[[1]],
       "anymalignancy" = cancer_concepts[[1]]))


## -------------------------------------------------------------------------- ##
## Generate concept-based cohorts for any malignancy code-list in table 'cancer' 
## -------------------------------------------------------------------------- ##
cdm$cancer = cdm %>%
  CohortConstructor::conceptCohort(
    conceptSet = cancer_codes,
    name       = "cancer") 



## -------------------------------------------------------------------------- ##
## combine cohorts together
## -------------------------------------------------------------------------- ##
cdm$cancer = CohortConstructor::unionCohorts(
    cdm$cancer,
    cohortName = "any_malignancy",
    name       = "cancer")



## -------------------------------------------------------------------------- ##
## add flag if patients in our eBrC cohort have any malignancy prior to diagnosis date 
## -------------------------------------------------------------------------- ##
cdm$outcome = cdm$outcome %>% 
              PatientProfiles::addCohortIntersectFlag(
              targetCohortTable = "cancer",
              targetStartDate   = "cohort_start_date",
              targetEndDate     = "cohort_end_date", 
              window            = c(-Inf,-1L),
              nameStyle         = "{cohort_name}")


## -------------------------------------------------------------------------- ##
## filter patients in our eBrC cohort for any malignancy prior to diagnosis date 
## -------------------------------------------------------------------------- ##
#cdm$outcome = cdm$outcome %>% 
#              CohortConstructor::requireCohortIntersect(
#                targetCohortTable = "cancer",
#                intersections     = 0,
#                indexDate         = "cohort_start_date", 
#                window            = c(-Inf,-1L))
              

CohortConstructor::attrition(cdm$outcome) %>% 
  filter(reason == "No malignancy between -Inf & -1 days before cohort_start_date")


log4r::info(logger, "INSTANTIATED EXCLUSION ANY MALIGNANT NEOPLASTIC DISEASE (EX SKIN CANCER)")


}


## -------------------------------------------------------------------------- ##
## apply study requirements to build study cohort
## -------------------------------------------------------------------------- ##
cdm$outcome = cdm$outcome %>%
              ## include only first record per person
              CohortConstructor::requireIsFirstEntry() %>%
              ##record_cohort_attrition("include only first record per person") %>%
              CohortConstructor::requireDemographics(
              ## restrict cohort entries to age range greater than 18 years
              ageRange   = ageRange#,
              ## restrict cohort entries to male & female
              ##sex = sex %>%
              ) %>%
              ## change cohort_end_date to end date of observation period
              CohortConstructor::exitAtObservationEnd() %>%
              ## restrict cohort_start_date to those that start or end within a certain time period.
              CohortConstructor::requireInDateRange(
                indexDate = "cohort_start_date",
                dateRange = c(startDate, endDate)) %>%
              ## add date_of_death to cohort
              PatientProfiles::addDeathDate() %>% 
              ## add study_end_date as censor date, ie endDate, or cohort_end_date
              dplyr::mutate(study_end_date = ifelse(cohort_end_date > endDate, endDate, cohort_end_date)) %>%
              dplyr::mutate(status     = ifelse(date_of_death > endDate | date_of_death > study_end_date,
                                                NA,
                                               date_of_death)) %>%
              dplyr::mutate(status     = ifelse(is.na(status), 1, 2)) %>%
              dplyr::mutate(time_days  = !!CDMConnector::datediff("cohort_start_date","study_end_date", interval="day")) %>%
              dplyr::mutate(time_years = time_days / 365.25)
  


## -------------------------------------------------------------------------- ##
## summarise attrition associated with cohort
## -------------------------------------------------------------------------- ##
summary_attrition = cdm$outcome %>%
                    CohortCharacteristics::summariseCohortAttrition() %>%
                    CohortCharacteristics::suppress(., minCellCount = dis_count_min)


## -------------------------------------------------------------------------- ##
## save cohort attrition table (.csv)
## -------------------------------------------------------------------------- ##
                    summary_attrition %>%
                    CohortCharacteristics::tableCohortAttrition(., type = "tibble") %>%
                    readr::write_csv(., paste0(here(output.dir),"/", group.name, "_cohort_attrition_table.csv"))

                                           
## -------------------------------------------------------------------------- ##
## save cohort attrition table (.png)
## -------------------------------------------------------------------------- ##                    
                    summary_attrition %>%
                    CohortCharacteristics::tableCohortAttrition(., type = "gt") %>%
                    gt::gtsave(., 
                               path     = here("Results", group.name, "Figures"),
                               filename = "cohort_attrition_table.png") 


## -------------------------------------------------------------------------- ##
## plot attrition associated with cohort
## -------------------------------------------------------------------------- ##
if( plot_cohort_attrition ){
  
  summary_attrition %>%
  CohortCharacteristics::plotCohortAttrition() %>%
  vtree::grVizToPNG(., 
                    width    = 400, 
                    height   = 800, 
                    folder   = here("Results", group.name, "Figures"), 
                    filename = "cohort_attrition_graph.png")

  }



## -------------------------------------------------------------------------- ##
## Generate summary statistics on this cohort
## -------------------------------------------------------------------------- ##
cohort_count = cdm$outcome %>%
               CohortCharacteristics::summariseCohortCount() %>%
               CohortCharacteristics::suppress(., minCellCount = dis_count_min)



## -------------------------------------------------------------------------- ##
## save cohort attrition table (.csv)
## -------------------------------------------------------------------------- ##
cohort_count %>%
  CohortCharacteristics::tableCohortCount(., type = "tibble") %>%
  readr::write_csv(., paste0(here(output.dir),"/", group.name, "_cohort_count_table.csv"))



## -------------------------------------------------------------------------- ##
## save cohort attrition table (.png)
## -------------------------------------------------------------------------- ##                    
cohort_count %>%
  CohortCharacteristics::tableCohortAttrition(., type = "gt") %>%
  gt::gtsave(., 
             path     = here("Results", group.name, "Figures"),
             filename = "cohort_count_table.png") 



## -------------------------------------------------------------------------- ##
## Generate summary characteristics on this cohort
## -------------------------------------------------------------------------- ##
cohort_characteristics = cdm$outcome %>%
                         CohortCharacteristics::summariseCharacteristics() %>%
                         CohortCharacteristics::suppress(., minCellCount = dis_count_min)


## -------------------------------------------------------------------------- ##
## save cohort characteristics table (.csv)
## -------------------------------------------------------------------------- ##
cohort_characteristics %>%
  CohortCharacteristics::tableCharacteristics(., type = "tibble") %>%
  readr::write_csv(., paste0(here(output.dir),"/", group.name, "_cohort_characteristics_table.csv"))


## -------------------------------------------------------------------------- ##
## save cohort characteristics table (.png)
## -------------------------------------------------------------------------- ##                    
cohort_characteristics %>%
  CohortCharacteristics::tableCharacteristics(., type = "gt") %>%
  gt::gtsave(., 
             path     = here("Results", group.name, "Figures"),
             filename = "cohort_characteristics_table.png") 



log4r::info(logger, "> create ebrc cohort")
