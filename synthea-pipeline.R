library(tidyverse)
library(fs)
library(jsonlite)
library(purrr)
library(arrow)
help(package = "jsonlite")

dir_ls("synthea/output/fhir") %>%
  file_info() %>%
  select(path)

# terminal commands
# s output/fhir | wc   
# grep -l '"resourceType"[[:space:]]*:[[:space:]]*"Patient"' output/fhir/*.json | wc -l

files <- dir_ls(
  "synthea/output/fhir",
  glob = "*.json"
)

# method 2: extract all resources -----------------------------------------

extract_resources <- function(file) {
  bundle <- fromJSON(file, simplifyVector = FALSE)
  entries <- bundle$entry
  
  patients <- list()
  conditions <- list()
  encounters <- list()
  
  for (e in entries) {
    resource <- e$resource
    rtype <- resource$resourceType
    
    if (rtype == "Patient") {
      patients <- append(patients, list(resource))
      
    } else if (rtype == "Condition") {
      conditions <- append(conditions, list(resource))
      
    } else if (rtype == "Encounter") {
      encounters <- append(encounters, list(resource))
    }
  }
  
  list(
    patients = patients,
    conditions = conditions,
    encounters = encounters
  )
}

patients_df <- map_dfr(files, function(file) {
  res <- extract_resources(file)
  
  map_dfr(res$patients, function(p) {
    tibble(
      patient_id = p$id,
      gender = p$gender,
      birthDate = p$birthDate,
      
      first_name = p$name[[1]]$given[[1]],
      last_name = p$name[[1]]$family,
      
      city = p$address[[1]]$city,
      state = p$address[[1]]$state
    )
  })
})

conditions_df <- map_dfr(files, function(file) {
  res <- extract_resources(file)
  
  map_dfr(res$conditions, function(c) {
    tibble(
      patient_id = str_remove(c$subject$reference, "Patient/"),
      
      condition_text = c$code$text,
      condition_code = c$code$coding[[1]]$code,
      
      onset_date = c$onsetDateTime,
      clinical_status = c$clinicalStatus$coding[[1]]$code
    )
  })
})

encounters_df <- map_dfr(files, function(file) {
  res <- extract_resources(file)
  
  map_dfr(res$encounters, function(e) {
    tibble(
      patient_id = str_remove(e$subject$reference, "Patient/"),
      
      encounter_start = e$period$start,
      encounter_end = e$period$end,
      
      encounter_type = e$type[[1]]$text,
      reason = e$reasonCode[[1]]$text
    )
  })
})

conditions_df <- conditions_df %>%
  mutate(patient_id = str_remove_all(patient_id, "urn:uuid:"))

conditions_df %>% distinct(patient_id) %>% nrow
patients_df %>% nrow

encounters_df <- encounters_df %>%
  mutate(patient_id = str_remove_all(patient_id, "urn:uuid:"))

encounters_df %>% distinct(patient_id) %>% nrow
encounters_df %>% inner_join(patients_df, by = "patient_id") %>% distinct(patient_id) %>% nrow
conditions_df %>% inner_join(patients_df, by = "patient_id") %>% distinct(patient_id) %>% nrow

write_parquet(
  patients_df,
  glue::glue("patients-{Sys.Date()}.parquet")
)

write_parquet(
  encounters_df,
  glue::glue("encounters-{Sys.Date()}.parquet")
)

write_parquet(
  conditions_df,
  glue::glue("conditions-{Sys.Date()}.parquet")
)
