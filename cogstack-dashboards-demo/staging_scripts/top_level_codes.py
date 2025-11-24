import pandas as pd
import json
import sys
from tqdm import tqdm
from opensearchpy import OpenSearch

# Load the full SNOMED CT relationship file
try:
    df = pd.read_csv(
        "../data/SNOMED/sct2_Relationship.txt",
        delimiter="\t",
    )
except Exception:
    print("Could not load SNOMED CT relationship file. Please check it exists in ../data/SNOMED/sct2_Relationship.txt or follow the README to obtain it.")
    sys.exit()

def find_top_level_concept(df, start_concept_id):
    """
    Finds the top-level concept for a given concept ID by traversing the "is-a" hierarchy.
    
    Parameters:
    - df: DataFrame containing SNOMED CT relationship data.
    - start_concept_id: The concept ID to start the search from.

    Returns:
    - The top-level concept ID.
    """
    while True:
        # Filter for active "is-a" relationships where sourceId matches
        row = df[(df["sourceId"] == start_concept_id) & 
                 (df["typeId"] == 116680003) &  # "is-a" relationship
                 (df["active"] == 1)]  # Active relationships only
        # print(row)
        if row.empty:
            # Nothing found probably british only
            return None
        if row.iloc[0]["destinationId"] == 138875005:
            return start_concept_id
        # Update start_concept_id to the parent (destinationId)
        start_concept_id = row.iloc[0]["destinationId"]

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

query = {
  "size": 0,
  "aggs": {
    "value_counts": {
      "terms": {
        "field": "nlp.cui.keyword",
        "size": 200000
      }
    }
  }
}

response = client.search(
    body = query,
    index = 'discharge_annotations'
)

top_level_counts = {}
buckets = response["aggregations"]["value_counts"]["buckets"]
for bucket in tqdm(buckets, total=len(buckets), desc="Processing CUIs"):
    concept = bucket["key"]
    top_level_concept = str(find_top_level_concept(df, int(concept)))
    if top_level_concept in top_level_counts:
        top_level_counts[top_level_concept] = top_level_counts[top_level_concept] + bucket["doc_count"]
    else:
        top_level_counts[top_level_concept] = bucket["doc_count"]


with open("../data/top_level_counts.json", "w") as file:
    json.dump(top_level_counts, file, indent=4)