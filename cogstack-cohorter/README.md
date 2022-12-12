# MedCAT annotations retriever for cohort identification

This webapp is a cohort identification app for users to obtain the number of patients satifying the search query. Both structured and unstructured data are used. Structured data include age, gender, dod and ethnicity. 
Unstructured data processed using [MedCAT](https://github.com/CogStack/MedCAT) and the MedCAT annotations are used for searching.

The frontend of the app is in the `client` folder. It is adapted from [Windmill Dashboard](https://windmillui.com/dashboard-html) with [tailwindcss](https://tailwindcss.com/) for styling and [alpine.js](https://alpinejs.dev/) for 
interactivity. The other runtime dependencies are [ECharts](https://echarts.apache.org/en/index.html) for charts and [popper.js](https://popper.js.org/) for tooltips. The `client` folder can be left untouched for running the app. If you 
want to change the frontend, in the app folder run `cd client && npm install`. Run `npm run tailwind` in the `client` folder after adding any tailwindcss classes.

The backend of the app is in the `server` folder which is a [node.js](https://nodejs.org/en/) application using [express.js](https://expressjs.com/) for web/api server and [flexsearch](https://github.com/nextapps-de/flexsearch) for indexing and searching SNOMED terms. In order to run the app, the data has to be prepared. First, extract the snomed terms by running `cd server/data && tar xzvf snomed_terms_data.tar.gz` from the app folder, it will extract 2 files, `snomed_terms.json` is an array of SNOMED terms while  `cui_pt2ch.json` contains the parent-to-child relationships of the SNOMED terms. For patients data, 6 files are needed:
- `ptt2age.json` a dictionary for age of each patient `{<patient_id>:<age>, ...}`
- `ptt2sex.json` a dictionary for gender of each patient `{<patient_id>:<gender>, ...}`
- `ptt2dod.json` a dictionary for dod if the patient has died `{<patient_id>:<dod>, ...}`
- `ptt2eth.json` a dictionary for ethnicity of each patient `{<patient_id>:<ethnicity>, ...}`
- `cui2ptt_pos.jsonl` each line is a dictionary of cui and the value is a dictionary of patients with a count `{<cui>: {<patient_id>:<count>, ...}}\n...`
- `cui2ptt_tsp.jsonl` each line is a dictionary of cui and the value is a dictionary of patients with a timestamp `{<cui>: {<patient_id>:<tsp>, ...}}\n...`

There is a script `gen_random_data.js` in `server/data/` folder to generate the above 6 files completely randomly so you can still try the app without any real data. In the app folder run `cd server/data && node --max-old-space-size=32768  gen_random_data.js`.

Please make sure to have the 6 data files ready before starting the server. To start the server, in the app folder run `cd server && npm install && npm run start`. There is also a Dockerfile in the app folder if using docker, run `docker build --tag cohortingtool/webapp . && docker run  -p 3000:3000 cohortingtool/webapp`.

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