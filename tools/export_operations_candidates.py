"""Export selected Operations sector/HQ/capture candidate membership.

This reports authored layout00 membership, not gameplay phase or battalion
order. Cross-partition captures remain identified by full GEM identity.
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
    from audit_retail_mode_structure import family
    from evaluate_gem_layout import select_layout

    maps = {}
    for path in args.membership:
        for report in json.loads(path.read_text(encoding="utf-8"))["maps"]:
            nodes = {node["id"]: node for node in report["nodes"]}
            layouts = {identity for node in nodes.values()
                       for identity in node.get("layout_filters", [])
                       if "/operations/layouts/" in identity.lower()
                       and "layout00.ebx#" in identity.lower()}
            if not layouts:
                continue
            if len(layouts) != 1:
                raise ValueError(f"Multiple Operations layout00 identities: {report['map']}")
            layout = next(iter(layouts))
            selected = set(select_layout(report, layout)["selected_entities"])
            kinds = {node_id: family(nodes[node_id].get("gem_blueprint")) for node_id in selected}
            sectors = {node_id for node_id, kind in kinds.items() if kind == "gem_sector"}
            if not sectors:
                continue
            memberships = [edge for edge in report["links"] if edge["source"] in sectors
                           and edge["target"] in selected]
            ordered = []
            for sector_id in sorted(sectors):
                children = sorted((edge for edge in memberships if edge["source"] == sector_id),
                                  key=lambda edge: edge["link_index"])
                captures = [edge["target"] for edge in children
                            if kinds.get(edge["target"]) == "gem_capturepoint"]
                hqs = [edge["target"] for edge in children
                       if kinds.get(edge["target"]) == "gem_hq"]
                if len(hqs) != 2 or not captures:
                    raise ValueError(f"Incomplete Operations sector: {report['map']} {sector_id}")
                ordered.append({"sector": sector_id, "captures": captures, "hqs": hqs,
                                "membership_link_indices": [edge["link_index"] for edge in children
                                                             if edge["target"] in captures + hqs]})
            key = report["map"].lower()
            maps[key] = {"layout": layout, "sectors": ordered}
    if len(maps) != 4 or sum(len(x["sectors"]) for x in maps.values()) != 17 or \
            sum(len(s["captures"]) for x in maps.values() for s in x["sectors"]) != 27 or \
            sum(len(s["hqs"]) for x in maps.values() for s in x["sectors"]) != 34:
        raise ValueError("Operations selected candidate census changed")
    output = {"source": "installed Operations layout00 selected GEM membership",
              "scope": "candidate membership only; gameplay sector/phase order unverified",
              "maps": dict(sorted(maps.items()))}
    args.output.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print("Operations: 4 maps, 17 sectors, 27 captures, 34 HQs")


if __name__ == "__main__":
    main()
