#!/usr/bin/env python3
"""Print pihole.toml as JSON keyed by the dotted names pihole-FTL --config uses.

Reading the TOML directly avoids parsing `pihole-FTL --config` output, whose
array format is not JSON and cannot be split safely when entries contain commas.
"""
import json
import sys
import tomllib


def flatten(node, prefix=""):
    flat = {}
    for key, value in node.items():
        path = prefix + key
        if isinstance(value, dict):
            flat.update(flatten(value, path + "."))
        else:
            flat[path] = value
    return flat


with open(sys.argv[1], "rb") as handle:
    json.dump(flatten(tomllib.load(handle)), sys.stdout)
