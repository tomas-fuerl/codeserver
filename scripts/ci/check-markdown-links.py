#!/usr/bin/env python3
"""Validate local Markdown link targets without network access."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

LINK_RE = re.compile(r"!?(?:\[[^\]]*\])\(([^)]+)\)")
EXTERNAL_SCHEMES = {"http", "https", "mailto", "tel"}


def destination_from(raw: str) -> str:
    value = raw.strip()
    if value.startswith("<") and ">" in value:
        return value[1 : value.index(">")]
    match = re.match(r"([^\s]+)(?:\s+['\"].*['\"])?$", value)
    return match.group(1) if match else value


def markdown_lines(path: Path):
    in_fence = False
    fence_marker = ""
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.lstrip()
        if stripped.startswith("```") or stripped.startswith("~~~"):
            marker = stripped[:3]
            if not in_fence:
                in_fence = True
                fence_marker = marker
            elif marker == fence_marker:
                in_fence = False
                fence_marker = ""
            continue
        if not in_fence:
            yield number, line


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    errors: list[str] = []
    checked = 0

    markdown_files = sorted(
        path
        for path in repo_root.rglob("*.md")
        if ".git" not in path.relative_to(repo_root).parts
    )

    for source in markdown_files:
        for line_number, line in markdown_lines(source):
            for match in LINK_RE.finditer(line):
                destination = destination_from(match.group(1))
                if not destination or destination.startswith("#"):
                    continue

                parsed = urlsplit(destination)
                if parsed.scheme.lower() in EXTERNAL_SCHEMES or parsed.netloc:
                    continue
                if parsed.scheme:
                    errors.append(
                        f"{source.relative_to(repo_root)}:{line_number}: "
                        f"unsupported local link scheme: {destination}"
                    )
                    continue

                decoded_path = unquote(parsed.path)
                if not decoded_path:
                    continue

                target = (source.parent / decoded_path).resolve()
                try:
                    target.relative_to(repo_root)
                except ValueError:
                    errors.append(
                        f"{source.relative_to(repo_root)}:{line_number}: "
                        f"link escapes repository: {destination}"
                    )
                    continue

                checked += 1
                if not target.exists():
                    errors.append(
                        f"{source.relative_to(repo_root)}:{line_number}: "
                        f"missing link target: {destination}"
                    )

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        print(
            f"Markdown link validation failed with {len(errors)} error(s).",
            file=sys.stderr,
        )
        return 1

    print(
        f"Markdown link validation passed: {len(markdown_files)} files, "
        f"{checked} local targets."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
