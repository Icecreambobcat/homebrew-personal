#!/usr/bin/env python3
"""Check installed tap receipts against current dependency compatibility metadata."""
import json
import subprocess
import sys

formulae = json.loads(subprocess.check_output(
    ["brew", "info", "--json=v2", "--installed"], text=True))["formulae"]
current = {f["full_name"]: f for f in formulae}
errors = []
expected = {"synctex", "zathura-core", "zathura-pdf-mupdf", "zathura-djvu",
            "zathura-ps", "zathura-cb", "zathura"}
missing = expected - {f["name"] for f in formulae if f["full_name"].startswith("icecreambobcat/personal/")}
if missing:
    errors.append(f"Missing installed stack packages: {sorted(missing)}")
for formula in formulae:
    if not formula["full_name"].startswith("icecreambobcat/personal/"):
        continue
    if formula["name"] != "synctex" and not formula["name"].startswith("zathura"):
        continue
    installed = next((i for i in formula["installed"] if i["version"] == formula.get("linked_keg")), None)
    if installed is None:
        # Keg-only packages may not have linked_keg; compare the latest installed receipt.
        installed = formula["installed"][-1]
    for dependency in installed.get("runtime_dependencies", []):
        name = dependency["full_name"]
        actual = current.get(name)
        if actual is None:
            errors.append(f'{formula["name"]}: missing runtime dependency {name}')
            continue
        before = dependency.get("compatibility_version")
        after = actual.get("compatibility_version")
        if before is not None and after is not None and before != after:
            errors.append(f'{formula["name"]}: {name} compatibility {before} -> {after}; rebuild required')
        if name == "mupdf" and dependency["version"] != actual["versions"]["stable"]:
            errors.append(f'{formula["name"]}: MuPDF {dependency["version"]} -> {actual["versions"]["stable"]}; rebuild required')
for error in errors:
    print(error, file=sys.stderr)
if errors:
    sys.exit(1)
print("PASS installed Zathura dependency receipts match current compatibility metadata")
