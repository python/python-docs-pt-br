#!/usr/bin/python
"""Print translation percentage to update statistics."""

import json
import os
import urllib.request
from datetime import datetime, timezone

key = os.environ.get('TX_TOKEN')
language = os.environ.get('PYDOC_LANGUAGE')
project = os.environ.get('PYDOC_TX_PROJECT')

url = "https://rest.api.transifex.com/resource_language_stats?filter[project]=o%3Apython-doc%3Ap%3A{tx_project}&filter[language]=l%3A{langcode}".format(tx_project=project, langcode=language)

headers = {
    "accept": "application/vnd.api+json",
    "authorization": "Bearer " + key
}

total = 0
translated = 0

while(url):
    request = urllib.request.Request(url=url,headers=headers)
    with urllib.request.urlopen(request) as response:
        data = json.loads(response.read().decode("utf-8"))
        url = data['links'].get('next')
        for resourse in data['data']:
            translated = translated + resourse['attributes']['translated_strings']
            total =  total + resourse['attributes']['total_strings']

p = '{:.2%}'.format(translated/total)
print(json.dumps({
    'translation':p,
    'updated_at':datetime.now(timezone.utc).isoformat(timespec='seconds') + 'Z',
    }))
