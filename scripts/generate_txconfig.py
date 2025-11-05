#!/usr/bin/env python3
"""
Generate the .tx/config file based on the existing projects
in Python docs Transifex project. Takes an project slug as
positional argument, e.g. python-newest or python-313
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

# Replaces required to fix the default values set by 'tx add remote' command.
# Add or remove
TEXT_TO_REPLACE = {
    "2_": "2.",
    "3_": "3.",
    "glossary_": "glossary",
    "collections_": "collections.",
    "compression_": "compression.",
    "concurrent_": "concurrent.",
    "curses_": "curses.",
    "email_": "email.",
    "html_": "html.",
    "http_": "http.",
    "importlib_resources_": "importlib.resources.",
    "importlib_": "importlib.",
    "logging_": "logging.",
    "multiprocessing_": "multiprocessing.",
    "os_": "os.",
    "string_": "string.",
    "sys_monitoring": "sys.monitoring",
    "tkinter_": "tkinter.",
    "unittest_": "unittest.",
    "urllib_": "urllib.",
    "xml_dom_": "xml.dom.",
    "xml_etree_": "xml.etree.",
    "xmlrpc_": "xmlrpc.",
    "xml_sax_": "xml.sax.",
    "xml_": "xml.",
}


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root-path",
        "-p",
        default=Path("."),
        help="Path to the translation files, and also the .tx/config (defaults to current directory)",
    )
    parser.add_argument(
        "tx_project", help="Slug of the Transifex project to query resources from"
    )
    return parser.parse_args()


def reset_tx_config(txconfig: Path):
    """Create or reset the .tx/config file with basic header."""
    txconfig.parent.mkdir(exist_ok=True)
    txconfig.write_text("[main]\nhost = https://www.transifex.com\n", encoding="utf-8")
    print("Initialized .tx/config.")


def populate_resources_from_remote(config_file: Path, tx_project: str):
    """Add the remote resources from the Transifex project to .tx/config."""
    result = subprocess.run(
        [
            "tx",
            "--config",
            str(config_file),
            "add",
            "remote",
            "--file-filter",
            "<lang>/<resource_slug>.<ext>",
            f"https://app.transifex.com/python-doc/{tx_project}/",
        ],
        check=True,
    )
    if result.returncode != 0:
        print("Failed to add the resources from remote:")
        print(result.stderr.strip())
        sys.exit(result.returncode)
    print("Added remote resources to Transifex.")


def patch_config(txconfig: Path):
    """Patch .tx/config to fixing PO filenames to match the expected."""
    content = txconfig.read_text(encoding="utf-8").splitlines()
    new_lines = []

    for line in content:
        if line.startswith(("source_file", "source_lang")):
            continue

        if line.startswith("file_filter"):
            line = line.replace("<lang>/", "")
            line = line.replace("--", "/")

            for pattern, replacement in TEXT_TO_REPLACE.items():
                if pattern in line:
                    line = line.replace(pattern, replacement)
                    break

        new_lines.append(line)

    text = "\n".join(new_lines)

    txconfig.write_text(text + "\n", encoding="utf-8")
    print("Updated .tx/config with character substitutions")


def main():
    args = parse_args()
    config_path = Path(".tx/config")
    if args.root_path:
        config_path = args.root_path / config_path
    reset_tx_config(config_path)
    populate_resources_from_remote(config_path, args.tx_project)
    patch_config(config_path)


if __name__ == "__main__":
    main()
