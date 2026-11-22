# Prober Customizations

## How to add Auth to the prober or further configurations?

To define how a probe behaves (e.g., add basic auth, headers, timeout, method), we will configure a module in the Blackbox Exporter config.

### 1. Create a Blackbox Exporter Config file
You will need to create a new file, and then mount it over the existing provided vconfig


1. Create a new file:

   ```
    alloy/blackbox-exporter.yml
   ```

2. Add the existing defaults

```yaml
modules:
    http_get_200:
        prober: http
        timeout: 5s
        http:
        valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
        valid_status_codes: [200]  # Defaults to 2xx
        method: GET
        preferred_ip_protocol: "ip4" # defaults to "ip6"
        tls_config:
            insecure_skip_verify: true
```

3. Add your own module to the modules in that file
```yaml
  http_2xx_custom:
    prober: http
    timeout: 5s
    http:
      valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
      valid_status_codes: [200]  # Defaults to 2xx
      method: GET
      preferred_ip_protocol: "ip4" # defaults to "ip6"
      tls_config:
        insecure_skip_verify: true
      basic_auth:
        username: my-user
        password: example-pass
```

This example adds a module named `http_2xx_custom` that adds some basic auth credentials

---

### 2. Reference the new module in your prober config

In your probe YAML file, reference the module in the `module` field of the `labels` section:

```yaml
    - targets:
        - https://myservice.example.com/health
      labels:
        name: my-service
        module: http_2xx_custom      # Optional - overrides the default Blackbox module
```

### 3. Mount the config file
You lastly need to mount the new config file and refer to it in docker compose

```yaml
 alloy:
    image: cogstacksystems/observability-alloy:latest
...
    volumes:
      - ${BASE_DIR-.}/alloy/blackbox-exporter.yml:/etc/alloy/blackbox-exporter.yml
...
```
