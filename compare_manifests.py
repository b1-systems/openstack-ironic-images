"""Compare two manifest files if they contain the same data"""

import sys
import json
from pathlib import Path
import github_action_utils
import deepcompare

if __name__ == "__main__":
    old_manifest_file = Path(sys.argv[1])
    new_manifest_file = Path(sys.argv[2])

    old_manifest = json.load(old_manifest_file.open(encoding='utf-8'))
    new_manifest = json.load(new_manifest_file.open(encoding='utf-8'))

    del old_manifest["config"]["version"]
    del new_manifest["config"]["version"]

    if deepcompare.compare(old_manifest, new_manifest):
        github_action_utils.set_output(name="value", value="true")
    else:
        github_action_utils.set_output(name="value", value="false")
