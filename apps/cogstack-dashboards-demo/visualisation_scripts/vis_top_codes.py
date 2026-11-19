import pandas as pd
import json
import matplotlib.pyplot as plt
import sys

# Load SNOMED CT descriptions
try:
    df = pd.read_csv(
        "../data/SNOMED/sct2_Description.txt", 
        delimiter="\t"
    )
except Exception:
    print("Could not load SNOMED CT description file. Please check it exists in ../data/SNOMED/sct2_Description.txt or follow the README to obtain it.")
    sys.exit()

# Load JSON file
with open("../data/top_level_counts.json", "r") as file:
    data = json.load(file)

def get_name(code):
    code = int(code) if code != "None" else 0
    result = df[(df["conceptId"] == code) & (df["active"] == 1)]
    preferred_term = result[result["typeId"] == 900000000000003001]  # Fully specified name
    return (preferred_term["term"].iloc[0]).split("(")[0] if not preferred_term.empty else str(code)

names = []
counts = []
for key in data:
    if data[key] >= 1:
        names.append(get_name(key))
        counts.append(data[key])

# Calculate total and filter small values
total = sum(counts)
threshold_value = 0.05 * total
others = 0
filtered_data = {}

for name, count in zip(names, counts):
    if count < threshold_value:
        others += count
    else:
        filtered_data[name] = count

if others > 0:
    filtered_data["Others"] = others

plt.rcParams.update({
    'axes.titlesize': 20,      # Title font size
    'axes.titleweight': 'bold', # Title font weight
    'axes.labelsize': 22,      # Label font size
    'axes.labelweight': 'bold', # Label font weight
    'xtick.labelsize': 20,     # X-tick font size
    'ytick.labelsize': 20,     # Y-tick font size
    'legend.fontsize': 18,     # Legend font size
    'lines.linewidth': 2.5,    # Line thickness
})

# Create the pie chart
plt.figure(figsize=(12, 10))
plt.pie(
    filtered_data.values(),
    labels=filtered_data.keys(),
    autopct='%1.1f%%',
    startangle=140,
    textprops={'fontsize': 20},
    # labeldistance=0.8
)
plt.title("Top Level Concepts")
plt.savefig("../figures/top_level_concepts.png")
print(f"Figure saved to ../figures/top_level_concepts.png")