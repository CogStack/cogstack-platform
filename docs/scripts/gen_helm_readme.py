from __future__ import annotations

from pathlib import Path

import mkdocs_gen_files  # type: ignore[import-not-found]


REPO_ROOT = Path(__file__).resolve().parents[2]
HELM_CHARTS_DIR = REPO_ROOT / "helm-charts"

# Output path is relative to MkDocs' `docs_dir` (configured in docs/mkdocs.yml).
OUTPUT_DIR = Path("platform/deployment/helm/charts")


def main() -> None:
    for chart_dir in sorted(HELM_CHARTS_DIR.iterdir(), key=lambda p: p.name):
        if not chart_dir.is_dir():
            continue

        readme_path = chart_dir / "README.md"
        if not readme_path.is_file():
            continue

        output_path = OUTPUT_DIR / f"{chart_dir.name}.md"

        # Copy README.md content verbatim into the docs page.
        with mkdocs_gen_files.open(output_path.as_posix(), "w") as f:
            f.write(readme_path.read_text(encoding="utf-8"))

        # Helps the "edit this page" link in themes that support it.
        mkdocs_gen_files.set_edit_path(
            output_path.as_posix(), readme_path.relative_to(REPO_ROOT)
        )


main()
