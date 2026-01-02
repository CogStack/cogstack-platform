from sklearn.manifold import TSNE
from collections import Counter, deque
from scipy.spatial import ConvexHull
import plotly.graph_objects as go
import matplotlib.pyplot as plt
import scipy.sparse as sp
import numpy as np
import pandas as pd
import plotly.express as px
import networkx as nx
import json
import hdbscan
import re
import sys

# these are CUIs that we've decided are uninteresting in the process of making figures. They can be removed as required
BANNED_CUIS = {
    138875005,  # SNOMED CT Concept (root)
    387713003, # Surgical Procedure
    106232001, # adjectival modifier
    106234000, # general adjectival modifier
    255203001, # additional values
    301857004, # finding of body region
    928000, # disease of musculoskeletal system
    312225001, # muscukloskeletal and connective tissue diseases
    298363007,  # finding of regional structure
    822987005, # finding of abdominopelvic segment of trunk
    822988000, # disorder of abdominopelvic segment of trunk
    118948005, # disease of abdomen
    609624008, # finding of abdomen
    609618002, # disorder of abdominal section of trunk
    119415007, # general finding of abdomen
    609627001, # finding of abdominal section of trunk
    118225008, # context dependant finding
}

ancestor_colors = {}
color_palette = px.colors.qualitative.Pastel + px.colors.qualitative.Set2

def get_color_for_ancestor(ancestor):
    if ancestor not in ancestor_colors:
        ancestor_colors[ancestor] = color_palette[len(ancestor_colors) % len(color_palette)]
    return ancestor_colors[ancestor]

def compute_depths(G, root=138875005):
    """
    Compute hierarchical depth (distance from root) in a SNOMED CT 'isa' graph.
    Edges are oriented child -> parent, so we traverse the reverse direction.
    
    Returns:
        dict: {node_id: depth} for all reachable nodes.
    """
    # 138875005 is the root concept
    depths = {root: 0}
    queue = deque([(root, 0)])
    
    # Traverse the graph in reverse (parent -> child)
    while queue:
        node, d = queue.popleft()
        for child in G.successors(node):  # reversed direction
            if child not in depths:
                depths[child] = d + 1
                queue.append((child, d + 1))
    return depths

def get_name(code):
    """Map SNOMED CT code -> preferred term"""
    try:
        code = int(code)
    except Exception:
        return str(code)

    result = name_df[(name_df["conceptId"] == code) & (name_df["active"] == 1)]
    preferred_term = result[result["typeId"] == 900000000000003001]  # Fully specified name

    if not preferred_term.empty:
        return preferred_term["term"].iloc[0].split("(")[0].strip()
    return str(code)

def most_frequent_ancestor_specific(cluster_cuis, G, depths, min_depth=3):
    """
    Returns (most_specific_common_ancestor, [CUIs contributing to it]).
    Excludes ancestors shallower than min_depth.
    """
    cluster_cuis = [int(cui) for cui in cluster_cuis if str(cui).isdigit()]
    anc_lists = []

    for cui in cluster_cuis:
        if cui not in G:
            continue
        anc = set(nx.ancestors(G, cui)) | {cui}
        # Filter out top-level ancestors based on depth
        anc = {a for a in anc if depths.get(a, 999) >= min_depth}
        anc_lists.append(anc)

    all_ancestors = [a for anc in anc_lists for a in anc if a not in BANNED_CUIS]
    if not all_ancestors:
        return None, []

    most_common_ancestor, _ = Counter(all_ancestors).most_common(1)[0]
    contributing = [cui for cui, anc in zip(cluster_cuis, anc_lists) if most_common_ancestor in anc]
    return int(most_common_ancestor), contributing

# Load SNOMED CT description table
try:
    name_df = pd.read_csv(
    "../data/SNOMED/sct2_Description.txt", 
    delimiter="\t"
)
except Exception:
    print("Could not load SNOMED CT description file. Please check it exists in ../data/SNOMED/sct2_Description.txt or follow the README to obtain it.")
    sys.exit()

# Load the SNOMED relationships table (id, sourceId, destinationId, typeId)
try:
    relations_df = pd.read_csv(
        "../data/SNOMED/sct2_Relationship.txt",
        delimiter="\t",
    )
except Exception:
    print("Could not load SNOMED CT relationship file. Please check it exists in ../data/SNOMED/sct2_Relationship.txt or follow the README to obtain it.")
    sys.exit()

# Keep only "Is a" relationships (typeId == 116680003)
isa = relations_df[relations_df['typeId'] == 116680003]

# Build a directed graph: child → parent
G = nx.DiGraph()
G.add_edges_from(zip(isa['destinationId'].astype(int), isa['sourceId'].astype(int)))

path_to_resources = "../data/co_occurrences/"

# Load cui mapping
with open(path_to_resources + "data_cuis.json") as f:
    cuis = json.load(f)

# Load matrix
co_matrix = sp.load_npz(path_to_resources + "data.npz").tocsr().astype(np.float64)
print("Original shape:", co_matrix.shape, "Nonzeros:", co_matrix.nnz)

# Compute total co-occurrence counts for each concept
concept_counts = np.array(co_matrix.sum(axis=1)).ravel()  # sum across rows

# Keep indices with >x occurrences
count_threshold = 200
keep_mask = concept_counts > count_threshold
keep_indices = np.where(keep_mask)[0]

print(f"Keeping {keep_mask.sum()} of {len(keep_mask)} concepts (>{count_threshold} occurrences)")

# Filter rows and columns
co_matrix = co_matrix[keep_indices,:]
filtered_cuis = [cuis[i] for i in keep_indices]

print("Filtered shape:", co_matrix.shape, "Nonzeros:", co_matrix.nnz)

embedding = TSNE(
    n_components=2,
    perplexity=5,
    learning_rate=200,
    n_iter=2000,
    metric='cosine',
    random_state=42
).fit_transform(co_matrix.toarray())

embedding_df = pd.DataFrame({
    "x": embedding[:, 0],
    "y": embedding[:, 1],
    "cui": filtered_cuis,
})
embedding_df["name"] = embedding_df["cui"].apply(get_name)
embedding_df["label"] = embedding_df["name"].str.slice(0, 60) + "..."

# expermiental numbers for clustering
min_cluster_size = max(5, len(embedding_df) // 100)
min_samples = min_cluster_size // 2

# clustering on 2d reduced vectors
clusterer = hdbscan.HDBSCAN(
    min_samples=3,       # higher = more conservative
    metric='euclidean'
)
embedding_df["cluster"] = clusterer.fit_predict(embedding_df[["x", "y"]])

clusters = embedding_df['cluster'].unique()
clusters_sorted = sorted(clusters)
color_map = {}

# Use a qualitative color palette 
palette = px.colors.qualitative.Plotly

# Assign colors to clusters
for i, c in enumerate(clusters_sorted):
    if c == -1:
        color_map[c] = 'grey'  # noise points
    else:
        color_map[c] = palette[i % len(palette)]

# Add a color column to the dataframe
embedding_df['color'] = embedding_df['cluster'].map(color_map)

clusters_dict = {}

# saving clusters into json for future work
for cluster_id, group in embedding_df.groupby("cluster"):
    clusters_dict[int(cluster_id)] = {
        "count": len(group),
        "concepts": [
            {
                "cui": row["cui"],
                "name": row["name"],
                "x": float(row["x"]),
                "y": float(row["y"])
            }
            for _, row in group.iterrows()
        ]
    }

# Save to JSON
with open("../data/co_occurrence_clusters.json", "w", encoding="utf-8") as f:
    json.dump(clusters_dict, f, ensure_ascii=False, indent=2)
    print(f"Saved {len(clusters_dict)} clusters to ../data/co_occurence_clusters.json")

depths = compute_depths(G)

cluster_to_ancestor = {}
cluster_to_ratio = {}
for cluster_id, group in embedding_df.groupby("cluster"):
    if cluster_id == -1:
        continue
    cuis = group["cui"].astype(int).tolist()
    ancestor, contributing_cuis = most_frequent_ancestor_specific(cuis, G, depths)
    ratio = len(contributing_cuis)/len(cuis)
    cluster_to_ancestor[cluster_id] = ancestor
    cluster_to_ratio[cluster_id] = ratio
embedding_df["common_ancestor"] = embedding_df["cluster"].map(cluster_to_ancestor)

# Compute average ratio per ancestor
ancestor_to_ratio = {}
for cluster_id, ancestor in cluster_to_ancestor.items():
    ratio = cluster_to_ratio.get(cluster_id, 0)
    if ancestor not in ancestor_to_ratio:
        ancestor_to_ratio[ancestor] = []
    ancestor_to_ratio[ancestor].append(ratio)

# Collapse lists into average ratios
ancestor_to_ratio = {a: np.mean(r) for a, r in ancestor_to_ratio.items()}

# Loop through ancestors, not clusters
added_legends = set()
fig = go.Figure()

for cluster_id, cluster_df in embedding_df.groupby("cluster"):
    ancestor_id = cluster_df["common_ancestor"].iloc[0]

    color = get_color_for_ancestor(ancestor_id)

    # --- Points (always visible) ---
    fig.add_trace(go.Scatter(
        x=cluster_df["x"],
        y=cluster_df["y"],
        mode="markers",
        marker=dict(size=5, color=color, opacity=0.8),
        hovertext=cluster_df["name"],
        hoverinfo="text",
        showlegend=False, 
        # legendgroup=str(ancestor_id),
    ))

    # --- Convex hull (the part that appears in the legend) ---
    if cluster_id != -1 and len(cluster_df) > 2:
        hull = ConvexHull(cluster_df[["x", "y"]])
        hull_pts = cluster_df.iloc[hull.vertices]
        ratio = ancestor_to_ratio.get(ancestor_id, 0)
        fig.add_trace(go.Scatter(
            x=hull_pts["x"],
            y=hull_pts["y"],
            fill="toself",
            mode="lines",
            line=dict(color=color, width=0.5),
            fillcolor=color,
            opacity=0.15,
            name=f"Name: {get_name(ancestor_id)}, Id: {ancestor_id}, Ratio: {ratio:.2f}",
            legendgroup=str(ancestor_id),
            showlegend=(ancestor_id not in added_legends),
            hoverinfo="skip"
        ))
        added_legends.add(ancestor_id)

fig.write_html("../figures/clusters.html")

# Figure PNG
fig, ax = plt.subplots(figsize=(10, 6), dpi=600)

def to_mpl_color(color_str):
    """Convert 'rgb(r,g,b)' strings to matplotlib-friendly (r,g,b) tuples in 0–1 range."""
    if isinstance(color_str, str) and color_str.startswith("rgb"):
        nums = list(map(int, re.findall(r"\d+", color_str)))
        return tuple(v / 255 for v in nums)
    return color_str 


added_legends = set()

for cluster_id, cluster_df in embedding_df.groupby("cluster"):
    ancestor_id = cluster_df["common_ancestor"].iloc[0]
    color = to_mpl_color(get_color_for_ancestor(ancestor_id))

    ax.scatter(
        cluster_df["x"],
        cluster_df["y"],
        s=8,  # point size
        color=color,
        alpha=0.8,
        linewidths=0,
        label=None
    )

    if cluster_id != -1 and len(cluster_df) > 2:
        hull = ConvexHull(cluster_df[["x", "y"]])
        hull_pts = cluster_df.iloc[hull.vertices]
        ratio = ancestor_to_ratio.get(ancestor_id, 0)

        ax.fill(
            hull_pts["x"],
            hull_pts["y"],
            color=color,
            alpha=0.15,
            linewidth=0.6,
            label=None  # we'll manage legend manually
        )

        if ancestor_id not in added_legends:
            ancestor_name = get_name(ancestor_id) 
            ax.scatter([], [], color=color, label=f"{ancestor_name} | {ratio:.2f}") # 
            added_legends.add(ancestor_id)

ax.tick_params(labelsize=7)

ax.legend(
    loc='upper center',
    bbox_to_anchor=(0.5, -0.1), 
    ncol=4,
    fontsize=8,
    frameon=False,
    handlelength=1.2,
    handletextpad=0.4,
    columnspacing=1.0
)
plt.tight_layout(pad=0.5, rect=[0, 0.05, 1, 1])

plt.tight_layout()
plt.savefig("../figures/clusters.png", bbox_inches="tight", dpi=600)
plt.show()
