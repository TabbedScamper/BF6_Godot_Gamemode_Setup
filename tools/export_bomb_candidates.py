"""Export selected Obliteration bomb/MCOM/HQ candidates from retail GEM links."""

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

    rows = {}
    for path in args.membership:
        for report in json.loads(path.read_text(encoding="utf-8"))["maps"]:
            nodes = {node["id"]: node for node in report["nodes"]}
            for mode in ("obliteration", "squadobliteration"):
                layouts = {identity for node in nodes.values()
                           for identity in node.get("layout_filters", [])
                           if f"/{mode}/layouts/" in identity.lower()
                           and "layout00.ebx#" in identity.lower()}
                if not layouts:
                    continue
                if len(layouts) != 1:
                    raise ValueError(f"Multiple {mode} layout00 identities: {report['map']}")
                layout = next(iter(layouts))
                selected = set(select_layout(report, layout)["selected_entities"])
                kinds = {node_id: family(nodes[node_id].get("gem_blueprint"))
                         for node_id in selected}
                sectors = [node_id for node_id, kind in kinds.items() if kind == "gem_sector"]
                if not sectors:
                    continue
                if len(sectors) != 1:
                    raise ValueError(f"Expected one bomb-mode sector: {report['map']} {mode}")
                sector = sectors[0]
                children = sorted((edge for edge in report["links"]
                                   if edge["source"] == sector and edge["target"] in selected),
                                  key=lambda edge: edge["link_index"])
                def members(kind):
                    return [edge["target"] for edge in children if kinds.get(edge["target"]) == kind]
                bombs, mcoms, hqs = (members("gem_bomb_pickup"),
                                     members("gem_objective_mcom"), members("gem_hq"))
                if len(bombs) != (12 if mode == "obliteration" else 1) or len(mcoms) != 6 \
                        or len(hqs) not in (2, 6):
                    raise ValueError(f"Bomb-mode candidate census changed: {report['map']} {mode}")
                key = report["map"].lower() + "/" + mode
                rows[key] = {"layout": layout, "sector": sector, "bombs": bombs,
                             "mcoms": mcoms, "hqs": hqs,
                             "membership_link_indices": [edge["link_index"] for edge in children
                                                          if edge["target"] in bombs + mcoms + hqs]}
    if len(rows) != 7 or sum(len(x["bombs"]) for x in rows.values()) != 40 \
            or sum(len(x["mcoms"]) for x in rows.values()) != 42:
        raise ValueError("Installed bomb-mode candidate census changed")
    output = {"source": "installed bomb-mode layout00 selected GEM membership",
              "scope": "authored candidate sites; live bomb selection and activation unverified",
              "layouts": dict(sorted(rows.items()))}
    args.output.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print("Bomb modes: 7 layouts, 40 bomb candidates, 42 MCOMs")


if __name__ == "__main__":
    main()
