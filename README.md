## Sample EHR Pipeline for Clinical Data Transformation

Clinical data rarely arrives in clean, analysis-ready format. It must be:

- extracted from multiple sources (e.g. EHR)
- validated for quality, consistency, and completeness
- transformed into a structured data set for analysis

This project is a demo using an end-to-end clinical data pipeline that transform raw EHR data into analysis ready 
data sets for statistical modeling and reporting.

This project uses [Synthea](https://synthetichealth.github.io/synthea/) to generate synthetic 
data on patients, conditions, and encounters.

See the bottom of this README for Synthea setup and data generation instructions.

This [script](https://github.com/davechilders/synthetic-patients/blob/main/synthea-pipeline.R) processes the synthetic JSON data into 
parquet files for patients, conditions, and encounters.

This Quarto [report](https://davechilders.github.io/synthetic-patients/) constructs a patient-level dataset on lung cancer patients and applies survival analysis to estimate
time from diagnosis to death

### Synthea Setup

```bash
$ git --version # confirm git installation
$ java --version # confirm java installation
$ git clone https://github.com/synthetichealth/synthea.git # clone synthea to local machine
$ ./run_synthea -p 500 # generate JSON records for 500 patients
$ ls output/fhir/*.json | wc -l
```
