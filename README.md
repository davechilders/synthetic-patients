## Sample EHR Pipeline for Clinical Data Transformation

This project is a demo using an end-to-end clinical data pipeline that transform raw EHR data into analysis ready 
data sets for statistical modeling and reporting.

We used [Synthea](https://synthetichealth.github.io/synthea/) to generate realistic health data. See the bottom of this README
for Synthea setup instructions.

### Synthea

```bash
$ git --version
$ java --version
$ git clone https://github.com/synthetichealth/synthea.git
$ ./run_synthea -p 500
$ ls output/fhir/*.json | wc -l
```
