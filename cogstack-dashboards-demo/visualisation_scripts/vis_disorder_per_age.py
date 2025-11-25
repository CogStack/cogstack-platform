import pandas as pd
import json
import sys
import numpy as np
import matplotlib.pyplot as plt
from scipy.ndimage import gaussian_filter1d

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

with open('../data/cui_to_age.json') as f:
    cui_to_age = json.load(f)

snomed_codes = [
    66214007, 44054006, 370143000, 396275006, 52448006, 
    13645005, 49436004, 13746004, 24700007, 254900004
]

wanted_codes = {get_name(str(code)): cui_to_age[str(code)] for code in snomed_codes if str(code) in cui_to_age}

# Set up the figure and subplots
fig, axes = plt.subplots(2, 5, figsize=(15, 6), sharex=True)
axes = axes.flatten()  # Flatten the 2D array of axes

for ax, (cui, age_counts) in zip(axes, wanted_codes.items()):
    # Remove the "all" and "91" keys if they exist
    age_counts = {k: v for k, v in age_counts.items() if k != "all" and k != "91"}

    # Convert age keys to integers and sort
    ages = np.array(sorted(map(int, age_counts.keys())))
    counts = np.array([age_counts[str(age)] for age in ages])

    # Apply Gaussian smoothing
    smoothed_counts = gaussian_filter1d(counts, sigma=2)

    # Plot smooth line
    ax.plot(ages, smoothed_counts, linestyle="-", color="#1f77b4", alpha=0.7)

    # Fill the area below the line
    ax.fill_between(ages, smoothed_counts, color="#1f77b4", alpha=0.3)

    ax.set_ylim(min(smoothed_counts) - 1, max(smoothed_counts) + 1)

    ax.set_title(cui, fontsize=10)
    ax.set_xlabel("Age")
    ax.set_ylabel("Count")

# Adjust layout
plt.tight_layout()
plt.savefig("../figures/disorder_per_age.pdf", format="pdf", bbox_inches="tight")