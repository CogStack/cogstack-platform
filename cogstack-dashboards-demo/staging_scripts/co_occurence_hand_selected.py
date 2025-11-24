# Graph of which diagnoses tend to occur together (e.g., diabetes + renal disease).
from opensearchpy import OpenSearch
from collections import defaultdict
from scipy.sparse import dok_matrix
from tqdm import tqdm 
import pandas as pd
import numpy as np
import itertools

serious_disorders = [
    44054006,   # Type 2 Diabetes Mellitus
    42343007,   # Congestive Heart Failure
    13645005,   # COPD
    233604007,  # Pneumonia
    91302008,   # Sepsis
    22298006,   # Acute Myocardial Infarction
    38341003,   # High BP
    19943007,   # Liver Cirrhosis
    230690007,  # Stroke
    254637007   # Lung Cancer
]
common_symptoms = [
    22253000,   # Pain
    422587007,  # Nausea
    422400008,  # Vomiting
    386661006,  # Fever
    84229001,   # Fatigue
    25064002,   # Headache
    267036007,  # Dyspnea (shortness of breath)
    49727002,   # Cough
    267038008,  # Edema
    404640003   # Dizziness
]
common_procedures = [
    116859006, # Transfusion
    415070008,  # Percutaneous coronary intervention
    232717009,  # Coronary Artery Bypass Graft
    302497006,  # Hemodialysis
    399208008,  # Plain chest X-ray
    40701008,   # Echocardiography (procedure) 
    265764009,  # Renal dialysis (procedure) 
    18027006,   # Transplant liver
    45211000, #  Catheterization
    10847001,   # Bronchoscopy
]
common_substances = [
    67866001,  # Insulin
    387475002,  # Furosemide
    372567009,  # Metformin
    372877000,  # Heparin
    372756006,  # Warfarin
    387458008,  # Aspirin
    373529000,  # Morphine
    372735009,  # Vancomycin
    372670001,  # Ceftriaxone
    24099007   # Oxygen
]

# Initialising the connection
client = OpenSearch(
    hosts=[{
        "host": "cogstackdashboards.sites.er.kcl.ac.uk",
        "port": 443,
        "url_prefix": "auth/api/proxy"   # this is required
    }],
    use_ssl=True,
    verify_certs=True,
    headers={"Username": "<PhysioNet Username>"}   # Enter your username here
)

# comment and uncomment as required - collate by patient or by note
# co_occurence = "meta.note_id"
co_occurence = "meta.subject_id"
# index_name = "radiology_annotations"
index_name = "discharge_annotations"

# choose save path
# multiple files will be saved with different suffixes
# it's better to contain them in their own folder
save_path = "../data/hand_selected_co_occurences"

# co occurence between these selected cuis
selected_cuis = [str(c) for c in serious_disorders + common_symptoms + common_procedures + common_substances]

# Build mapping for selected CUIs
cui_to_idx = {cui: i for i, cui in enumerate(selected_cuis)}
N = len(cui_to_idx)

# scrolling query
scroll_size = 10000  # tune as needed
query = {
    "_source": ["meta.note_id", "meta.subject_id", "nlp.cui"],
    "size": scroll_size,
    "query": {
        "bool": {
            "filter": [
                {
                    "terms": {
                        "nlp.cui.keyword": selected_cuis
                    }
                }
            ]
        }
    }
}

resp = client.search(index=index_name, body=query, scroll="5m")
scroll_id = resp["_scroll_id"]

total_hits = resp["hits"]["total"]["value"]
print(f"Found {total_hits} hits for selected CUIs")

# Sparse matrix 
co_matrix = dok_matrix((N, N), dtype=np.int32)

note_to_cuis = defaultdict(set)
processed = 0

with tqdm(total=total_hits, desc="Processing documents") as pbar:
    while True:
        hits = resp["hits"]["hits"]
        if not hits:
            break

        for doc in hits:
            src = doc["_source"]
            note_id = src[co_occurence]
            cui = src["nlp.cui"]

            if cui in cui_to_idx:
                note_to_cuis[note_id].add(cui)

        # Update co-occurrence matrix
        for note_id, cuis_in_note in note_to_cuis.items():
            if len(cuis_in_note) > 1:
                for c1, c2 in itertools.combinations(sorted(cuis_in_note), 2):
                    i, j = cui_to_idx[c1], cui_to_idx[c2]
                    co_matrix[i, j] += 1
                    co_matrix[j, i] += 1
        note_to_cuis.clear()

        processed += len(hits)
        pbar.update(len(hits))

        resp = client.scroll(scroll_id=scroll_id, scroll="5m")

# Convert to DataFrame
csr = co_matrix.tocsr()

rows, cols = csr.nonzero()
values = csr[rows, cols]
df = pd.DataFrame({
    "cui_x": [selected_cuis[i] for i in rows],
    "cui_y": [selected_cuis[j] for j in cols],
    "count": values.A1
})

# Save parquet and sparse matrix
df.to_parquet(save_path + ".parquet")
print("Saved:", save_path + ".parquet")