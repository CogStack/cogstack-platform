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

def top_disorder_children(response):
    all_disorder_counts = {}
    buckets = response["aggregations"]["value_counts"]["buckets"]
    for bucket in tqdm(buckets, total=len(buckets), desc="Top Disorder Counts CUIs"):
        concept = bucket["key"]
        count = bucket["doc_count"]
        all_disorder_concepts = find_all_disorder_children(df, int(concept))
        if all_disorder_concepts == set():
            continue
        else:
            for ancestor_concept in all_disorder_concepts:
                if ancestor_concept in all_disorder_counts:
                    all_disorder_counts[ancestor_concept] = all_disorder_counts[ancestor_concept] + count
                else:
                    all_disorder_counts[ancestor_concept] = count

    with open("../data/top_disorder_counts.json", "w") as file:
        json.dump(all_disorder_counts, file, indent=4)

top_disorder_children(response)  

def disorder_counts(response):
    all_disorder_counts = {}
    buckets = response["aggregations"]["value_counts"]["buckets"]
    for bucket in tqdm(buckets, total=len(buckets), desc="All disorder count CUIs"):
        concept = int(bucket["key"])
        count = bucket["doc_count"]
        if disorder_parent(df, int(concept)):
            all_disorder_counts[concept] = count

    with open("../data/all_disorder_counts.json", "w") as file:
        json.dump(all_disorder_counts, file, indent=4)

disorder_counts(response)