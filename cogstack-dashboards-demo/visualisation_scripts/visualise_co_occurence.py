import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
import numpy as np
import sys

# Load SNOMED CT description table
try:
    df = pd.read_csv(
        "../data/SNOMED/sct2_Description.txt", 
        delimiter="\t"
    )
except Exception:
    print("Could not load SNOMED CT description file. Please check it exists in ../data/SNOMED/sct2_Description.txt or follow the README to obtain it.")
    sys.exit()

def get_name(code):
    code = int(code) if code != "None" else 0
    # Filter the description table for the SNOMED code
    result = df[(df["conceptId"] == code) & 
                            (df["active"] == 1)]  # Only active descriptions
                        
    # Extract the preferred term
    preferred_term = result[result["typeId"] == 900000000000003001]  # "Fully specified name"
    
    return (preferred_term["term"].iloc[0]).split("(")[0] if not preferred_term.empty else code

# Load parquet
co_occurences_df = pd.read_parquet("../data/hand_selected_co_occurrences.parquet")

# Predefined curated lists
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

# columns lists can be removed if not required for a figure
row_cuis = [str(c) for c in serious_disorders]
col_cuis = [str(c) for c in common_procedures + common_symptoms + common_substances]

# Filter for pairs where one is in row_cuis and the other in col_cuis
df_subset = co_occurences_df[
    ((co_occurences_df["cui_x"].isin(row_cuis)) & (co_occurences_df["cui_y"].isin(col_cuis))) |
    ((co_occurences_df["cui_y"].isin(row_cuis)) & (co_occurences_df["cui_x"].isin(col_cuis)))
].copy()

# Normalize orientation: row_cui always disorder, col_cui always symptom/procedure/substance
def orient(row):
    if row["cui_x"] in row_cuis and row["cui_y"] in col_cuis:
        return row["cui_x"], row["cui_y"]
    else:
        return row["cui_y"], row["cui_x"]

df_subset[["row_cui", "col_cui"]] = df_subset.apply(orient, axis=1, result_type="expand")

# Pivot into matrix
heatmap_df = df_subset.pivot_table(
    index="row_cui",
    columns="col_cui",
    values="count",
    fill_value=0
)

# Enforce full grid (even if no co-occurrence for some)
heatmap_df = heatmap_df.reindex(index=row_cuis, columns=col_cuis, fill_value=0)

# Map CUIs to names
row_labels = [get_name(c) for c in heatmap_df.index]
col_labels = [get_name(c) for c in heatmap_df.columns]

# Replace 0 with NaN so they can be colored uniformly
plot_data = heatmap_df.replace(0, np.nan)

cmap = plt.cm.Reds
cmap.set_bad(color="#BFE5F7A7")

fig, ax = plt.subplots(figsize=(20, 8))

sns.heatmap(
    plot_data,
    cmap=cmap,
    xticklabels=col_labels,
    yticklabels=row_labels,
    cbar_kws={"label": "Co-occurrence Count"},
    norm=mcolors.LogNorm(vmin=1, vmax=heatmap_df.values.max()),
    linewidths=0.25, linecolor="gray",
    square=False,
    ax=ax
)

ax.set_title("Co-occurrence of Handpicked SNOMED Codes", fontsize=18, pad=20)  
ax.set_xlabel("", fontsize=14, labelpad=10)
ax.set_ylabel("Major Disorders", fontsize=14, labelpad=10)

plt.xticks(rotation=90)
plt.yticks(rotation=0)
plt.tight_layout()
plt.savefig("../figures/handpicked_co_occurrences.png", dpi=600)
