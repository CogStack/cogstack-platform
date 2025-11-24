import pandas as pd
import sys
import os
import json
import sys
import numpy as np
import matplotlib.pyplot as plt
from opensearchpy import OpenSearch

# Load SNOMED CT descriptions
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

# Open json file and read into dict
with open('../data/cui_to_gender_all.json') as f:
    cui_to_gender = json.load(f)

# Total counts for normalization
totals = {'M': 141159, 'F': 158553, 'all': 299712}

# Normalize counts before selecting top conditions
cui_to_gender = {
    cui: {category: (count / totals[category]) * 100 for category, count in counts.items()}
    for cui, counts in cui_to_gender.items()
}

top_10_most_male = {
    get_name(cui): data  # Apply function to keys
    for cui, data in sorted(cui_to_gender.items(), key=lambda item: max(item[1]["M"], 1) / max(item[1]["F"], 1), reverse=True)[:10]
}
top_10_most_female = {
    get_name(cui): data  # Apply function to keys
    for cui, data in sorted(cui_to_gender.items(), key=lambda item: max(item[1]["F"], 1) / max(item[1]["M"], 1), reverse=True)[:10]
}

# This reversal is so the most female are shown at the top of the figure, and the most male at the bottom.
# The closest are in the middle - which I think is nicer
top_10_most_female = dict(reversed(list(top_10_most_female.items()))) 

merged_dict = {**top_10_most_male, **top_10_most_female, }

# Convert counts to percentages
# data_percent = {
#     condition: {category: (count / totals[category]) * 100 for category, count in counts.items()}
#     for condition, counts in merged_dict.items()
# }

# Categories (Male, Female, All)
categories = ["M", "F", "all"]
colors = {"M": "#1f77b4", "F": "#d62728", "all": "#2ca02c"}  # Define colors

# Set figure size
fig, ax = plt.subplots(figsize=(12, 4))

# Bar width and position setup
y_positions = np.arange(len(merged_dict))  # One position per condition
bar_width = 0.2  # Spacing for bars within the group

# Loop through categories (M, F, All) and plot bars grouped together
for i, category in enumerate(categories):
    values = [merged_dict[condition][category] for condition in merged_dict]  # Extract percentages
    ax.barh(y_positions + i * bar_width, values, bar_width, label=category, color=colors[category])

# Set y-ticks to condition names
ax.set_yticks(y_positions + bar_width)  # Centering labels
ax.set_yticklabels(merged_dict.keys())

# Labels and title
ax.set_xlabel("Prevalence (%)")
# ax.set_ylabel("Condition")
ax.set_title("Prevalence of Conditions by Gender for All Notes")
ax.legend(title="Category")  # Legend for colors

# Improve layout
plt.grid(axis="x", linestyle="--", alpha=0.7)
plt.tight_layout()

plt.savefig("../images/disorder_per_gender_all.pdf", format="pdf", bbox_inches="tight")