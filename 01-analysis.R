library(tidyverse)
library(fs)
library(arrow)
library(testthat)
library(scales)
library(survival)
library(lubridate)
library(gt)
library(survminer)

# check files -------------------------------------------------------------


dir_ls(glob = "*.parquet") %>% file_info() %>% select(path, size)

# load --------------------------------------------------------------------

cond <- read_parquet("conditions-2026-04-25.parquet")
pat <- read_parquet("patients-2026-04-25.parquet")
enc <- read_parquet("encounters-2026-04-25.parquet")

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


# create data set for lung cancer patients -----------------------------------------------------------------

# shorter patient IDs
pat <- pat %>% arrange(patient_id) %>% mutate(pid = row_number()) %>%
  select(pid, everything()) %>%
  select(-patient_id) %>%
  mutate(birthDate = as.Date(birthDate))

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

cond_lung <- cond %>%
  semi_join(
    cond %>% filter(str_detect(tolower(condition_text), "lung cancer")),
    by = "pid"
  ) 

# cond_lung %>%
#   filter(str_detect(tolower(condition_text), "cancer")) %>%
#   split(.$pid) %>%
#   knitr::kable()

cond_lung2 <- cond_lung %>%
  mutate(
    lung_cancer = str_detect(tolower(condition_text), "lung cancer")
  ) %>%
  group_by(pid) %>%
  mutate(is_last = row_number() == n()) %>%
  ungroup() %>%
  filter(lung_cancer | is_last)

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

surv_df0 <- cond_lung_patient %>%
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
    ) %>% print

surv_df <- surv_df0 %>%
  left_join(pat %>% select(pid, birthDate, gender), by = "pid") %>%
  mutate(
    surv_obj = Surv(time = cancer_outcome_days, event = death_outcome),
    onset_age = time_length(interval(birthDate, lung_cancer_onset), "year")
  )

# view survival outcomes 
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

# kaplan meier curve
km_fit <- survfit(surv_obj ~ 1, data = surv_df)

plot(km_fit, xlab = "Days", ylab = "Survival Probability", col = "blue", lwd = 2)

ggsurvplot(km_fit, data = surv_df, conf.int = TRUE, risk.table = TRUE)

# age is only covariates
coxph_fit <- coxph(surv_obj ~ onset_age, data = surv_df)
coxph_output <- broom::tidy(coxph_fit, conf.int = TRUE, exponentiate = TRUE)

gt(coxph_output %>% 
     select(term, estimate, conf.low, conf.high, p.value)
   ) %>%
  tab_header(
    "Time to Death following Lunch Cancer Diagnosis",
    subtitle = "Cox Proportional Hazards Model"
  ) %>%
  fmt_number(columns = estimate:p.value) %>%
  cols_label(
    term = "Covariate",
    estimate = "Haz Ratio",
    conf.low = "Lower 95% CI",
    conf.high = "Upper 95% CI"
  )
