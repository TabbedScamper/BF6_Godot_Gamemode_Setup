"""Package derived identity links; never use transforms to infer relationships."""
import argparse
import json
from pathlib import Path
import sys
from collections import defaultdict


def identity(row):
    raw = row.get('raw', row)
    return (raw.get('partition') or '') + '#' + (raw.get('instance_guid') or '')


def add_cross_partition_rows(result, directory):
    """Only recover explicitly referenced endpoints, never import another mode wholesale."""
    corpus = defaultdict(list)
    documents = {}
    for path in sorted(directory.glob('*.layout.json')):
        doc = json.loads(path.read_text(encoding='utf-8-sig'))
        documents[path.name] = doc
        for row in doc.get('objects', []):
            if row.get('raw', {}).get('instance_guid'):
                corpus[identity(row)].append((path.name, row))
    for key, layout in result['layouts'].items():
        doc = documents.get(key.replace('/', '_') + '.layout.json', {})
        present = {identity(r) for r in doc.get('objects', [])}
        controllers = {s['id'] for s in layout['sectors']}
        for sector in layout['sectors']:
            controllers.update(i for i in sector['members'] if any(
                tag in layout['entities'].get(i, '') for tag in
                ['/gem_hq.ebx#', '/gem_capturepoint.ebx#', '/gem_objective_mcom.ebx#']))
        required = {e['target'] for e in layout['attachments'] if e['source'] in controllers}
        supplements = {}
        for target in sorted(required - present):
            candidates = corpus.get(target, [])
            if not candidates:
                continue
            signatures = {json.dumps({
                'transform': r.get('raw', {}).get('transform'),
                'points': r.get('world_points'), 'centre': r.get('centre'),
                'height': r.get('height'), 'shape': r.get('raw', {}).get('shape_asset')
            }, sort_keys=True) for _, r in candidates}
            if len(signatures) != 1:
                raise ValueError('Conflicting cross-partition geometry: ' + target)
            supplements[target] = {'row': candidates[0][1],
                                   'source_layouts': [p for p, _ in candidates],
                                   'basis': 'explicit game attachment target; full partition#GUID join'}
        layout['supplemental_rows'] = supplements
    return result


def export(research, reports, hq_evidence):
    sys.path.insert(0, str(research / 'impl/retools'))
    from evaluate_gem_layout import select_layout
    manifest = json.loads((research / 'data/progressive_authored_order_6a1c1b.json').read_text())
    objective_manifest = json.loads(
        (research / 'data/progressive_objective_order_6a1c1b.json').read_text())
    objective_order = {}
    for map_entry in objective_manifest['maps']:
        for layout_entry in map_entry['layouts']:
            for sector in layout_entry['sectors']:
                objective_order[(map_entry['map'], layout_entry['layout'], sector['sector'])] = {
                    'status': layout_entry['status'],
                    'objectives': sector['objectives'],
                }
    maps = {m['map']: m for path in reports for m in json.loads(path.read_text())['maps']}
    hq_properties = {}
    for entry in json.loads(hq_evidence.read_text())['maps']:
        for layout in entry['layouts']:
            for sector in layout['sectors']:
                for hq in sector['hqs']:
                    hq_properties[hq['hq']] = hq['properties']
    layouts = {}
    for entry in manifest['maps']:
        report = maps[entry['map']]
        nodes = {n['id']: n for n in report['nodes']}
        sectors = {s['id']: s for s in report['sectors']}
        for layout in entry['layouts']:
            parts = layout['layout'].split('/gamemodes/', 1)
            if len(parts) != 2:
                raise ValueError('Layout is outside the gamemode namespace: ' + layout['layout'])
            mode = parts[1].split('/', 1)[0]
            if mode not in ('rush', 'breakthrough'):
                raise ValueError('Unexpected progressive mode: ' + mode)
            retained = set(select_layout(report, layout['layout'])['selected_entities'])
            ordered = [s['entity'] for s in layout['sectors']]
            assert len(ordered) == len(set(ordered))
            assert set(ordered) <= retained
            rows = []
            for identity in ordered:
                # Keep the complete descendant membership, not root-order pairs.
                members = list(dict.fromkeys(d['id'] for d in sectors[identity]['descendants'] if d['id'] in retained))
                ordered_objectives = objective_order[(entry['map'], layout['layout'], identity)]
                objective_ids = [o['entity'] for o in ordered_objectives['objectives']]
                assert len(objective_ids) == len(set(objective_ids))
                assert set(objective_ids) <= set(members)
                rows.append({'id': identity, 'members': members,
                             'objective_order_status': ordered_objectives['status'],
                             'objectives': ordered_objectives['objectives']})
            links = [e for e in report['attachments'] if e['source'] in retained]
            layouts[entry['map'].lower() + '/' + mode] = {
                'layout': layout['layout'], 'status': layout['status'],
                'sectors': rows, 'attachments': links,
                'memberships': [e for e in report['links'] if e['source'] in retained and e['target'] in retained],
                'entities': {k: nodes[k].get('gem_blueprint', '') for k in sorted(retained)},
                'hq_properties': {k: hq_properties[k] for k in sorted(retained) if k in hq_properties},
            }
    return {
        'schema': 2,
        'status': 'verified_standard_authored_layout_and_objective_order',
        'conditions': manifest['conditions'],
        'hq_control_baseline': {
            'InvertedHQ': False,
            'InvertTeamRoles': False,
            'GameModeControlsHQ': False,
            'attacker_team': 1,
            'defender_team': 2,
            'scope': 'mounted standard Rush and Breakthrough authored launch path',
            'finding': 'standard-progressive-hq-control-baseline-is-false',
        },
        'hq_activation_by_sector_status': {
            'status_names': {
                '0': 'Contested', '1': 'Upcoming', '2': 'Next',
                '3': 'Prepare', '4': 'Abandoned', '5': 'Previous',
                '6': 'Pre-Contested', '7': 'Captured', '8': 'Outcome',
                '9': 'CleanUp', '10': 'Any', '11': 'Secured',
            },
            'team_1_active': [0, 6, 7, 8, 9, 11],
            'team_2_active': [0, 2, 3, 6, 11],
            'scope': 'shared sector writer with the standard false HQ-control baseline',
            'finding': 'sector-hq-activation-slice-and-round-delegate-writes',
        },
        'objective_order_finding': 'progressive-objective-runtime-filter-and-order',
        'layouts': layouts,
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--research', type=Path, required=True)
    parser.add_argument('--reports', type=Path, nargs='+', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--hq-evidence', type=Path, required=True)
    parser.add_argument('--layouts', type=Path, default=Path(__file__).resolve().parents[1] / 'data')
    args = parser.parse_args()
    result = export(args.research, args.reports, args.hq_evidence)
    add_cross_partition_rows(result, args.layouts)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, separators=(',', ':'), sort_keys=True) + '\n', encoding='utf-8')
    print('Exported', len(result['layouts']), 'layout link sets')
