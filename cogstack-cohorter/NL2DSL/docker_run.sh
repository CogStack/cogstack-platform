sudo docker network create cohorter-net

sudo docker network connect cohorter-net ollama
sudo docker network connect cohorter-net cohorter-medcat

sudo docker run -d --name cohorter-nl2dsl --network cohorter-net \
  -p 3002:3002 \
  -e OLLAMA_URL="http://ollama:11434/api/generate" \
  -e OLLAMA_MODEL="llama3.2:3b" \
  -e MEDCAT_URL="http://cohorter-medcat:5000" \
  -e ALLOW_ORIGINS="*" \
  --restart unless-stopped \
  cohorter-nl2dsl:latest
