#!/usr/bin/env python3
# List PO files that no longer have a corresponding page in Python docs

import os
import os.path
import sys
import subprocess

def run(cmd):
  return subprocess.check_output(cmd, shell=True, text=True)

# Set POT root directory from command-line argument or hardcoded, then test it
pot_root = 'cpython/Doc/locales/pot/'

if len(sys.argv) > 1:
  pot_root = sys.argv[0]

if not os.path.isdir(pot_root):
  print(f'Unable to find the POT directory {pot_root}')
  exit(1)

# List PO files tracked by git
po_files = run('git ls-files | grep .po | tr "\n" " "').split()

# Compare po vs pot, store po without corresponding pot
to_remove = []
for file in sorted(po_files):
  pot = os.path.join(pot_root, file + 't')
  if not os.path.isfile(pot):
    to_remove.append(file)

# Exit if no obsolete, or print obsoletes files.
# If running in GitHub Actions, add a problem matcher to bring up the attention
if len(to_remove) == 0:
  exit
else:
  matcher = ""
  if 'CI' in os.environ:
    matcher = '::error::'
  print(f'{matcher}The following files are absent in the documentation, hence they should be removed:\n')
  for file in to_remove:
    print(f'{matcher}  ' + file)
  print("")
