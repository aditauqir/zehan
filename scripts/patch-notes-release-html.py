#!/usr/bin/env python3
"""Generate Sparkle release-note HTML from PATCH_NOTES.md."""

from __future__ import annotations

import argparse
import html
import pathlib
import re


def markdown_inline_to_html(text: str) -> str:
    escaped = html.escape(text)
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", escaped)


def extract_version_entries(markdown: str, version: str) -> list[str]:
    heading_pattern = re.compile(r"^##\s+v?" + re.escape(version) + r"\s*$", re.MULTILINE)
    match = heading_pattern.search(markdown)
    if not match:
        return []

    next_heading = re.search(r"^##\s+", markdown[match.end():], re.MULTILINE)
    section_end = match.end() + next_heading.start() if next_heading else len(markdown)
    section = markdown[match.end():section_end]
    entries: list[str] = []

    for line in section.splitlines():
        stripped = line.strip()
        if stripped.startswith("- "):
            entries.append(stripped[2:].strip())

    return entries


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    parser.add_argument("--patch-notes", default="PATCH_NOTES.md")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    patch_notes_path = pathlib.Path(args.patch_notes)
    entries = extract_version_entries(patch_notes_path.read_text(errors="ignore"), args.version)
    if not entries:
        return 2

    title = html.escape(f"Zirn {args.version}")
    items = "\n".join(f"  <li>{markdown_inline_to_html(entry)}</li>" for entry in entries)
    output = f"<h2>{title}</h2>\n<ul>\n{items}\n</ul>\n"
    pathlib.Path(args.output).write_text(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
