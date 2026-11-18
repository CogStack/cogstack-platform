from opensearchpy import OpenSearch
import matplotlib.pyplot as plt

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

def main(field, title, save_path):

  query = {
    "size": 0,
    "aggs": {
      "value_counts": {
        "terms": {
          "field": field,
          "size": 100
        }
      }
    }
  }

  response = client.search(
      body = query,
      index = 'discharge_annotations'
  )

  labels = []
  counts = []
  for bucket in response["aggregations"]["value_counts"]["buckets"]:
      labels.append(bucket["key"])
      counts.append(bucket["doc_count"])

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

  plt.figure(figsize=(12, 10))
  plt.pie(
      counts, 
      labels=labels, 
      autopct='%1.1f%%',  # Display percentages
      startangle=140,
      textprops={'fontsize': 20}
  )

  # Add a title
  plt.title(title)

  # Save the chart to a file
  plt.savefig(save_path)

main("nlp.meta_anns.Presence.value.keyword", "Presence", "../figures/presence.png")
main("nlp.meta_anns.Time.value.keyword", "Time", "../figures/time.png")
main("nlp.meta_anns.Subject.value.keyword", "Subject", "../figures/subject.png")