from __future__ import annotations

"""
mkdocs-gen-files generator: zip archives from repository folders.

Each zip is written under `docs_dir` so MkDocs publishes it as a static download.

Configuration:
`ZIP_SPECS` is a list of dicts with:
- `sourceFolderPath`: directory under the repository root to archive (recursive)
- `outputZipPath`: path (relative to MkDocs `docs_dir`) for the `.zip` file
"""

import io
import zipfile
from pathlib import Path

import mkdocs_gen_files  # type: ignore[import-not-found]


REPO_ROOT = Path(__file__).resolve().parents[2]

ZIP_SPECS = [
    {
        "sourceFolderPath": "deployment-examples",
        "outputZipPath": "assets/downloads/deployment-examples.zip",
    },
]


def main() -> None:
    """Build configured zips and register them with the MkDocs virtual file tree."""
    for spec in ZIP_SPECS:
        source_rel = spec["sourceFolderPath"]
        output_rel = spec["outputZipPath"]

        source_dir = REPO_ROOT / source_rel
        if not source_dir.is_dir():
            raise FileNotFoundError(f"Source directory not found: {source_dir}")

        root_name = source_dir.name
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
            for path in sorted(source_dir.rglob("*"), key=lambda p: p.as_posix()):
                if not path.is_file():
                    continue
                arcname = Path(root_name) / path.relative_to(source_dir)
                zf.write(path, arcname.as_posix())

        out = Path(output_rel)
        with mkdocs_gen_files.open(out.as_posix(), "wb") as f:
            f.write(buf.getvalue())
        mkdocs_gen_files.set_edit_path(out.as_posix(), source_dir.relative_to(REPO_ROOT))


main()
