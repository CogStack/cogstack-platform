# Create a Keypair resource in openstack
# Either generate a brand new public and private key, when the var.ssh_key_pair variable is not provided
# Or use the file contents in var.ssh_key_pair 

locals {
  is_using_existing_ssh_keypair = var.ssh_key_pair != null
  ssh_keys = {
    # If user inputs an existing SSH keypair, then pass it through. Else use the generated resources.
    private_key      = local.is_using_existing_ssh_keypair ? file(var.ssh_key_pair.private_key_file) : openstack_compute_keypair_v2.compute_keypair.private_key
    private_key_file = local.is_using_existing_ssh_keypair ? var.ssh_key_pair.private_key_file : abspath(local_file.private_key[0].filename)
    public_key       = local.is_using_existing_ssh_keypair ? file(var.ssh_key_pair.public_key_file) : openstack_compute_keypair_v2.compute_keypair.public_key
    public_key_file  = local.is_using_existing_ssh_keypair ? var.ssh_key_pair.public_key_file : abspath(local_file.public_key[0].filename)
  }
}

resource "openstack_compute_keypair_v2" "compute_keypair" {
  name       = local.prefix != "" ? "${local.prefix}-cogstack_keypair" : "cogstack_keypair"
  public_key = local.is_using_existing_ssh_keypair ? file(var.ssh_key_pair.public_key_file) : null
}

resource "local_file" "private_key" {
  count           = local.is_using_existing_ssh_keypair ? 0 : 1
  content         = openstack_compute_keypair_v2.compute_keypair.private_key
  filename        = "${local.output_file_directory}/${openstack_compute_keypair_v2.compute_keypair.name}-rsa.pem"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  count           = local.is_using_existing_ssh_keypair ? 0 : 1
  content         = openstack_compute_keypair_v2.compute_keypair.public_key
  filename        = "${local.output_file_directory}/${openstack_compute_keypair_v2.compute_keypair.name}-rsa.pub"
  file_permission = "0600"
}
