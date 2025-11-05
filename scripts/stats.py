#!/usr/bin/env python
"""
Obtain translation stats from the PO files directory and
store it with JSON format into 'stats.json'.
"""

import json
import os
import logging
from datetime import datetime, timezone
from pathlib import Path

from potodo.po_file import PoDirectory

logging.basicConfig(level=logging.INFO)


def main() -> None:
    """Main function to generate translation stats."""

    lang_dir = os.environ.get("PYDOC_LANG_DIR")
    if lang_dir:
        pofiles_path = Path(lang_dir)
    else:
        language = os.environ.get("PYDOC_LANGUAGE")
        if not language:
            raise ValueError("Environment variable PYDOC_LANGUAGE is not set.")
        pofiles_path = Path(f"cpython/Doc/locales/{language}/LC_MESSAGES")

    if not pofiles_path.exists():
        raise FileNotFoundError(f"Path does not exist: {pofiles_path}")

    # Check for PO files inside the pofiles_path
    if not list(pofiles_path.rglob("*.po")):
        raise FileNotFoundError(f"No PO files found in {pofiles_path}")

    stats = PoDirectory(pofiles_path, use_cache=False)
    stats.scan()

    stats_data = {
        "completion": str(round(stats.completion, 2)) + "%",
        "translated": stats.translated,
        "entries": stats.entries,
        "updated_at": datetime.now(timezone.utc).isoformat(timespec="seconds") + "Z",
    }

    stats_json = pofiles_path / "stats.json"
    try:
        with stats_json.open("w") as output_file:
            json.dump(stats_data, output_file)
        logging.info(f"Content written to {stats_json}")
    except IOError as e:
        logging.error(f"Failed to write to {stats_json}: {e}")
        raise


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        logging.error(f"An error occurred: {e}")
