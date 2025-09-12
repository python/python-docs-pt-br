#!/usr/bin/env python
"""
Generate a commit message
Parses staged files and generates a commit message with Last-Translator's as
co-authors.
Based on Stan Ulbrych's implementation for Python Doc' Polish team
"""

import argparse
import contextlib
import os
from subprocess import run, CalledProcessError
from pathlib import Path

from polib import pofile, POFile


def generate_commit_msg():
    translators: set[str] = set()

    result = run(
        ["git", "diff", "--cached", "--name-only", "--diff-filter=ACM"],
        capture_output=True,
        text=True,
        check=True,
    )
    staged = [
        filename for filename in result.stdout.splitlines() if filename.endswith(".po")
    ]

    for file in staged:
        staged_file = run(
            ["git", "show", f":{file}"], capture_output=True, text=True, check=True
        ).stdout
        try:
            old_file = run(
                ["git", "show", f"HEAD:{file}"],
                capture_output=True,
                text=True,
                check=True,
            ).stdout
        except CalledProcessError:
            old_file = ""

        new_po = pofile(staged_file)
        old_po = pofile(old_file) if old_file else POFile()
        old_entries = {entry.msgid: entry.msgstr for entry in old_po}

        for entry in new_po:
            if entry.msgstr and (
                entry.msgid not in old_entries
                or old_entries[entry.msgid] != entry.msgstr
            ):
                # Prevent failure on missing Last-Translator field.
                # Transifex only adds Last-Translator if someone from
                # the team translated. If it was uploaded by an account
                # that is not in the team, this field will be missing.
                translator = (
                    (new_po.metadata.get("Last-Translator") or "").split(",")[0].strip()
                )
                if translator:
                    translators.add(f"Co-Authored-By: {translator}")
                break

    print("Update translation\n\n" + "\n".join(translators))


# contextlib implemented chdir since Python 3.11
@contextlib.contextmanager
def chdir(path: Path):
    """Temporarily change the working directory."""
    original_dir = Path.cwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(original_dir)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate commit message with translators as co-authors."
    )
    parser.add_argument(
        "path",
        type=Path,
        nargs="?",
        default=".",
        help="Path to the Git repository (default: current directory)",
    )
    args = parser.parse_args()

    with chdir(args.path):
        generate_commit_msg()
