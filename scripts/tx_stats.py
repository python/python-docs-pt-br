#!/usr/bin/python
"""Print translation percentage to update statistics."""

import json
import os
import configparser
import urllib.request
from datetime import datetime, timezone

# Get language and project from environment variables
language = os.environ.get("PYDOC_LANGUAGE")
project = os.environ.get("PYDOC_TX_PROJECT")
if language is None:
    raise ValueError("The PYDOC_LANGUAGE environment variable must be set.")
if project is None:
    raise ValueError("The PYDOC_TX_PROJECT environment variable must be set.")


# Try to read API token from TX_TOKEN env and then from ~/.transifexrc
def get_transifex_token():
    key = os.environ.get("TX_TOKEN")
    if key is None:
        config = configparser.ConfigParser()
        config.read(os.path.expanduser("~/.transifexrc"))
        try:
            key = config["https://www.transifex.com"]["token"]
        except KeyError:
            raise ValueError("Unable to retrieve Transifex API token.")
    return key


# API URL setup
url_template = (
    "https://rest.api.transifex.com/resource_language_stats"
    "?filter[project]=o%3Apython-doc%3Ap%3A{project}"
    "&filter[language]=l%3A{language}"
)

# Get the authorization key
key = get_transifex_token()

url = url_template.format(project=project, language=language)

headers = {"accept": "application/vnd.api+json", "authorization": f"Bearer {key}"}

# Initialize counters
total_strings = 0
translated_strings = 0


# Function to make an API request and handle potential errors
def fetch_data(url):
    request = urllib.request.Request(url=url, headers=headers)
    try:
        with urllib.request.urlopen(request) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.URLError as e:
        raise ConnectionError(f"Error fetching data: {e}")
    except json.JSONDecodeError as e:
        raise ValueError(f"Error decoding JSON response: {e}")


# Fetch and process translation stats
while url:
    data = fetch_data(url)
    url = data["links"].get("next")
    for resource in data["data"]:
        translated_strings += resource["attributes"]["translated_strings"]
        total_strings += resource["attributes"]["total_strings"]

# Calculate translation percentage
if total_strings == 0:
    raise ValueError("Total strings cannot be zero.")

percentage = f"{(translated_strings / total_strings):.2%}"

# Print the result as JSON
print(
    json.dumps(
        {
            "translation": percentage,
            "total": total_strings,
            "updated_at": datetime.now(timezone.utc).isoformat(timespec="seconds")
            + "Z",
        }
    )
)
