"""Package exact schematic-group parents for selected progressive vehicles.

The selected GEM manifest omits non-GEM schematic group nodes. This preserves
their full-identity membership edges without guessing an HQ or sector owner.
"""

import argparse
import json
from pathlib import Path


def identity(row):
    raw = row.get("raw", row)
    return f"{raw.get('partition', '')}#{raw.get('instance_guid', '')}"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--membership", type=Path, action="append", required=True)
    parser.add_argument("--plugin", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    reports = {}
    for path in args.membership:
        for report in json.loads(path.read_text(encoding="utf-8"))["maps"]:
            key = report["map"].lower()
            if key in reports:
                raise ValueError(f"Duplicate map report: {key}")
            reports[key] = report
    package = json.loads((args.plugin / "addons/bf6_gamemode_setup/data/progressive_links.json")
                         .read_text(encoding="utf-8"))
    result = {}
    groups = set()
    for key, evidence in package["layouts"].items():
        if not evidence["sectors"]:
            continue
        path = args.plugin / "data" / (key.replace("/", "_") + ".layout.json")
        if not path.exists():
            continue
        document = json.loads(path.read_text(encoding="utf-8"))
        rows = {identity(row): row for row in document["elements"]}
        rows.update({identity(row): row for row in document["objects"]})
        report = reports[key.split("/")[0]]
        nodes = {node["id"]: node for node in report["nodes"]}
        full_parents = {}
        for edge in report["links"]:
            full_parents.setdefault(edge["target"], []).append(edge["source"])
        selected_parents = {}
        for edge in evidence["memberships"]:
            selected_parents.setdefault(edge["target"], []).append(edge["source"])
        sector_ids = {sector["id"] for sector in evidence["sectors"]}
        for vehicle_id, blueprint in evidence["entities"].items():
            row = rows.get(vehicle_id)
            if not row or row.get("role") != 6 or row.get("stationary"):
                continue
            seen, pending, scopes = set(), list(selected_parents.get(vehicle_id, [])), set()
            while pending:
                parent_id = pending.pop()
                if parent_id in seen:
                    continue
                seen.add(parent_id)
                parent_blueprint = evidence["entities"].get(parent_id, "")
                if (parent_id in sector_ids or "/gem_hq.ebx#" in parent_blueprint
                        or "/gem_capturepoint.ebx#" in parent_blueprint
                        or "/gem_objective_mcom.ebx#" in parent_blueprint):
                    scopes.add(parent_id)
                else:
                    pending.extend(selected_parents.get(parent_id, []))
            if scopes:
                continue
            candidates = list(dict.fromkeys(full_parents.get(vehicle_id, [])))
            if len(candidates) != 1:
                raise ValueError(f"Unscoped vehicle lacks unique full-graph parent: {vehicle_id}")
            parent_id = candidates[0]
            parent = nodes[parent_id]
            if "group_behavior" not in parent or evidence["layout"].lower() not in [
                    value.lower() for value in parent.get("layout_filters", [])]:
                raise ValueError(f"Vehicle parent is not a selected schematic group: {vehicle_id}")
            result.setdefault(key, {})[vehicle_id] = parent_id
            groups.add(parent_id)
    if sum(len(rows) for rows in result.values()) != 23 or len(groups) != 8:
        raise ValueError("Schematic vehicle census changed; review before packaging")
    output = {"source": "installed full GEM membership graph",
              "scope": "selected schematic-group parent; not a proven live HQ/sector activation",
              "layouts": {key: dict(sorted(rows.items())) for key, rows in sorted(result.items())}}
    args.output.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print("Progressive schematic vehicles: 23 records in 8 selected groups")


if __name__ == "__main__":
    main()
