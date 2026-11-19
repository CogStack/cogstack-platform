# Manual Quickstart
The quickstart page uses a script to setup the folders for you.

This page instead details how to do it manually, to provide clarity.

## Step 1: Setup directory
Create the necessary directory structure
```
mkdir -p observability-simple/alloy/probers
```

Download these two files, and place in the right folder

- [docker-compose.yml](https://raw.githubusercontent.com/CogStack/cogstack-platform/main/deployment/examples/observability/simple/docker-compose.yml) in observability-simple/
- [probe-observability.yml](https://raw.githubusercontent.com/CogStack/cogstack-platform/main/deployment/examples/observability/simple/alloy/probers/probe-observability.yml) into observability-simple/alloy/probers

### Step 2: Start the stack

In the folder containing the downloaded files, run:

```bash
docker compose up -d
```

### Step 3: Access the dashboards
Open your web browser and go to:

`http://localhost/grafana`

You should see the Grafana dashboard displaying the availability of the sample web page.

There it is, you can now see the availability of the cogstack homepage, as well as the observability stack
