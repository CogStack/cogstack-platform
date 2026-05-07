"""MkDocs-Macros definitions (see https://mkdocs-macros-plugin.readthedocs.io/)."""

from __future__ import annotations

from fnmatch import fnmatch
from pathlib import Path


def define_env(env):
    """Register Jinja macros available as {{ macro_name(...) }} in Markdown."""

    repo_root = Path(__file__).resolve().parent.parent

    @env.macro
    def cogstack_banner_logo() -> str:
        """Inline SVG for the tech-stack banner (avoids late <img> fetch vs emoji icons)."""
        docs_dir = Path(env.conf.docs_dir)
        path = docs_dir / "assets" / "brand-logo-dark.svg"
        svg = path.read_text(encoding="utf-8").strip()
        if svg.startswith("<?xml"):
            svg = svg.split("?>", 1)[-1].strip()
        return (
            f'<span class="tech-stack-banner__logo-svg" role="img" aria-label="CogStack">{svg}</span>'
        )

    @env.macro
    def embed_all_files_in_directory_as_snippets(
        folder: str,
        patterns: str = "*.tf,*.hcl,*.yml,*.yaml",
    ) -> str:
        """
        Emit pymdownx **tabbed** blocks with **snippets** for every matching file under a directory.

        ``folder`` is relative to the repo ``deployment-examples/`` directory. Snippet paths match
        that layout; ensure ``pymdownx.snippets`` ``base_path`` includes ``../deployment-examples``.

        ``patterns`` is a comma-separated list of globs matched against the **basename**
        (e.g. ``*.tf`` or ``*`` for every file). Hidden files (names starting with ``.``) are skipped.
        """
        root = repo_root / "deployment-examples" / folder
        if not root.is_dir():
            raise FileNotFoundError(
                f"embed_all_files_in_directory_as_snippets: not a directory: {root}"
            )

        globs = [p.strip() for p in patterns.split(",") if p.strip()]
        if not globs:
            globs = ["*"]

        def include_file(path: Path) -> bool:
            if path.name.startswith("."):
                return False
            return any(fnmatch(path.name, g) for g in globs)

        paths = sorted(
            (p for p in root.rglob("*") if p.is_file() and include_file(p)),
            key=lambda p: p.as_posix(),
        )
        if not paths:
            return "_No matching files found._"

        blocks: list[str] = []
        deploy_root = repo_root / "deployment-examples"
        for path in paths:
            rel = path.relative_to(deploy_root).as_posix()
            title = path.relative_to(root).as_posix()
            language = _fence_language(path.suffix)
            inner_indent = "    "
            blocks.append(f'=== "{title}"')
            blocks.append(f"{inner_indent}```{language}")
            blocks.append(f'{inner_indent}--8<-- "{rel}"')
            blocks.append(f"{inner_indent}```")
            blocks.append("")

        return "\n".join(blocks).rstrip() + "\n"


def _fence_language(suffix: str) -> str:
    return {
        ".tf": "hcl",
        ".hcl": "hcl",
        ".yml": "yaml",
        ".yaml": "yaml",
        ".json": "json",
        ".md": "markdown",
        ".sh": "bash",
        ".txt": "text",
    }.get(suffix.lower(), "text")
