import json
from tqdm import tqdm
from opensearchpy import OpenSearch
from collections import defaultdict

load_paths = ["../data/cui_to_subjects_discharge.json"]
save_path = "../data/cui_to_gender.json"

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

cui_to_gender = {}
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
            "gender_counts": {
                "terms": {
                    "field": "gender.keyword",  # Aggregate gender counts
                    "size": 10  # Should be enough for "M" and "F"
                }
            }
        }
    }
    
    response = client.search(
        body = query,
        index = 'patients'
    ) 
    
    cui_to_gender[cui] = {"F" : 0, "M" : 0}
    n = 0
    for bucket in response["aggregations"]["gender_counts"]["buckets"]:
        cui_to_gender[cui][bucket["key"]] = bucket["doc_count"]
        n += bucket["doc_count"]
    cui_to_gender[cui]["all"] = n

with open(save_path, 'w') as fp:
    json.dump(cui_to_gender, fp)