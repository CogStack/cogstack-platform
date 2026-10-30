Reusable terraform modules for CogStack deployments.

These modules should not be limited to a specific deployment or contain secrets.

## Generating module docs

Modules that use [terraform-docs](https://github.com/terraform-docs/terraform-docs) keep a `.terraform-docs.yml` and inject generated Requirements, Providers, Resources, Inputs, and Outputs between `<!-- BEGIN_TF_DOCS -->` and `<!-- END_TF_DOCS -->` in the module README.

From the module directory:

```bash
docker run --rm --volume "$(pwd):/terraform-docs" -u $(id -u) quay.io/terraform-docs/terraform-docs:0.24.0 markdown /terraform-docs
```

If that tag is missing for your architecture, use `quay.io/terraform-docs/terraform-docs:0.24.0-amd64` (or `-arm64`) instead.

