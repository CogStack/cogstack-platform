# cohorting-tool

This webapp is a cohort identification app for users to obtain the number of patients satifying the search query. Both structured and unstructured data are used. Structured data include age, gender, dod and ethnicity. 
Unstructured data processed using [MedCAT](https://github.com/CogStack/MedCAT) and the MedCAT annotations are used for searching.

The frontend of the app is in the `client` folder. It is adapted from [Windmill Dashboard](https://windmillui.com/dashboard-html) with [tailwindcss](https://tailwindcss.com/) and [alpine.js](https://alpinejs.dev/) for 
interactivity. The runtime dependencies are [ECharts](https://echarts.apache.org/en/index.html) for charts and [popper.js](https://popper.js.org/) for tooltips. The `client` folder can be left untouched for running the app. If you 
want to change the frontend, run `cd client && npm install`. Run `npm run tailwind` in the `client` after adding any tailwindcss classes.

The backend of the app is a [node.js](https://nodejs.org/en/) server using [express.js](https://expressjs.com/) for web/api server and [flexsearch](https://github.com/nextapps-de/flexsearch) for indexing and search for SNOMED 
terms. In order to run the app, the data has to be prepared. First, extract the snomed terms by `cd server/data && tar xzvf snomed_terms_data.tar.gz`, it will extract 2 files, `snomed_terms.json` is an array of SNOMED terms while 
`cui_pt2ch.json` contains the parent-to-child relationships of the SNOMED terms. For patients data, 6 files are needed:
- `ptt2age.json` a dictionary for age of each patient `{<patient_id>:<age>, ...}`
- `ptt2sex.json` a dictionary for gender of each patient `{<patient_id>:<gender>, ...}`
- `ptt2dod.json` a dictionary for dod if the patient has died `{<patient_id>:<dod>, ...}`
- `ptt2eth.json` a dictionary for ethnicity of each patient `{<patient_id>:<ethnicity>, ...}`
- `cui2ptt_pos.json` a dictionary of cui where each cui contains a dictionary of patients with a count `{<cui>: {<patient_id>:<count>, ...}, ...}`
- `cui2ptt_tsp.json` a dictionary of cui where each cui contains a dictionary of patients with a timestamp `{<cui>: {<patient_id>:<tsp>, ...}, ...}`

There is a script `gen_random_data.js` in `server/data/` folder to generate the above 6 files completely randomly so you can still try the app without any data files. Run `cd server/data && node --max-old-space-size=32768 
gen_random_data.js`.

Please make sure to have the 6 data files before starting the server. To start the server, run `cd server && npm run start`. There is also a Dockerfile in the app folder if using docker, run `docker build --tag 
cohortingtool/webapp . && docker run  -p 3000:3000 cohortingtool/webapp`.
