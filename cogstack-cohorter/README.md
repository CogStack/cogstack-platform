# RetCAT - A MedCAT annotations retrieval tool for cohort identification

This webapp is a cohort identification app for users to obtain the number of patients satifying the search query. Both structured and unstructured data are used. Structured data include age, gender, dod and ethnicity. Unstructured (text) data are processed using [MedCAT](https://github.com/CogStack/MedCAT) and the MedCAT annotations are used for searching.

The frontend of the app is in the `client` folder. It is adapted from [Windmill Dashboard](https://windmillui.com/dashboard-html) with [tailwindcss](https://tailwindcss.com/) for styling and [alpine.js](https://alpinejs.dev/) for interactivity. The other runtime dependencies are [ECharts](https://echarts.apache.org/en/index.html) for charts and [popper.js](https://popper.js.org/) for tooltips. The `client` folder can be left untouched for running the app. If you want to change the frontend, in the app folder run `cd client && npm install`. Run `npm run tailwind` in the `client` folder after adding any tailwindcss classes.

The backend of the app is in the `server` folder which is a [node.js](https://nodejs.org/en/) application (v14 or higher) using [express.js](https://expressjs.com/) for the web/api server and [flexsearch](https://github.com/nextapps-de/flexsearch) for indexing and searching SNOMED terms. In order to run the app, the required data has to be prepared. First, extract the snomed terms by running `cd server/data && tar xzvf snomed_terms_data.tar.gz` from the app folder, it will extract 2 files, `snomed_terms.json` is an array of SNOMED terms while  `cui_pt2ch.json` contains the parent-to-child relationships of the SNOMED terms. For patients data, 6 files are needed in the `server/data/` folder:
- `ptt2age.json` a dictionary for age of each patient `{<patient_id>:<age>, ...}`
- `ptt2sex.json` a dictionary for gender of each patient `{<patient_id>:<gender>, ...}`
- `ptt2dod.json` a dictionary for dod if the patient has died `{<patient_id>:<dod>, ...}`
- `ptt2eth.json` a dictionary for ethnicity of each patient `{<patient_id>:<ethnicity>, ...}`
- `cui2ptt_pos.jsonl` each line is a dictionary of cui and the value is a dictionary of patients with a count `{<cui>: {<patient_id>:<count>, ...}}\n...`
- `cui2ptt_tsp.jsonl` each line is a dictionary of cui and the value is a dictionary of patients with a timestamp `{<cui>: {<patient_id>:<tsp>, ...}}\n...`

There is a script `gen_random_data.js` in `server/data/` folder to generate the above 6 files completely randomly so you can still try the app without any real data. In the app folder run `cd server/data && node --max-old-space-size=32768  gen_random_data.js`.

Please make sure to have the 6 data files ready in the `server/data/` folder before starting the server. To start the server, in the app folder run `cd server && npm install && npm run start`. There is also a Dockerfile in the app folder if using docker, to build and run the container, run `docker build --tag cohortingtool/webapp . && docker run  -p 3000:3000 cohortingtool/webapp`.

The following code snippet can be used to generate the 4 data (json) files if you have access to [Cogstack](https://github.com/CogStack).
```python
from datetime import datetime
from medcat.utils.ethnicity_map import ethnicity_map

# function to convert a dictionary to json and write to file (d: dictionary, fn: string (filename))
def dict2json_file(d, fn)
    # convert pickle object to json object
    json_obj = json.loads(json.dumps(d))

    # write the json file
    with open(fn, 'w', encoding='utf-8') as outfile:
        json.dump(json_obj, outfile, ensure_ascii=False, indent=None, separators=(',',':'))

today = datetime.now().timestamp()
ethnicity_map = {k.lower():v for k,v in ethnicity_map.items()}

ptt2sex = {}
ptt2eth = {}
ptt2dob = {}
ptt2age = {}
ptt2dod = {}

# info_df is a pandas DataFrame containing the fields: client_idcode, client_gendercode, client_racecode, client_dob, client_deceaseddtm

for pair in info_df[['client_idcode', 'client_gendercode']].values.tolist():
    if pair[0] not in ptt2sex and pair[1]:
        ptt2sex[pair[0]] = pair[1]

for pair in info_df[['client_idcode', 'client_racecode']].values.tolist():
    if pair[0] not in ptt2eth and pair[1] and pair[0] and str(pair[1]).lower() in ethnicity_map:
        ptt2eth[pair[0]] = ethnicity_map[str(pair[1]).lower()]

info_df.client_dob = pd.to_datetime(info_df.client_dob, format="%Y-%m-%dT%H:%M:%S.%f%z", utc=True)
info_df.client_deceaseddtm = pd.to_datetime(info_df.client_deceaseddtm, format="%Y-%m-%dT%H:%M:%S.%f%z", utc=True)

for id, dob, dod in info_df[['client_idcode', 'client_dob', 'client_deceaseddtm']].values:
    if id not in ptt2dob and not pd.isna(dob):
        ptt2dob[id] = dob.timestamp()
        age = (today - dob.timestamp()) // (60 * 60 * 24 * 365)
        ptt2age[id] = age
    if not pd.isna(dod):
        ptt2dod[id] = dod.timestamp()

dict2json_file(ptt2sex, 'ptt2sex.json')
dict2json_file(ptt2eth, 'ptt2eth.json')
dict2json_file(ptt2age, 'ptt2age.json')
dict2json_file(ptt2dod, 'ptt2dod.json')
```

With MedCAT annotation output (e.g., part_0.pickle), `cui2ptt_pos.jsonl` and `cui2ptt_tsp.jsonl` can be generated with python script similar to below.

```python
import pandas as pd
from collections import defaultdict, Counter

cui2ptt_pos = defaultdict(Counter) # store the count of a SNOMED term for a patient
cui2ptt_tsp = defaultdict(lambda: defaultdict(int)) # store the first mention timestamp of a SNOMED term for a pateint

# doc2ptt is a dictionary {<doc_id> : <patient_id>, ...}

# for each part of the MedCAT output (e.g., part_0.pickle)
for part in range(parts):
    annotations = pd.read_pickle(f'part_{part}.pickle')
    for docid in annotations:
        docid = int(docid)
        if docid not in doc2ptt:
            continue
        ptt = doc2ptt[docid]
        for _, ent in annotations[str(docid)]['entities'].items():
            'if ent['meta_anns']['Subject']['value'] == 'Patient' and ent['meta_anns']['Presence']['value'] == 'True' and ent['meta_anns']['Time']['value'] != 'Future':'
                cui = ent['cui']
                cui2ptt_pos[cui][ptt] += 1
                if 'document_timestamp' in ent:
                    time = ent['document_timestamp']
                    if cui2ptt_tsp[cui][ptt] == 0 or time < cui2ptt_tsp[cui][ptt]:
                        cui2ptt_tsp[cui][ptt] = time

with open('cui2ptt_pos.jsonl', 'a', encoding='utf-8') as outfile:
    for k,v in cui2ptt_pos.items():
        o = {k: v}
        json_obj = json.loads(json.dumps(o))
        json.dump(json_obj, outfile, ensure_ascii=False, indent=None, separators=(',',':'))
        print('', file = outfile)

with open('cui2ptt_tsp.jsonl', 'a', encoding='utf-8') as outfile:
    for k,v in cui2ptt_tsp.items():
        o = {k: v}
        json_obj = json.loads(json.dumps(o))
        json.dump(json_obj, outfile, ensure_ascii=False, indent=None, separators=(',',':'))
        print('', file = outfile)

```
