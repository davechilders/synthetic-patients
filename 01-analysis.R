library(tidyverse)
library(fs)
library(arrow)
library(testthat)

dir_ls(glob = "*.parquet") %>% file_info() %>% select(path, size)

cond <- read_parquet("conditions-2026-04-25.parquet")
pat <- read_parquet("patients-2026-04-25.parquet")
enc <- read_parquet("encounters-2026-04-25.parquet")
enc

test_that("validation checks on patient_id", {
  
  expect_equal(
    cond %>% distinct(patient_id) %>% nrow,
    pat %>% distinct(patient_id) %>% nrow
  )
  
  expect_equal(
    cond %>% distinct(patient_id) %>% nrow,
    enc %>% distinct(patient_id) %>% nrow
  )
  
  expect_equal(
    cond %>% anti_join(pat, by = "patient_id") %>% nrow,
    0
  )
  
  expect_equal(
    cond %>% anti_join(enc, by = "patient_id") %>% nrow,
    0
  )

}
)

