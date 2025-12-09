curl -X GET \
  "https://cogstackdashboards.sites.er.kcl.ac.uk/auth/api/proxy/discharge_annotations/_search?pretty" \
  -H "Content-Type: application/json" \
  -H "Username: <PhysioNet username>" \
  -d '{
    "size": 1,
    "query": {
      "match_all": {}
    }
  }'