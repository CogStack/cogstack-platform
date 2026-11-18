locals {

  services = {
    medcat_service = {
      hostname    = "medcat-service.cogstack.local"
      path_prefix = "medcat-service"
    }
  }
  planned_ingress_name = yamldecode(data.helm_template.medcat-service.manifests["templates/ingress.yaml"]).metadata.name
}
