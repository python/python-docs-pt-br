import os
from pathlib import Path
import re

absolute_path = Path(__file__).resolve().parents[2]
pattern_translated_strings = r'Translated:\s+(\d+)'


def run_git_command(command):
    try:
        return os.popen(command).read()
    except Exception as e:
        print(f"Error executing Git command: {e}")
        return ""


def get_translated_commit_strings(commit_hash):
    try:
        changed_files = run_git_command(f"git diff-tree --no-commit-id --name-only {commit_hash} -r").split("\n")
        changed_files.remove("")
        changed_count = 0
        for file in changed_files:
            file_path = absolute_path / file
            output = os.popen(f"pocount {file_path}").read()
            strings_match = re.search(pattern_translated_strings, output)
            matched_strings = int(strings_match.group(1)) if strings_match else 0
            changed_count += matched_strings
        return changed_count
    except Exception as e:
        print(f"Error getting translated strings count: {e}")
        return 0


def get_difference_between_translated_commits_strings(commit_hash1, commit_hash2):
    try:
        commit_hash1_count = get_translated_commit_strings(commit_hash1)
        commit_hash2_count = get_translated_commit_strings(commit_hash2)
        return abs(commit_hash1_count - commit_hash2_count)
    except Exception as e:
        print(f"Error calculating the difference between translated strings counts: {e}")
        return 0
