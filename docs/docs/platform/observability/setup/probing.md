# Availability

This guide explains how to configure HTTP probers using Blackbox Exporter in Grafana Alloy to monitor the availability of your services. These probers generate uptime and latency metrics, which can then be visualized in Grafana.

See the [Reference](../reference/understanding-metrics.md) for an explanation of the metrics this generates.

---

## How to Add New Probers

To add a new prober target:

1. Navigate to the folder:

   ```
    alloy/probers/
   ```

2. Create a new YAML file (e.g., `probe.my-services.yml`) with the following structure:

   ```
    # probe.my-services.yml
    - targets:
        - https://myservice.example.com/health
      labels:
        name: my-service             # Mandatory - the name of the service being probed
        job: my-services             # Mandatory - used to group probes in dashboards
        ip_address: "10.0.0.12"      # Optional - IP of the host being probed
        host: service-hostname       # Optional - Human-readable hostname
        any_custom_field: anything   # Optional - Add as many labels as desired here
   ```

3. Ensure the folder is mounted in docker under `/etc/alloy/probers`, which it should be by default if you've followed the setup guids. Any valid `.yml` files in this folder will be automatically picked up and used as Blackbox targets.

---

## Advanced Setup
See [Prober Customization](../customization/blackbox-exporter-config.md) to do any advanced setup, for example adding Basic Auth to allow the prober to call endpoints that need a username and password

## Notes

* Changes will take effect on the next Prometheus reload or container restart.
* Jobs with the same `job` label are grouped in dashboards to simplify analysis.
* Job labels need to line up with defined SLOs to enable Alerting
* Probers can be used for both external URLs, and direct to local docker containers. For example, we probe grafana on "grafana:3000/". If you want to probe local docker containers, note that the network has to line up


## External links
For full Blackbox Exporter documentation, see:

- [Prometheus Blackbox Exporter](https://github.com/prometheus/blackbox_exporter)
