import pandas as pd
import json
import sys
from opensearchpy import OpenSearch
from tqdm import tqdm

try:
    df = pd.read_csv(
        "../data/SNOMED/sct2_Relationship.txt",
        delimiter="\t",
    )
except Exception:
    print("Could not load SNOMED CT relationship file. Please check it exists in ../data/SNOMED/sct2_Relationship.txt or follow the README to obtain it.")
    sys.exit()

def disorder_parent(df, concept_id, disorder_id=64572001):
    """
    Finds any 'Disorder' children along the path from a given concept ID to the 'Disorder' concept.
    
    Parameters:
    - df: DataFrame containing SNOMED CT relationship data.
    - concept_id: The concept ID to start the search from.
    - disorder_id: The ID for 'Disorder' (default 64572001).
    
    Returns:
    - True if it is a child of the disorder node
    - False: if not
    """
    visited = set()
    queue = [(concept_id, [])]  # (current_concept, path_to_disorder)

    while queue:
        current, path = queue.pop(0)
        if current in visited:
            continue
        visited.add(current)

        # Check for "is-a" relationships
        parents = df[
            (df["sourceId"] == current) & 
            (df["typeId"] == 116680003) &  # "is-a" relationship
            (df["active"] == 1)
        ]["destinationId"].tolist()

        # If Disorder is a parent, add the current concept as a 'disorder child'
        if disorder_id in parents:
            return True

        # Continue traversing
        for parent in parents:
            queue.append((parent, path + [current]))

    return False

def find_all_disorder_children(df, concept_id, disorder_id=64572001):
    """
    Finds all 'Disorder' children along the path from a given concept ID to the 'Disorder' concept.
    
    Parameters:
    - df: DataFrame containing SNOMED CT relationship data.
    - concept_id: The concept ID to start the search from.
    - disorder_id: The ID for 'Disorder' (default 64572001).
    
    Returns:
    - disorder_children: A list of all 'Disorder' children encountered along the path.
    - full_path: The entire path from the concept to 'Disorder' in the hierarchy.
    """
    visited = set()
    queue = [(concept_id, [])]  # (current_concept, path_to_disorder)
    disorder_children = set()

    while queue:
        current, path = queue.pop(0)
        if current in visited:
            continue
        visited.add(current)

        # Check for "is-a" relationships
        parents = df[
            (df["sourceId"] == current) & 
            (df["typeId"] == 116680003) &  # "is-a" relationship
            (df["active"] == 1)
        ]["destinationId"].tolist()

        # If Disorder is a parent, add the current concept as a 'disorder child'
        if disorder_id in parents:
            disorder_children.add(current)

        # Continue traversing
        for parent in parents:
            queue.append((parent, path + [current]))

    return disorder_children

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

# index of interest. discharge_annotations or radiology_annotations
index = "discharge_annotations"
save_path = "../data/cui_to_subjects_discharge.json"

# Define composite aggregation query
query = {
    "size": 0,
    "query": {
        "bool": {
            "must": [
                {"terms": {"enrich_top_level_concept": [64572001]}},
                {"term": {"nlp.meta_anns.Presence.value": True}},
                {"term": {"nlp.meta_anns.Subject.value.keyword": "Patient"}},
                {"range": {"nlp.context_similarity": {"gt": 0.6}}}
            ]
        }
    },
    "aggs": {
        "cui_counts": {
            "composite": {
                "size": 10000,  # Fetch in chunks
                "sources": [
                    {"cui": {"terms": {"field": "nlp.cui.keyword"}}},
                    {"subject_id": {"terms": {"field": "meta.subject_id.keyword"}}}
                ]
            }
        }
    }
}

# Get estimated total buckets
cardinality_query = {
    "size": 0,
    "query": query["query"],
    "aggs": {
        "estimated_total_buckets": {
            "cardinality": {
                "script": {
                    "source": "doc['nlp.cui.keyword'].value + '|' + doc['meta.subject_id.keyword'].value"
                }
            }
        }
    }
}

est = client.search(index=index, body=cardinality_query)
total_est = est["aggregations"]["estimated_total_buckets"]["value"]

pbar = tqdm(total=total_est, desc="Estimated Progress")

after_key = None
cui_to_subjects = {}

while True:
    if after_key:
        query["aggs"]["cui_counts"]["composite"]["after"] = after_key

    response = client.search(index=index, body=query)
    buckets = response["aggregations"]["cui_counts"]["buckets"]

    for bucket in buckets:
        cui = bucket["key"]["cui"]
        subject_id = bucket["key"]["subject_id"]
        cui_to_subjects.setdefault(cui, set()).add(subject_id)

    pbar.update(len(buckets))

    if "after_key" in response["aggregations"]["cui_counts"]:
        after_key = response["aggregations"]["cui_counts"]["after_key"]
    else:
        break

pbar.close()

# Convert sets to lists for final output
cui_to_subjects = {cui: list(subjects) for cui, subjects in cui_to_subjects.items()}

print(f"Saved data to: ../data/cui_to_subjects_discharge.json")
with open(save_path, "w") as fp:
    json.dump(cui_to_subjects, fp)