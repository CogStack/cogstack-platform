# Graph of which diagnoses tend to occur together (e.g., diabetes + renal disease).
from opensearchpy import OpenSearch
from collections import defaultdict
from scipy.sparse import dok_matrix, save_npz
from tqdm import tqdm 
import pandas as pd
import numpy as np
import json
import itertools

# comment and uncomment as required - collate by patient or by note
# co_occurence = "meta.note_id"
co_occurence = "meta.subject_id"
# index_name = "radiology_annotations"
index_name = "discharge_annotations"

# counting co-occurences of cuis from x axis and y axis
# top level concept can be anything - common top level concepts are:
# disorders=64572001, procedures=71388002, substance=105590001
# None means no top filtering according to the top level concept
y_tlc = None
x_tlc = None

# Choose the top k most occuring concepts to save time on computation
# There are 50733 unique concepts. So going behind 60k is pointless.
top_k = 60000

# choose save path
# multiple files will be saved with different suffixes
# it might be better to put them in their own folder
save_path = "../data/co_occurrences/data"

def get_top_cuis(client, index, K, tlc_val=None):
    body = {
        "size": 0,
        "aggs": {
            "all_cuis": {"terms": {"field": "nlp.cui.keyword", "size": K}}
        }
    }
    if tlc_val:
        body["query"] = {"term": {"enrich_top_level_concept": tlc_val}}
    resp = client.search(index=index, body=body)
    return [b["key"] for b in resp["aggregations"]["all_cuis"]["buckets"]]


def build_query(x_tlc, y_tlc, scroll_size):
    must = []
    if x_tlc and y_tlc:
        must.append({
            "bool": {
                "should": [
                    {"term": {"enrich_top_level_concept": x_tlc}},
                    {"term": {"enrich_top_level_concept": y_tlc}}
                ]
            }
        })
    elif x_tlc:
        must.append({"term": {"enrich_top_level_concept": x_tlc}})
    elif y_tlc:
        must.append({"term": {"enrich_top_level_concept": y_tlc}})

    if must:
        return {
            "size": scroll_size,
            "_source": ["meta.note_id", "meta.subject_id", "nlp.cui", "enrich_top_level_concept"],
            "query": {"bool": {"must": must}},
        }
    else:
        return {
            "size": scroll_size,
            "_source": ["meta.note_id", "meta.subject_id", "nlp.cui", "enrich_top_level_concept"],
            "query": {"match_all": {}},
        }


def main():
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

    if x_tlc and y_tlc:
        cuis_x = get_top_cuis(client, index_name, top_k, y_tlc)
        cuis = cuis_x
        cuis_y = get_top_cuis(client, index_name, top_k, y_tlc)
        cui_to_idx_x = {cui: i for i, cui in enumerate(cuis_x)}
        cui_to_idx = cui_to_idx_x
        cui_to_idx_y = {cui: i for i, cui in enumerate(cuis_y)}
        co_matrix = dok_matrix((len(cuis_x), len(cuis_y)), dtype=np.int32)
        print(f"Tracking {len(cuis_x)} CUIs (X) × {len(cuis_y)} CUIs (Y)")
    elif x_tlc:
        cuis_x = get_top_cuis(client, index_name, top_k, x_tlc)
        cuis = cuis_x
        cuis_y = get_top_cuis(client, index_name, top_k, None)
        cui_to_idx_x = {cui: i for i, cui in enumerate(cuis_x)}
        cui_to_idx = cui_to_idx_x
        cui_to_idx_y = {cui: i for i, cui in enumerate(cuis_y)}
        co_matrix = dok_matrix((len(cuis_x), len(cuis_y)), dtype=np.int32)
        print(f"Tracking {len(cuis_x)} CUIs (X) × {len(cuis_y)} CUIs (Y)")
    elif y_tlc:
        cuis_x = get_top_cuis(client, index_name, top_k, None)
        cuis = cuis_x
        cuis_y = get_top_cuis(client, index_name, top_k, y_tlc)
        cui_to_idx_x = {cui: i for i, cui in enumerate(cuis_x)}
        cui_to_idx = cui_to_idx_x
        cui_to_idx_y = {cui: i for i, cui in enumerate(cuis_y)}
        co_matrix = dok_matrix((len(cuis_x), len(cuis_y)), dtype=np.int32)
        print(f"Tracking {len(cuis_x)} CUIs (X) × {len(cuis_y)} CUIs (Y)")
    else:
        cuis = get_top_cuis(client, index_name, top_k,
                            x_tlc or y_tlc)
        cui_to_idx = {cui: i for i, cui in enumerate(cuis)}
        co_matrix = dok_matrix((len(cuis), len(cuis)), dtype=np.int32)
        print(f"Tracking top {len(cuis)} CUIs")

    
    # Save both directions for convenience
    with open(f"{save_path}_cui_to_idx.json", "w") as f:
        json.dump(cui_to_idx, f)
    idx_to_cui = {v: k for k, v in cui_to_idx.items()}
    with open(f"{save_path}_idx_to_cui.json", "w") as f:
        json.dump(idx_to_cui, f)
    with open(f"{save_path}_cuis.json", "w") as f:
        json.dump(cuis, f)
    print(f"Saved cui mappings to {save_path}_cui_to_idx.json, {save_path}_idx_to_cui.json, and {save_path}_cuis.json")
    
    scroll_size = 10000
    query = build_query(x_tlc, y_tlc, scroll_size)

    resp = client.search(index=index_name, body=query, scroll="5m")
    scroll_id = resp["_scroll_id"]
    total_hits = resp["hits"]["total"]["value"]
    processed = 0
    note_to_cuis = defaultdict(lambda: {"x": set(), "y": set()})

    with tqdm(total=total_hits, desc="Processing documents") as pbar:
        while True:
            hits = resp["hits"]["hits"]
            if not hits:
                break

            for doc in hits:
                src = doc["_source"]
                note_id = src[co_occurence]
                cui = src["nlp.cui"]
                tlc = src.get("enrich_top_level_concept")

                if x_tlc and y_tlc:
                    if tlc == x_tlc and cui in cui_to_idx_x:
                        note_to_cuis[note_id]["x"].add(cui)
                    elif tlc == y_tlc and cui in cui_to_idx_y:
                        note_to_cuis[note_id]["y"].add(cui)
                else:
                    if cui in cui_to_idx:
                        note_to_cuis[note_id]["x"].add(cui)  # single set mode

            # update co-occurrence
            for note_id, groups in note_to_cuis.items():
                if x_tlc and y_tlc:
                    for c1 in groups["x"]:
                        for c2 in groups["y"]:
                            i, j = cui_to_idx_x[c1], cui_to_idx_y[c2]
                            co_matrix[i, j] += 1
                else:
                    cuis_in_note = groups["x"]
                    if len(cuis_in_note) > 1:
                        for c1, c2 in itertools.combinations(sorted(cuis_in_note), 2):
                            i, j = cui_to_idx[c1], cui_to_idx[c2]
                            co_matrix[i, j] += 1
                            co_matrix[j, i] += 1
            note_to_cuis.clear()

            # update progress
            processed += len(hits)
            pbar.update(len(hits))
            # next scroll
            resp = client.scroll(scroll_id=scroll_id, scroll="5m")

    csr = co_matrix.tocsr()
    rows, cols = csr.nonzero()
    values = csr[rows, cols]

    if x_tlc and y_tlc:
        df = pd.DataFrame({
            "cui_x": [cuis_x[i] for i in rows],
            "cui_y": [cuis_y[j] for j in cols],
            "count": values.A1,
        })
    else:
        df = pd.DataFrame({
            "cui_x": [cuis[i] for i in rows],
            "cui_y": [cuis[j] for j in cols],
            "count": values.A1,
        })

    save_npz(save_path + ".npz", csr)
    print(f"Saved co-occurrence matrix to {save_path}.npz")
    df.to_parquet(save_path+".parquet")
    print(f"Saved co-occurrence edges to {save_path}.parquet")

if __name__ == "__main__":
    main()