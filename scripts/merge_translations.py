#!/usr/bin/env python3
"""
Merge PO files from a source directory into a target directory using pomerge.
"""

import argparse
import os
import sys
from pathlib import Path

from pomerge import pomerge


def check_directory(path: Path) -> Path:
    """Check if the given path is an existing and readable directory."""
    if not path.is_dir():
        sys.exit(f"Error: '{path}' is not a valid directory.")
    if not os.access(path, os.R_OK):
        sys.exit(f"Error: '{path}' is not readable.")
    return path


def list_po_files(path: Path) -> list[Path]:
    """Return a list of PO files inside the path."""
    return list(path.rglob("*.po"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--no-overwrite",
        "-n",
        action="store_true",
        help="When applying translation, "
        "do not overwrite existing translations (apply only to untranslated or fuzzy ones).",
    )
    parser.add_argument("source", type=Path, help="Directory to merge PO files from")
    parser.add_argument("target", type=Path, help="Directory to merge PO files into")

    args = parser.parse_args()

    source_dir = check_directory(args.source)
    target_dir = check_directory(args.target)

    source_po_files = list_po_files(source_dir)
    target_po_files = list_po_files(target_dir)

    print(f"Merging translations from {source_dir} into {target_dir}... ")
    pomerge.merge_po_files(
        source_po_files, target_po_files, overwrite=not args.no_overwrite
    )


if __name__ == "__main__":
    main()
