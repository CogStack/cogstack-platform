ui           = true
cluster_addr = "https://openbao:8201"

storage "raft" {
  path = "/openbao/file"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/openbao/tls/tls.crt"
  tls_key_file  = "/openbao/tls/tls.key"
}
