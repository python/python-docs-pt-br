#!/usr/bin/python3
# Extract translation credits from the PO files within the directory

from pathlib import Path

# Get all PO files in the current directory and its subdirectories
p = Path(r'.').glob('**/*.po')
pofiles = list(p)

translators_credits_set = set()

# Exclude bot account, duplicated entry and hashes for deleted accounts
ignore_entries = [
    'i17obot <i17obot@rougeth.com>',
    'Willian Lopes',
    '01419cbcade949a3bc5433893a160e74',
    '2c4b5a73177ea5ea1d3324f10df471a7_b8aeba7 <7df8a60bac356f3b148ac94f3c2796f6_834576>',
    '82596da39877db21448335599650eb68_ac09920 <1d2e18e2f37f0ba6c4f06b239e0670bd_848591>',
]

for po in pofiles:
    with po.open() as f:
    
        # If true, it means it is between "# Translators:\n" and "#\n",
        # and it is a translator credit. Start with False
        is_translator_credits = False
    
        # Start looping through the file, line by line, looking for the
        # translation credits block, and then quit without going any
        # further down.
        for line in f:

            # if true, translator credits block finished; quit file
            if line == '#\n' and is_translator_credits:
                break

            # if true, we are in the translator credits block; extract info
            if is_translator_credits:
                # remove leading sharp sign, and trailing comma and year
                line = line.strip('# ')
                line = line[:-7]
                
                # Skip entries we do not want to add
                if line in ignore_entries:
                    continue
                
                # Add entry to the set
                translators_credits_set.add(line)
            
            # if true, this is the start of the translation credits block;
            # flag is_translator_credits and go to the next line
            if line == '# Translators:\n':
                is_translator_credits = True
                continue
            
            # if true, it means the loop went down until it found the first msgid.
            # This means there is no translator credits block (i.e. no one started
            # translating this file). Therefore we should stop looking at this file.
            # Quit this file and go to the next one.
            if line == 'msgid "':
                break

# Remove parentheses that messes the alphabeticall order.
translators_credits_set.remove('(Douglas da Silva) <dementikovalev@yandex.ru>')
translators_credits_set.add('Douglas da Silva <dementikovalev@yandex.ru>')

# Print the resulting list to the standard output
for t in sorted(translators_credits_set):
    print(t)
