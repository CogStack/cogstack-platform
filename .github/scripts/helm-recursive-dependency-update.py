#!/usr/bin/env python3
"""Update Helm chart dependencies in file://-safe order.

This script aims to recursively update the dependencies of all the charts, and ensure that all the subcharts get vendored into the parent chart.
When we publish a chart to dockerhub, we want to ensure that all the subcharts are included

For example:
medcat-trainer-helm depends on postgresql. 
When we publish this into dockerhub, it means that inside medcat-trainer-helm.tgz, there's a charts/postgresql.tgz file.

cogstack-ce-helm depends on medcat-trainer-helm
When we publish this into dockerhub, inside cogstack-ce-helm.tgz, we want to have a charts/medcat-trainer-helm.tgz file, and inside that file we should have charts/solr.tgz.

The complex part is that we are using the file:// path to depend on the subchart. This means we need to run `helm dependency update` in that folder specifically before we can reference it in the parent chart.
If we weren't using file:// but referencing the tar in dockerhub, there wouldnt be any issue.

Helm packages each chart independently and does not recurse into local subchart sources (see https://github.com/helm/helm/pull/30855).

Approach:
  1. Discover chart directories (Chart.yaml locations).
  2. Build a DAG of file:// dependencies between those charts.
  3. Topologically sort so dependencies come before dependents.
  4. Run `helm dependency update` in that order.

Usage (cwd should be helm-charts/):
  helm-recursive-dependency-update.py
  helm-recursive-dependency-update.py CHART [CHART ...]
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from collections import defaultdict, deque
from pathlib import Path

import yaml

FILE_URI_PREFIX = "file://"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "charts",
        nargs="*",
        help=(
            "Optional chart directory names under the current working directory. "
            "When omitted, every Chart.yaml under cwd is considered "
            "(excluding vendored copies under charts/)."
        ),
    )
    return parser.parse_args()


def is_vendored_chart_yaml(path: Path) -> bool:
    """Skip Chart.yaml files that live inside a Helm charts/ vendor tree."""
    return any(part == "charts" for part in path.parts)


def discover_chart_dirs(roots: list[Path]) -> set[Path]:
    """Return absolute chart directories under the given roots."""
    found: set[Path] = set()
    for root in roots:
        root = root.resolve()
        if not root.is_dir():
            raise FileNotFoundError(f"Chart path does not exist: {root}")
        for chart_yaml in root.rglob("Chart.yaml"):
            if is_vendored_chart_yaml(chart_yaml.relative_to(root)):
                continue
            found.add(chart_yaml.parent.resolve())
    return found


def load_chart_yaml(chart_dir: Path) -> dict:
    chart_yaml = chart_dir / "Chart.yaml"
    with chart_yaml.open(encoding="utf-8") as fh:
        data = yaml.safe_load(fh) or {}
    if not isinstance(data, dict):
        raise ValueError(f"Unexpected Chart.yaml contents in {chart_yaml}")
    return data


def file_dependency_dirs(chart_dir: Path) -> set[Path]:
    """Resolve local file:// dependency chart directories for one chart."""
    data = load_chart_yaml(chart_dir)
    deps = data.get("dependencies") or []
    resolved: set[Path] = set()
    for dep in deps:
        if not isinstance(dep, dict):
            continue
        repo = dep.get("repository") or ""
        if not isinstance(repo, str) or not repo.startswith(FILE_URI_PREFIX):
            continue
        rel = repo.removeprefix(FILE_URI_PREFIX)
        dep_dir = (chart_dir / rel).resolve()
        if not (dep_dir / "Chart.yaml").is_file():
            raise FileNotFoundError(
                f"{chart_dir.name} declares {repo} but {dep_dir}/Chart.yaml is missing"
            )
        resolved.add(dep_dir)
    return resolved


def chart_has_dependencies(chart_dir: Path) -> bool:
    deps = load_chart_yaml(chart_dir).get("dependencies") or []
    return bool(deps)


def expand_with_file_deps(seed_charts: set[Path]) -> set[Path]:
    """Include transitive file:// dependency sources of the seed charts."""
    all_charts = set(seed_charts)
    queue = deque(seed_charts)
    while queue:
        chart_dir = queue.popleft()
        for dep_dir in file_dependency_dirs(chart_dir):
            if dep_dir not in all_charts:
                all_charts.add(dep_dir)
                queue.append(dep_dir)
    return all_charts


def build_depends_on_graph(charts: set[Path]) -> dict[Path, set[Path]]:
    """Map each chart to the set of local charts it depends on (must run first)."""
    depends_on: dict[Path, set[Path]] = {chart: set() for chart in charts}
    for chart_dir in charts:
        for dep_dir in file_dependency_dirs(chart_dir):
            if dep_dir in charts:
                depends_on[chart_dir].add(dep_dir)
    return depends_on


def topological_sort(depends_on: dict[Path, set[Path]]) -> list[Path]:
    """Return charts ordered so every file:// dependency appears before its parent.

    Raises ValueError if the file:// graph contains a cycle.
    """
    remaining = {chart: set(deps) for chart, deps in depends_on.items()}
    dependents: dict[Path, set[Path]] = defaultdict(set)
    for chart, deps in remaining.items():
        for dep in deps:
            dependents[dep].add(chart)

    ready = deque(sorted((c for c, deps in remaining.items() if not deps), key=str))
    ordered: list[Path] = []

    while ready:
        chart = ready.popleft()
        ordered.append(chart)
        for child in sorted(dependents[chart], key=str):
            remaining[child].remove(chart)
            if not remaining[child]:
                ready.append(child)

    if len(ordered) != len(depends_on):
        cyclic = sorted(str(c) for c, deps in remaining.items() if deps)
        raise ValueError(
            "Cycle detected in file:// chart dependencies involving: "
            + ", ".join(cyclic)
        )
    return ordered


def helm_dependency_update(chart_dir: Path) -> None:
    print(f"Updating dependencies for {chart_dir}")
    subprocess.run(
        ["helm", "dependency", "update", str(chart_dir)],
        check=True,
    )


def main() -> int:
    args = parse_args()
    cwd = Path.cwd()

    if args.charts:
        roots = [cwd / name for name in args.charts]
    else:
        roots = [cwd]

    seed_charts = discover_chart_dirs(roots)
    charts = expand_with_file_deps(seed_charts)
    depends_on = build_depends_on_graph(charts)
    ordered = topological_sort(depends_on)

    print("Dependency update order:")
    for chart_dir in ordered:
        rel = chart_dir.relative_to(cwd) if chart_dir.is_relative_to(cwd) else chart_dir
        marker = "" if chart_has_dependencies(chart_dir) else " (no dependencies, skip)"
        print(f"  - {rel}{marker}")

    for chart_dir in ordered:
        if chart_has_dependencies(chart_dir):
            helm_dependency_update(chart_dir)

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (FileNotFoundError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
