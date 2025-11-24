import json
from opensearchpy import OpenSearch
from collections import defaultdict
from tqdm import tqdm

load_paths = ["../data/cui_to_subjects_discharge.json"]
save_path = "../data/cui_to_age.json"

cui_to_subject = defaultdict(list)

for path in load_paths:
    with open(path, "r") as f:
        data = json.load(f)
        for key, value in data.items():
            cui_to_subject[int(key)].extend(value)  # Ensure lists are merged

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

cui_to_age = {}
for cui in tqdm(cui_to_subject, desc="Processing per CUI"):
    # Define the query
    query = {
        "size": 0,  # We don't need document hits, only aggregations
        "query": {
            "terms": {
                "subject_id": cui_to_subject[cui]  # Filter patients by subject_id
            }
        },
        "aggs": {
            "age_counts": {
                "terms": {
                    "field": "anchor_age",  # Aggregate gender counts
                    "size": 75  # Should
                }
            }
        }
    }
    
    response = client.search(
        body = query,
        index = "patients"
    ) 
    cui_to_age[cui] = {"all": len(cui_to_subject[cui])}
    for bucket in response["aggregations"]["age_counts"]["buckets"]:
        cui_to_age[cui][int(bucket["key"])] = bucket["doc_count"]

with open(save_path, "w") as fp:
    json.dump(cui_to_age, fp)