---
name: add-to-release-please
description: >-
  Register a package in release-please by updating release-please-config.json
  and .release-please-manifest.json, and aligning publish workflows to the new
  tag prefix. Use when adding an app, Helm chart, or package to release-please,
  onboarding a new release path, or when the user mentions release-please
  config or manifest.
---

# Add to release-please

Register a package so release-please can version it, write changelogs, and create tags/releases.

## When to Use

- Adding an app, library, or Helm chart to release-please
- Onboarding a new release path in this monorepo
- Updating release-please config or manifest for a new package

## Instructions

### 1. Work out the path

Work out the path to use, or ask the user what path to use.

The path is the package key in both config files (repo-relative directory). Confirm it exists and is not already in `release-please-config.json`.

| Kind | Path examples |
|---|---|
| App | `cogstack-cohorter` |
| Helm chart | `helm-charts/medcat-service-helm` |

Helm charts in this repo are top-level directories under `helm-charts/<chart>/` with a `Chart.yaml`. The package key is that directory. See [Helm charts](#helm-charts) before editing.

### 2. Update `release-please-config.json`

Update `release-please-config.json` with the path. Work out the release-type. It's probably `python`, `helm`, `node`, or `simple`.

Add under `packages`. Match the file's 4-space indent.

```json
"<path>": {
    "release-type": "<python|node|helm|simple>",
    "component": "<tag-prefix>",
    "changelog-path": "CHANGELOG.md",
    "bump-minor-pre-major": false,
    "bump-patch-for-minor-pre-major": false,
    "draft": false,
    "prerelease": false
}
```

**`release-type`:**

| Type | When | Bumps |
|---|---|---|
| `python` | Root `pyproject.toml` | `$.project.version` |
| `node` | Root `package.json` | `version` |
| `helm` | Chart dir with `Chart.yaml` | `version` |
| `simple` | No single root version file, or nested API + frontend | CHANGELOG only; use `extra-files` for nested bumps |

`component` is the git tag prefix: `{component}-v{version}` (e.g. `cohorter-v0.7.0`). For Helm charts in this repo, `component` is the package path (`helm-charts/<chart>`), so the tag is `helm-charts/<chart>-v<version>`.

**`extra-files`** (paths relative to the package directory) — e.g. python API + node frontend under `simple`:

```json
"extra-files": [
    {
        "type": "toml",
        "path": "api/pyproject.toml",
        "jsonpath": "$.project.version"
    },
    {
        "type": "json",
        "path": "frontend/package.json",
        "jsonpath": "$.version"
    }
]
```

### Helm charts

Copy an existing chart entry such as `helm-charts/medcat-service-helm`. Charts here always use `release-type` `helm`, `component` equal to the package key, and these changelog sections. Do not add `extra-files`.

`<chart>` is the directory name (for example `ocr-service-helm`). It must match `name` in `Chart.yaml`, and `Chart.yaml` must sit directly under `helm-charts/` (not nested).

```json
"helm-charts/<chart>": {
    "release-type": "helm",
    "component": "helm-charts/<chart>",
    "changelog-path": "CHANGELOG.md",
    "bump-minor-pre-major": false,
    "bump-patch-for-minor-pre-major": false,
    "draft": false,
    "prerelease": false,
    "changelog-sections": [
        { "type": "feat", "section": "Features" },
        { "type": "fix", "section": "Bug Fixes" },
        { "type": "build", "section": "Dependencies" },
        { "type": "refactor", "section": "Code Refactoring" },
        { "type": "revert", "section": "Reverts" }
    ]
}
```

`.github/workflows/kubernetes-charts-build.yaml` already discovers every `helm-charts/*/Chart.yaml` and publishes tags matching `helm-charts/*-v*.*.*`. Do not add a workflow or edit `release-please.yml` for a chart that fits this layout. Release-please writes `CHANGELOG.md` on the first release.

### 3. Update `.release-please-manifest.json`

Update `.release-please-manifest.json` by finding the most recent version based on the tags in git.

The manifest value is the **last released** version. The next tag is a bump from that version (`0.1.0` plus a `feat` commit becomes `0.2.0`).

1. `git tag -l '*<name>*' | sort -V`
2. Take the highest semver; strip the prefix (`helm-charts/medcat-service-helm-v0.6.0` → `0.6.0`)
3. If the user states a version, confirm it against git tags
4. If tags exist, add `"<path>": "<version>"` (same path key as in the config)
5. If there are no tags, the package has never been released. Set the manifest to `0.0.0` and set `initial-version` on the package to the first tag you want (for example `"initial-version": "0.1.0"`). `0.0.0` is not treated as a prior release, so the first release is `initial-version` rather than a bump. Without `initial-version`, that first release defaults to `1.0.0`. Do not copy `Chart.yaml` `version` into the manifest for an unreleased chart.

### 4. Update GitHub workflows if the tag format changes

Skip this step for a Helm chart registered as in [Helm charts](#helm-charts). The shared chart workflow already matches `helm-charts/*-v*.*.*`.

For other packages, release-please tags are `{component}-v{version}`. If workflows still match an old prefix that uses a forward slash (e.g. `cogstack-cohorter/v*`):

1. `on.push.tags` → `{component}-v*`
2. Version strip / docker metadata patterns → after `{component}-v`
3. Attach artifacts to the release-please GitHub Release (do not create a draft release)

```bash
rg -n '<old-prefix>|tags:' .github/workflows/<package>*
```

### Done when

- [ ] Path chosen (or confirmed with user)
- [ ] `packages` entry in `release-please-config.json`
- [ ] Helm charts use the path, `component`, and `changelog-sections` from [Helm charts](#helm-charts)
- [ ] Manifest entry is the latest git tag, or `0.0.0` plus `initial-version` when the package has never been released
- [ ] Workflows updated if the tag prefix changed, except Helm charts that already match `helm-charts/*-v*.*.*`
