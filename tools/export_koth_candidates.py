"""Package audited, selected KOTH capture candidates for the Godot importer.

The input reports are produced from installed-game GEM partitions. This build
helper imports the research audit so selection and link-order checks are not
reimplemented differently inside the plugin repository.
"""

import argparse
import json
import sys
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--research", type=Path, required=True)
    parser.add_argument("--membership", type=Path, action="append", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    sys.path.insert(0, str(args.research / "impl" / "retools"))
    from audit_koth_hill_candidates import audit_map

    maps = {}
    for path in args.membership:
        for report in json.loads(path.read_text(encoding="utf-8"))["maps"]:
            key = report["map"].lower()
            if key in maps:
                raise ValueError(f"Duplicate map report: {key}")
            maps[key] = audit_map(report)
    if len(maps) != 17:
        raise ValueError(f"Expected 17 mounted map reports; found {len(maps)}")

    populated = {key: value for key, value in maps.items()
                 if value and value["sector_count"] and value["captures"]}
    if len(populated) != 15 or sum(len(row["captures"]) for row in populated.values()) != 73:
        raise ValueError("Installed KOTH candidate census changed")
    package = {
        "source": "installed KOTH layout00 GEM sector membership links",
        "scope": "authored candidates and link order; live hill rotation unverified",
        "maps": {key: {"layout": row["layout"], "capture_guids": row["captures"],
                       "link_indices": row["link_indices"]}
                 for key, row in sorted(populated.items())},
    }
    args.output.write_text(json.dumps(package, indent=2) + "\n", encoding="utf-8")
    print(f"KOTH: {len(populated)} populated maps, 73 exact candidates")


if __name__ == "__main__":
    main()
