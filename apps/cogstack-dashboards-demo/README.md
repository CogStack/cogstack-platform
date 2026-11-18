# CogStack Dashboards Demo Scripts

This repository demonstrates figures created by data stored in [CogStackDashboards](https://www.cogstackdashboards.sites.er.kcl.ac.uk).

This repo is intended to be a guide on how to access the dashboards and includes example scripts that can be used to gain clinical insights from the MIMIC-IV dataset. Along with additional capacity for querying annotations via `discharge_annotations` and `radiology_annotations`.
```
├── data/
│   ├── co_occurrences/ - Co-occurrence information for SNOMED CT concepts
│   └── SNOMED/ - Required SNOMED CT Files, See below
├── figures/ - Images used in the paper and generated from scripts
├── sample_access_scripts/ - Simple demo scripts showing how to request data via curl or Python
├── staging_scripts/ - Staging scripts to save data from CogstackDashboards in local files
├── visualisation_scripts/ - Scripts used to generate images used in the paper
└── README.md
```
## Access:

1. Sign up for a [PhysioNet account](https://physionet.org/register/)
2. Complete [training](https://physionet.org/settings/training/) and obtain [credentialed status](https://physionet.org/settings/credentialing/)
3. Log into [CogStackDashboards](https://www.cogstackdashboards.sites.er.kcl.ac.uk) with your PhysioNet account
4. For API access, see sample_access_scripts for examples of how to create appropriate queries

# Prerequisite: SNOMED CT Required Files

SNOMED CT is required for resolving higher-level ancestors of top-level nodes and translating SNOMED codes into human-readable names.

## International SNOMED CT Downloads

https://www.nlm.nih.gov/healthit/snomedct/international.html

## UK SNOMED CT Downloads

https://isd.digital.nhs.uk/trud/users/guest/filters/0/home

After downloading, extract the following two files from the ontology package. They follow this naming convention:

- `sct2_Description_Full-en_INT_YYYYMMDD.txt`
- `sct2_Relationship_Full_INT_YYYYMMDD.txt`

Save them in `data/SNOMED/` as:

- `sct2_description.txt`
- `sct2_relationship.txt`