## Sample EHR Pipeline for Clinical Data Transformation

Clinical data rarely arrives in clean, analysis-ready format. It must be:

- extracted from multiple sources (e.g. EHR)
- validated for quality, consistency, and completeness
- transformed into a structured data set for analysis

This project is a demo using an end-to-end clinical data pipeline that transform raw EHR data into analysis ready 
data sets for statistical modeling and reporting.

This project synthesis [Synthea](https://synthetichealth.github.io/synthea/) to generate synthetic 
data on patients, conditions, and encounters.

See the bottom of this README for Synthea setup and data generation instructions.

This [script](https://github.com/davechilders/synthetic-patients/blob/main/01-analysis.R) processes the synthetic JSON data into 
parquet files for patients, conditions, and encounters.

This Quarto [report](https://github.com/davechilders/synthetic-patients/blob/main/01-analysis.R) joins the data sources and presents a
(very simplified) survival analysis for lung cancer patients.

### Synthea

```bash
$ git --version
$ java --version
$ git clone https://github.com/synthetichealth/synthea.git
$ ./run_synthea -p 500
$ ls output/fhir/*.json | wc -l
```
