import os
from pathlib import Path
import re
from git import Repo

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
        run_git_command(f"git switch {commit_hash} --detach")
        output = os.popen(f"pocount {absolute_path}/*.po {absolute_path}/**/*.po").read()
        all_translated_results = re.findall(pattern_translated_strings, output, re.DOTALL)
        translated_commit_strings = int(all_translated_results[-1])
        return translated_commit_strings
    except Exception as e:
        print(f"Error getting translated strings count: {e}")
        return 0


def get_difference_between_translated_commits_strings(commit_hash1, commit_hash2):
    try:
        commit_hash1_count = get_translated_commit_strings(commit_hash1)
        commit_hash2_count = get_translated_commit_strings(commit_hash2)
        return commit_hash1_count - commit_hash2_count
    except Exception as e:
        print(f"Error calculating the difference between translated strings counts: {e}")
        return 0


hash1 = "69ff2f8a3141f5aad0f968e76675830a158660c6"
hash2 = "fa5d1cea27abe701398ee8fe7ee5ba285fafeee2"

print(get_difference_between_translated_commits_strings(hash1, hash2))
