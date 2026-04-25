library(tidyverse)
library(fs)
library(arrow)
library(testthat)
library(viridis)
library(scales)
library(survival)

dir_ls(glob = "*.parquet") %>% file_info() %>% select(path, size)



# load --------------------------------------------------------------------

cond <- read_parquet("conditions-2026-04-25.parquet")
pat <- read_parquet("patients-2026-04-25.parquet")
enc <- read_parquet("encounters-2026-04-25.parquet")
enc


# data validation ---------------------------------------------------------


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


# analyze -----------------------------------------------------------------

pat <- pat %>% arrange(patient_id) %>% mutate(pid = row_number()) %>%
  select(pid, everything()) %>%
  select(-patient_id)

cond <- cond %>% 
  arrange(patient_id) %>%
  mutate(pid = dense_rank(patient_id)) %>%
  select(pid, everything()) %>%
  select(-patient_id)

enc <- enc %>%
  arrange(patient_id) %>%
  mutate(pid = dense_rank(patient_id)) %>%
  select(pid, everything()) %>%
  select(-patient_id)

pat
cond
enc

pat

cond_lung <- cond %>%
  semi_join(
    cond %>% filter(str_detect(tolower(condition_text), "lung cancer")),
    by = "pid"
  ) %>%
  print

cond_lung %>%
  filter(str_detect(tolower(condition_text), "cancer")) %>%
  split(.$pid) %>%
  knitr::kable()

cond_lung2 <- cond_lung %>%
  mutate(
    lung_cancer = str_detect(tolower(condition_text), "lung cancer")
  ) %>%
  group_by(pid) %>%
  mutate(is_last = row_number() == n()) %>%
  ungroup() %>%
  filter(lung_cancer | is_last)

cond_lung2 %>%
  filter(pid == 19)

cond %>% filter(pid == 19, str_detect(tolower(condition_text), "cancer"))
cond %>% filter(pid == 19) %>% knitr::kable()

cond_lung2 %>%
  mutate(
    days_since_suspect = ifelse(condition_text == "Suspected lung cancer (situation)", 0, NA)
  ) %>%
  group_by(pid) %>%
  mutate(days_since_suspect = as.integer(onset_date - min(onset_date))) %>%
  ungroup() %>%
  View

cond_lung_patient <- cond_lung2 %>%
  group_by(pid) %>%
  filter(any(condition_text == "Non-small cell lung cancer (disorder)")) %>%
  summarise(
    lung_cancer_onset = onset_date[condition_text == "Non-small cell lung cancer (disorder)"],
    last_onset_date = onset_date[is_last],
    last_cond_death = as.integer(str_detect(tolower(condition_text[is_last]), "died"))
  ) %>%
  mutate(cancer_last_days = as.integer(last_onset_date - lung_cancer_onset)) %>%
  print

enc %>% filter(pid == 214) %>% tail(5)

surv_df <- cond_lung_patient %>%
  left_join(
    enc %>%
      filter(encounter_type == "Death Certification") %>%
      select(pid, death_date = encounter_start),
    by = "pid"
  ) %>%
  select(-last_cond_death, -cancer_last_days) %>%
  mutate(
    death_outcome = ifelse(is.na(death_date), 0L, 1L),
    last_date = case_when(
      !is.na(death_date) ~ death_date, 
      TRUE ~ as.Date("2026-04-24")
      ),
    cancer_outcome_days = as.integer(last_date - lung_cancer_onset)
    )

ggplot(surv_df, aes(y = reorder(pid, cancer_outcome_days), x = cancer_outcome_days)) +
  geom_point(aes(color = factor(death_outcome))) +
  theme_bw() +
  expand_limits(x = 0) +
  scale_color_manual(values = c("0" = "forestgreen", "1" = "red")) +
  labs(
    title = "Survival from lung cancer diagnosis",
    x = "Days Since Diagnosis",
    y = "Patient ID",
    color = "Death"
  ) +
  scale_x_continuous(breaks = pretty_breaks(10))


# make a survival analysis
surv_df <- surv_df %>%
  mutate(
    surv_obj = Surv(time = cancer_outcome_days, event = death_outcome)
  )

km_fit <- survfit(surv_obj ~ 1, data = surv_df)
km_fit

plot(km_fit, xlab = "Days", ylab = "Survival Probability", col = "blue", lwd = 2)

coxph_fit <- coxph(surv_obj ~ 1, data = surv_df)
summary(coxph_fit)
coef(coxph_fit)
