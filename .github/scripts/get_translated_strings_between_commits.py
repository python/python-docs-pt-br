import subprocess
from pathlib import Path
import re

absolute_path = Path(__file__).resolve().parents[2]
pattern_translated_strings = r'Translated:\s+(\d+)'


def run_os_command(command):
    try:
        return subprocess.check_output(command, shell=True, text=True)
    except subprocess.CalledProcessError as e:
        print(f"Error executing command '{command}': {e}")
        return None


def get_translated_commit_strings(commit_hash):
    run_os_command(f"git switch --force {commit_hash} --detach")
    pocount_of_commit = run_os_command(f"pocount {absolute_path}/*.po {absolute_path}/**/*.po")
    all_translated_results = re.findall(pattern_translated_strings, pocount_of_commit, re.DOTALL)
    total_of_translated_commit_strings = int(all_translated_results[-1])
    return total_of_translated_commit_strings


def get_difference_between_translated_commits_strings(commit_hash1, commit_hash2):
    commit_hash1_count = get_translated_commit_strings(commit_hash1)
    commit_hash2_count = get_translated_commit_strings(commit_hash2)
    return commit_hash1_count - commit_hash2_count
