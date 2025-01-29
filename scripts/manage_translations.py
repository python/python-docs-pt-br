#!/usr/bin/env python

# SPDX-License-Identifier: CC0-1.0

import argparse
import contextlib
import logging
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Optional

ROOTDIR = Path(__file__).resolve().parent.parent
COMMANDS = ["build"]

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)


def configure_parser() -> argparse.ArgumentParser:
    """Configure and return the argument parser."""
    parser = argparse.ArgumentParser(description="Manage translation for Python documentation")
    parser.add_argument("command", choices=COMMANDS, help="The command to execute")
    parser.add_argument("-l", "--language", help="Language for the translated documentation")
    parser.add_argument("-v", "--python-version", help="Python version to be used")
    parser.add_argument("-L", "--logs-dir", default=ROOTDIR / "logs", type=Path, help="Directory for logs")
    parser.add_argument("-c", "--cpython-path", default=ROOTDIR / "cpython", type=Path, help="Path to the CPython repository")
    return parser


def get_value(env_var_name: str, arg_value: Optional[str]) -> str:
    """Return a CLI argument or environment variable value."""
    value = arg_value or os.getenv(env_var_name)
    if not value:
        logger.error(f"The environment variable {env_var_name} is not defined, and no value was provided.")
        sys.exit(1)
    return value


def get_minor_version(version: str) -> int:
    """Return the minor version number from a version string (e.g., '3.13')."""
    try:
        return int(version.split(".")[1])
    except (IndexError, ValueError) as e:
        logger.error(f"Invalid version format '{version}': {e}")
        sys.exit(1)


def build_docs(language: str, version: str, logs_dir: Path, cpython_path: Path) -> None:
    """Build the documentation using Sphinx."""
    minor_version = get_minor_version(version)
    warning_log = logs_dir / "sphinxwarnings.txt"

    sphinx_opts = f"-E -D language={language} --keep-going -w {warning_log}"
    if minor_version < 12:
        sphinx_opts += "-D gettext_compact=False"

    try:
        logger.info(f"Building documentation for {language}, Python {version}.")
        subprocess.run([
            "make", "-C", str(cpython_path / "Doc"), "html", f"SPHINXOPTS={sphinx_opts}"
        ], check=True)

        if warning_log.exists() and not warning_log.stat().st_size:
            warning_log.unlink()
            logger.info("Empty warning log file removed.")

    except subprocess.CalledProcessError as e:
        logger.error(f"Make command failed: {e}")
        sys.exit(1)


def validate_paths(cpython_path: Path) -> None:
    """Validate necessary paths for handling documentation."""
    if not (cpython_path / "Doc" / "conf.py").exists():
        logger.error(f"Missing conf.py in {cpython_path}. Invalid CPython directory.")
        sys.exit(1)


def main() -> None:
    parser = configure_parser()
    args = parser.parse_args()

    language = get_value("PYDOC_LANGUAGE", args.language)
    version = get_value("PYDOC_VERSION", args.python_version)
    logs_dir = Path(get_value("PYDOC_LOGS", str(args.logs_dir)))
    cpython_path = args.cpython_path

    validate_paths(cpython_path)

    if args.command == "build":
        if not shutil.which("make"):
            logger.error("'make' not found. Please install it.")
            sys.exit(1)

        logs_dir.mkdir(exist_ok=True)
        logger.info(f"Logs will be stored in: {logs_dir}")

        build_docs(language, version, logs_dir, cpython_path)
        logger.info("Documentation build completed successfully.")


if __name__ == "__main__":
    main()

