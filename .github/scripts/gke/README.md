# GKE deployment test

Every pull request that touches the Helm charts is deployed to its own small GKE
cluster and left running, so reviewers can open the apps in a browser.

| | |
|---|---|
| Workflows | `.github/workflows/gke_deploy_test.yml`, `.github/workflows/gke_teardown.yml` |
| URLs | `https://<app>.pr-<number>.platform.cogstack.dev` for `trainer`, `jupyter`, `dashboards`, `medcat`, `anoncat`, `ocr` |
| Login | user `cogstack`; password: `gcloud secrets versions access latest --secret preview-basic-auth-password --project <project>` |
| Auth to Google Cloud | GitHub OIDC (Workload Identity Federation). No keys are stored anywhere. |

## How it works

There is no state file. The cluster for PR 123 is always called `pr-123`, and
every script derives what it needs from the PR number.

1. `cluster-up.sh` creates the cluster, or reuses it if a previous push already did.
2. `deploy.sh` installs Traefik and cert-manager, points `*.pr-<n>.platform.cogstack.dev`
   at the load balancer, obtains a wildcard certificate, then installs or upgrades
   `cogstack-ce-helm` from the PR and runs `helm test`.
3. `smoke-test.sh` requests every app over public HTTPS.
4. The check goes green and the cluster stays up.

Every route sits behind basic auth, because the charts ship demo passwords and
the URLs are public.

## Teardown

`teardown.sh` removes the workloads first (so Google deletes the load balancer
and disks), then the cluster, then the PR's DNS records. It runs:

- when the PR is closed or merged;
- by hand: run the `gke_teardown` workflow with a PR number, or `all`;
- hourly, for any environment whose PR is closed or that is older than
  `GKE_PR_MAX_AGE_HOURS` (repository variable, default 24). Re-run the deploy
  job to bring an expired environment back.

## Setup, and moving between repositories

`setup-gcp.sh` builds the Google Cloud project and is safe to re-run. Its
arguments are the repositories allowed to authenticate; each run replaces the
previous list.

```bash
GCP_ORG_ID=<org id> GCP_BILLING_ACCOUNT=<billing id> \
  .github/scripts/gke/setup-gcp.sh <owner>/<repo>
```

It prints the NS record to add to the parent DNS zone (needed once) and the
three `gh variable set` commands for the repository. The workflows do nothing
in a repository where those variables are not set.

To move the test to another repository:

1. Run the `gke_teardown` workflow with `all` in the old repository. PR numbers
   differ between repositories, so old environments must not be left behind.
2. Run `setup-gcp.sh <new owner>/<new repo>`.
3. Run the three `gh variable set` commands it prints.
4. To make the test block merging, add **GKE deployment test** as a required
   status check on the default branch.

## Limits

- Pull requests from forks and from Dependabot are skipped: they cannot obtain an OIDC token.
- The charts deploy published images, so this tests the charts, not unreleased application code.
