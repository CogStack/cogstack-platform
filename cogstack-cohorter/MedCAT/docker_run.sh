sudo docker run -d --name cohorter-medcat \
  -p 3001:3001 \
  -v "$PWD/models:/app/models" \
  -e MEDCAT_MODEL_PACK=/app/models/medcat_model_pack.zip \
  -e ALLOW_ORIGINS="*" \
  cohorter-medcat:latest
