"""Augment the generated manifest with additional file data"""
import json
import sys
import hashlib
from pathlib import Path


if __name__ == "__main__":
    manifest_file = Path(sys.argv[1])
    path_list: list[Path] = [
        Path("lvm-system.csv"),
        Path("mkosi.conf"),
        *Path("mkosi.extra").rglob("*"),
        Path("mkosi.postinst.chroot"),
        Path("mkosi.finalize")
    ]
    manifest: dict = {}
    files: list[dict[str, str]] = []
    with manifest_file.open(encoding="utf-8") as m_f:
        manifest = json.load(m_f)

    for file in path_list:
        if file.is_file() and not file.is_dir():
            files.append(
                {
                    "name": str(file),
                    "mode": oct(file.stat().st_mode),
                    "hash": hashlib.sha512(file.read_bytes()).hexdigest(),
                }
            )

    manifest["files"] = files
    manifest_file.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=4, sort_keys=True),
        encoding="utf-8",
    )
