sudo docker network create cohorter-net

sudo docker network connect cohorter-net ollama
sudo docker network connect cohorter-net cohorter-medcat

sudo docker run -d --name cohorter-nl2dsl --network cohorter-net \
  -p 3002:3002 \
  -e OLLAMA_URL="http://ollama:11434/api/generate" \
  -e OLLAMA_MODEL="gpt-oss:20b" \
  -e MEDCAT_URL="http://cohorter-medcat:3001" \
  -e ALLOW_ORIGINS="*" \
  --restart unless-stopped \
  cohorter-nl2dsl:latest
