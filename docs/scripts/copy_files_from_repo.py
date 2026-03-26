from __future__ import annotations

"""
mkdocs-gen-files generator for static CogStack AI assets.

This script copies configured notebook files from the repository into the
MkDocs build output (relative to `docs_dir`).

Configuration:
`COPY_SPECS` is a list of dicts with:
- `sourceFilePath`: path to the repo file to copy
- `outputFilePath`: path (relative to MkDocs' `docs_dir`) to write into
"""

from pathlib import Path

import mkdocs_gen_files  # type: ignore[import-not-found]


REPO_ROOT = Path(__file__).resolve().parents[2]

# Add more entries here to copy additional static files into documentation.
COPY_SPECS = [
    {
        "sourceFilePath": "helm-charts/cogstack-helm-ce/charts/jupyterhub/examples/medcat-service-tutorial.ipynb",
        "outputFilePath": "platform/cogstack-ai/medcat-service-tutorial.ipynb",
    },
    {
        "sourceFilePath": "helm-charts/cogstack-helm-ce/charts/jupyterhub/examples/medcat-opensearch-e2e.ipynb",
        "outputFilePath": "cogstack-ce/tutorial/medcat-opensearch-e2e.ipynb",
    },
]


def main() -> None:
    """Copy configured files into the MkDocs virtual filesystem."""
    for spec in COPY_SPECS:
        source_rel = spec["sourceFilePath"]
        output_rel = spec["outputFilePath"]

        source_path = REPO_ROOT / source_rel
        if not source_path.is_file():
            raise FileNotFoundError(f"Source file not found: {source_path}")

        output_path = Path(output_rel)

        # Write bytes so formats like .ipynb are preserved exactly.
        with mkdocs_gen_files.open(output_path.as_posix(), "wb") as f:
            f.write(source_path.read_bytes())


main()
