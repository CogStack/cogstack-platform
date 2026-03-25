# QuickStart

This tutorial guides you through running the simplest setup of the observability stack using example configuration files and Docker Compose.

After completing these steps, you will have a full observability stack running locally, showing the availability of web pages you want to target

## Requirements

- Docker installed ([install Docker](https://docs.docker.com/get-docker/))
- Docker Compose installed ([install Docker Compose](https://docs.docker.com/compose/install/))
- A terminal with network access

## Steps

### Step 1: Run the Quickstart script

Run this quickstart script to setup the project
```bash
curl https://raw.githubusercontent.com/CogStack/cogstack-platform-toolkit/85029d135b5bacfb473b638d82e45021ee67781a/observability/examples/simple/quickstart.sh | bash
```
Now go to "http://localhost/grafana" to see the dashboards

Thats everything. The stack is running and you can see the availability.

If you can't use the script, see the [Manual Quickstart](../reference/quickstart-manual.md) to setup your own files. 


### Optional Step: Probe your own web page
Now you can look at getting monitoring of your own page

1. In your current folder, in the file `alloy/probers/probe-observability.yml` add the following yml to the bottom of the file:

```yaml
- targets:
    - https://google.com
  labels:
    name: google
    job: probe-my-own-site
```

Note to be careful of the indentation in yml, this target must be at the same depth as the existing contents. 

2. Restart the containers with:
```
docker compose restart
```

Now refresh the grafana dashboard, and you can see the availability of google.com, it's probably 100%!

## Next steps
This is the end of this quickstart tutorial, that enables probing availability of endpoints.

For the next steps we can:

- Look deeper into the observability dashboards, on [Dashboards Userguide](./userguide-tutorial.md)
- Productionise our deployment to enable further features  by following [Production Setup](../setup/production-setup.md)





