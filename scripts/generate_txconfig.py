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

def reset_tx_config(txconfig: Path):
    """Create or reset the .tx/config file with basic header."""
    txconfig.parent.mkdir(exist_ok=True)
    txconfig.write_text("[main]\nhost = https://www.transifex.com\n", encoding="utf-8")
    print("Initialized .tx/config.")


def populate_resources_from_remote(config_file: Path, tx_project: str):
    """Add the remote resources from the Transifex project to .tx/config."""
    result = subprocess.run([
        "tx", "--config", str(config_file), "add", "remote",
        "--file-filter", "<lang>/<resource_slug>.<ext>",
        f"https://app.transifex.com/python-doc/{tx_project}/"
    ], check=True)
    if result.returncode != 0:
        print("Failed to add the resources from remote:")
        print(result.stderr.strip())
        sys.exit(result.returncode)
    print("Added remote resources to Transifex.")


def patch_config(txconfig: Path):
    """Patch .tx/config to fixing PO filenames to match the expected."""
    content = txconfig.read_text(encoding="utf-8").splitlines()
    new_lines = []

    text_to_replace = {
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
        "xml_": "xml."
    }

    for line in content:
        if line.startswith(("source_file", "source_lang")):
            continue

        if line.startswith("file_filter"):
            line = line.replace("<lang>/", "")
            line = line.replace("--", "/")

            for pattern, replacement in text_to_replace.items():
               if pattern in line:
                  line = line.replace(pattern, replacement)
                  break

        new_lines.append(line)

    text = "\n".join(new_lines)

    txconfig.write_text(text + "\n", encoding="utf-8")
    print("Updated .tx/config with character substitutions")


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root-path",
        "-p",
        default=Path("."),
        help="Path to the translation files, and also the .tx/config"
    )
    parser.add_argument(
        "tx_project",
        help="Name of the Transifex project to query resources from (e.g. python-newest or python-313)"
    )
    return parser.parse_args()


def main():
    args = parse_args()
    TX_CONFIG = Path(".tx/config")
    if args.root_path:
        TX_CONFIG = args.root_path / TX_CONFIG
    reset_tx_config(TX_CONFIG)
    populate_resources_from_remote(TX_CONFIG, args.tx_project)
    patch_config(TX_CONFIG)


if __name__ == "__main__":
    main()
