#!/usr/bin/env python
"""
Manage translation for Python documentation
"""

# SPDX-License-Identifier: CC0-1.0


import argparse
import logging
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Optional

ROOTDIR = Path(__file__).resolve().parent.parent
COMMANDS = {
    "build",
}

# Logger configuration
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


def configure_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=COMMANDS, help="The command to execute")
    parser.add_argument(
        "--language", "-l", help="Language for the translated documentation"
    )
    parser.add_argument("--python-version", "-v", help="Python version to be used")
    parser.add_argument(
        "--logs-dir",
        "-L",
        default=ROOTDIR / "logs",
        help="Directory for logs (default: 'logs')",
    )
    parser.add_argument(
        "--cpython-path",
        "-c",
        default=ROOTDIR / "cpython",
        type=Path,
        help="Path to the CPython repository (default: 'cpython')",
    )
    return parser


def get_value(env_var_name: str, arg_value: Optional[str]) -> str:
    """
    Return value passed via command-line interface arguments *arg_value*,
    and if not passed, use the environment variable *env_var_name* instead.
    """

    value = arg_value or os.getenv(env_var_name)
    if not value:
        logger.error(
            f"The environment variable {env_var_name} is not defined, and no value was provided by the command line."
        )
        sys.exit(1)
    return value


def get_minor_version(version: str) -> int:
    """Return Python minor *version* assuming the schema as X.Y, e.g. 3.13"""
    return int(version.split(".")[1])


def build(language: str, version: str, logs_dir: Path, cpython_path: Path) -> None:
    minor_version = get_minor_version(version)
    warning_log = logs_dir / "sphinxwarnings.txt"

    # Sphinx options.
    # Append gettext_compact=False if python version is 3.11 or older,
    # because this confval was added to conf.py only in 3.12.
    opts = f"-E -D language={language} --keep-going -w {warning_log}"
    if minor_version < 12:
        opts += " -D gettext_compact=False"

    try:
        # Run the make command
        logger.info(
            f"Building documentation for language {language}, Python version {version}."
        )
        subprocess.run(
            ["make", "-C", cpython_path / "Doc", "html", f"SPHINXOPTS={opts}"],
            check=True,
        )
    except subprocess.CalledProcessError as e:
        logger.error(f"Error executing the make command: {e}")
        raise

    # Remove the warning log file if it is empty
    if warning_log.exists() and warning_log.stat().st_size == 0:
        warning_log.unlink()
        logger.info("The warning log file was empty and has been removed.")


def main() -> None:
    # Configure ArgumentParser
    parser = configure_parser()
    args = parser.parse_args()

    # Get values from environment variables or arguments
    language = get_value("PYDOC_LANGUAGE", args.language)
    version = get_value("PYDOC_VERSION", args.python_version)
    logs_dir = Path(get_value("PYDOC_LOGS", str(args.logs_dir)))
    cpython_path = args.cpython_path

    # Validate contents of the CPython local checkout
    conf_file = cpython_path / "Doc" / "conf.py"
    if not conf_file.exists():
        logger.error(
            f"Configuration file '{conf_file}' not found. Invalid CPython checkout directory."
        )
        sys.exit(1)

    # Check if the command is one of those that use Sphinx
    if args.command in [
        "build",
    ]:
        # make is required
        if not shutil.which("make"):
            logger.error("Executable 'make' not found, make sure it is installed.")
            sys.exit(1)

        # Create the logs directory if it doesn't exist
        logs_dir.mkdir(exist_ok=True)
        logger.info(f"Logs will be stored in the directory: {logs_dir}")

        if args.command == "build":
            # Build the documentation
            try:
                build(language, version, logs_dir, cpython_path)
                logger.info("Documentation built successfully.")
            except Exception as e:
                logger.error(f"Error building the documentation: {e}")
                raise


if __name__ == "__main__":
    main()
