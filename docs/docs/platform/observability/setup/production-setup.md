# Production Setup Tutorial

This tutorial guides you through setting up the **CogStack Observability Stack** for production use.

If you're new, we recommend completing the [Quickstart Tutorial](../get-started/quickstart.md) first to get a simplified setup running.

By the end of the tutorial, you will have a complete stack offering all the observability features, customized to your usage. 

We will run the stack and then:

- Setup further *Probing* of our running services to get availability metrics
- Configure *Telemetry* like VM memory usage, and Elasticsearch index size, by running Grafana Alloy
- Enable *Alerting* based on our availability and a defined Service Level Objective (SLO)

---

## Step 1: Initialise the project

Run:
```bash
curl https://raw.githubusercontent.com/CogStack/cogstack-platform-toolkit/85029d135b5bacfb473b638d82e45021ee67781a/observability/examples/full/full-quickstart.sh | bash
```

This script will setup all the folder structure, and download all the relevant files.

### Script Details
The script automates making folders, and downloading these files:

Downloads the example docker compose files:

- [docker-compose.yml](https://raw.githubusercontent.com/CogStack/cogstack-platform-toolkit/85029d135b5bacfb473b638d82e45021ee67781a/observability/examples/full/docker-compose.yml)
- [exporters.docker-compose.yml](https://raw.githubusercontent.com/CogStack/cogstack-platform-toolkit/85029d135b5bacfb473b638d82e45021ee67781a/observability/examples/full/exporters.docker-compose.yml)
- [exporters.elastic.docker-compose.yml](https://raw.githubusercontent.com/CogStack/cogstack-platform-toolkit/85029d135b5bacfb473b638d82e45021ee67781a/observability/examples/full/exporters.elastic.docker-compose.yml)

Downloads the configurations:

- [alloy/probers/probe-external.yml](https://raw.githubusercontent.com/CogStack/cogstack-platform-toolkit/85029d135b5bacfb473b638d82e45021ee67781a/observability/examples/full/alloy/probers/probe-external.yml)
- [alloy/probers/probe-observability.yml](https://raw.githubusercontent.com/CogStack/cogstack-platform-toolkit/85029d135b5bacfb473b638d82e45021ee67781a/observability/examples/full/alloy/probers/probe-observability.yml)
- [prometheus/scrape-configs/exporters/exporters.yml](https://raw.githubusercontent.com/CogStack/cogstack-platform-toolkit/85029d135b5bacfb473b638d82e45021ee67781a/observability/examples/full/prometheus/scrape-configs/exporters/exporters.yml)
- [prometheus/scrape-configs/recording-rules/slo.yml](https://raw.githubusercontent.com/CogStack/cogstack-platform-toolkit/85029d135b5bacfb473b638d82e45021ee67781a/observability/examples/full/prometheus/scrape-configs/recording-rules/slo.yml)



## Step 2: Understand the Folder structure

Your project configuration will be created with follow this structure:

```
observability.docker-compose.yml
exporters.docker-compose.yml
alloy/
    probers/           # HTTP endpoints to check availability
        blackbox-exporter/     # (Optional) Custom Probe configurations like auth details
prometheus/
    scrape-configs/
        exporters/         # Targets that expose metrics (e.g. Elasticsearch, Docker, VMs)
    recording-rules/       # Prometheus recording rules (e.g. for SLOs, summaries)
grafana/                   # (Optional) Custom Grafana dashboards and config
```

Inspect the results of the script and see that it matches this layout


## Step 3: Run the Stack
The files come with basic defaults, so we can now run the stack

   ```
   docker compose up -d
   ```

This will launch Prometheus, Grafana, and Alloy

Navigate to the dashboard urls on `http://localhost/grafana` to view the dashboards.


## Step 4: Create Site-Specific Probing files
You must provide your own scrape and recording rules to tell Prometheus what to monitor.

This is probably the hardest step: You will actually need to know what is running, and where it is! Building out these config files will give you that inventory, and give a real definition of what is running where.

- Probers: HTTP endpoints you want to monitor for availability
  - Add files in `alloy/probers/*.yml`
  - [Configure Probers](./probing.md)

- Recording Rules: Define uptime goals or custom aggregations
  - Add files in `recording-rules/*.yml`
  - [Enable Alerting](./alerting.md)

## Step 5: Run Grafana Alloy on every VM
The Grafana Alloy image needs to be run on each VM that you want to get information from. 

Use the example docker compose file in [exporters.docker-compose.yml](https://raw.githubusercontent.com/CogStack/cogstack-platform-toolkit/85029d135b5bacfb473b638d82e45021ee67781a/observability/examples/full/exporters.docker-compose.yml) which will start up alloy and get metrics

   ```
   docker compose -f exporters.docker-compose.yml up -d
   ```

See [Configure Telemetry](./telemetry.md) for the full details

---

## What’s Next?

Your observability stack is now monitoring your services, and you have a production ready project setup

You can now setup prometheus with any telemetry or probers required following the remaining steps in the Setup section.

For the last steps, you can:

- Run the exporters on all the VMs that you want access to 
- Deploy the stack in produciton
- Fully customise with [Customization](../customization/_index.md) section
- Look further into understanding the concepts and details in the Reference section
