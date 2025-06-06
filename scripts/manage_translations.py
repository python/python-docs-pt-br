#!/usr/bin/env python

# SPDX-License-Identifier: CC0-1.0

import argparse
import contextlib
import logging
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Optional

from sphinx_intl.transifex import create_txconfig, update_txconfig_resources

ROOTDIR = Path(__file__).resolve().parent.parent
COMMANDS = ["build", 'generate_templates']

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)


def configure_parser() -> argparse.ArgumentParser:
    """Configure and return the argument parser."""
    parser = argparse.ArgumentParser(description="Manage translation for Python documentation")
    parser.add_argument("command", choices=COMMANDS, help="The command to execute")
    parser.add_argument("-l", "--language", help="Language for the translated documentation")
    parser.add_argument("-v", "--python-version", help="Python version to be used")
    parser.add_argument("-L", "--logs-dir", default=ROOTDIR / "logs", type=Path, help="Directory for logs (default: 'logs' in root directory")
    parser.add_argument("-c", "--cpython-path", default=ROOTDIR / "cpython", type=Path, help="Path to the CPython repository (default: 'cpython' in root directory")
    parser.add_argument("-p", "--po-dir", type=Path, help="Path to the language team repository containing PO files (default: CPYTHON_PATH/Doc/locales/LANGUAGE/LC_MESSAGES")
    parser.add_argument('-t', '--tx-project', help="Name of the Transifex project under python-doc Transifex organization")
    return parser


def get_value(arg_value: Optional[str], arg_name: str, env_var_name: str) -> str:
    """Return a CLI argument or environment variable value."""
    value = arg_value or os.getenv(env_var_name)
    if not value:
        logger.error(f"'{arg_name}' not provided and the environment variable {env_var_name} is not set.")
        sys.exit(1)
    return value


def validate_cpython_path(cpython_path: Path) -> None:
    if not (cpython_path / "Doc" / "conf.py").exists():
        logger.error(f"Missing conf.py in {cpython_path}. Invalid CPython directory.")
        sys.exit(1)


def validate_po_dir(po_dir: Path) -> None:
    if not po_dir.exists() or not list(po_dir.glob("*.po")):
        logger.error(f"Invalid locale directory '{po_dir}'. No PO files found.")
        sys.exit(1)


def validate_tx_config(tx_config: str) -> None:
    if not re.match(r"python-(newest|\d+)", tx_config):
        logger.error(f"Invalid Transifex project name: {tx_config}")
        sys.exit(1)


# contextlib implemented chdir since Python 3.11 
@contextlib.contextmanager
def chdir(path: Path):
    """Temporarily change the working directory."""
    original_dir = Path.cwd()
    logger.info(path)
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(original_dir)


def build_docs(language: str, version: str, po_dir: Path, logs_dir: Path, cpython_path: Path) -> None:
    """Build the documentation using Sphinx."""
    warning_log = logs_dir / "sphinx_warnings_build_docs.txt"
    sphinx_opts = ["-E", "-Dgettext_compact=0", f"-Dlanguage={language}", "--keep-going", "-w", f"{warning_log}"]
    locale_dirs = cpython_path / "Doc/locales"
    target_locale_dir = cpython_path / "Doc/locales" / language / "LC_MESSAGES"

    # TODO Fix symlinking when po_dir is not equal to target_locale_dir
    #if not po_dir.relative_to(locale_dirs) and
    #   not target_locale_dir.readlink() == po_dir:
    #        if target_locale_dir.is_symlink():
    #             target_locale_dir.unlink() # remove only if it is a symlink
    #        if not target_locale_dir.exists() and not target_locale_dir.is_symlink():
    #        (locale_dirs / language).mkdir(parents=True, exist_ok=True)
    #        os.symlink(po_dir, target_locale_dir)

    try:
        logger.info(f"Building documentation for {language}, Python {version}.")
        subprocess.run([
            "make", "-C", str(cpython_path / "Doc"), "html", f"SPHINXOPTS={' '.join(sphinx_opts)}"
        ], check=True)

        if warning_log.exists() and not warning_log.stat().st_size:
            warning_log.unlink()
            logger.info("Removed empty warning log file.")

    except subprocess.CalledProcessError as e:
        logger.error(f"Make command failed: {e}")
        sys.exit(1)


def generate_templates(logs_dir: Path, cpython_path: Path, tx_project: str) -> None:
    """Generate translation template files (a.k.a. POT files) with Sphinx"""
    warning_log = logs_dir / "sphinx_warnings_generate_templates.txt"
    all_sphinx_opts = [
        "-E", "-b", "gettext", "-Dgettext_compact=0", "--keep-going",
        "-w", f"{warning_log}", "-d", "build/.doctrees-gettext", ".", "build/gettext"
    ]

    try:
        logger.info("Generating template files for Python docs.")
        subprocess.run([
            "make", "-C", str(cpython_path / "Doc"), "build", f"ALLSPHINXOPTS={' '.join(all_sphinx_opts)}"
        ], check=True)

        if warning_log.exists() and not warning_log.stat().st_size:
            warning_log.unlink()
            logger.info("Removed empty warning log file.")

    except subprocess.CalledProcessError as e:
        logger.error(f"Make command failed: {e}")
        sys.exit(1)

    with chdir(cpython_path / "Doc/locales"):
        logger.info("Updating Transifex's resources configuration file")
        Path(".tx/config").unlink(missing_ok=True)
        create_txconfig()
        update_txconfig_resources(
            transifex_organization_name='python-doc',
            transifex_project_name=tx_project,
            locale_dir=Path("."),
            pot_dir=Path("../build/gettext")
        )


def main() -> None:
    parser = configure_parser()
    args = parser.parse_args()

    # Set and require variable depending on the command issued by the user
    cpython_path = args.cpython_path
    logs_dir = Path(get_value(str(args.logs_dir), "--logs-dir", "PYDOC_LOGS"))

    if args.command == "generate_templates":
        tx_project = get_value(args.tx_project, "--tx-project", "PYDOC_TX_PROJECT")

    if args.command == "build":
        language = get_value(args.language, "--language", "PYDOC_LANGUAGE")
        version = get_value(args.python_version, "--python-version", "PYDOC_VERSION")
        po_dir = args.po_dir.absolute() if args.po_dir else cpython_path / f"Doc/locales/{language}/LC_MESSAGES"

    if args.command in ["build", "generate_templates"]:
        if not shutil.which("make"):
            logger.error("'make' not found. Please install it.")
            sys.exit(1)

        logs_dir.mkdir(exist_ok=True)
        logger.info(f"Logs will be stored in: {logs_dir}")

        if args.command == "build":
            validate_cpython_path(cpython_path)
            validate_po_dir(po_dir)
            build_docs(language, version, po_dir, logs_dir, cpython_path)
            logger.info("Documentation build completed successfully.")
        elif args.command == "generate_templates":
            validate_cpython_path(cpython_path)
            validate_tx_config(tx_project)
            generate_templates(logs_dir, cpython_path, tx_project)


if __name__ == "__main__":
    main()

