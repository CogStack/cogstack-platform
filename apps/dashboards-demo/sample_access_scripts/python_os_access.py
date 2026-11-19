from opensearchpy import OpenSearch

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

response = client.search(
    index="discharge_annotations",
    body={
        "size": 1,
        "query": {
            "match_all": {}
        }
    }
)

print(response)