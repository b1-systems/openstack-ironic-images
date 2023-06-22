"""Compare two manifest files if they contain the same data"""

import sys
import json
from pathlib import Path
import github_action_utils

if __name__ == "__main__":
    old_manifest_file = Path(sys.argv[1])
    new_manifest_file = Path(sys.argv[2])

    old_manifest = json.loads(old_manifest_file.read_text(encoding="utf-8"))
    new_manifest = json.loads(new_manifest_file.read_text(encoding="utf-8"))

    if old_manifest == new_manifest:
        github_action_utils.set_output(name="value", value="true")
    else:
        github_action_utils.set_output(name="value", value="false")
