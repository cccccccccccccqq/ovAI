"""Apply tool/sourced_content.json to the bundled catalog, the cloud seed and
the narration manifest. Run from app/: python3 tool/apply_sourced_content.py
Then delete the affected m4a files and run tool/prepare_assets.py.
"""
import json
import re
from pathlib import Path

APP = Path(__file__).resolve().parents[1]
CONTENT = json.loads((APP / 'tool/sourced_content.json').read_text())
DEMO = APP / 'lib/core/demo_data.dart'
CATALOG = APP.parent / 'seed/catalog.json'
MANIFEST = APP / 'tool/narration_manifest.json'


def dart(value):
    escaped = value.replace('\\', '\\\\').replace('"', '\\"').replace('$', '\\$')
    return f'"{escaped}"'


def citation_dart(c):
    url = dart(c['url']) if c.get('url') else 'null'
    return (
        '  Citation(\n'
        f'    id: {dart(c["id"])},\n'
        f'    title: {dart(c["title"])},\n'
        f'    author: {dart(c["author"])},\n'
        f'    page: {dart(c["page"])},\n'
        f'    note:\n        {dart(c["note"])},\n'
        f'    url: {url},\n'
        '  ),\n'
    )


def segments(template_id):
    t = CONTENT['templates'][template_id]
    items = [{'kind': 'legend', 'text': text} for text, _ in t['segments']]
    text, citation_id, _ = t['context']
    # Each story cites its own pages, so its citation ID is story-specific.
    items.append({'kind': 'context', 'text': text, 'citationId': f'{citation_id}-{template_id}'})
    return items


def template_citation(template_id):
    _, citation_id, page = CONTENT['templates'][template_id]['context']
    return {**citations[citation_id], 'id': f'{citation_id}-{template_id}', 'page': page}


def template_dart(base):
    t = CONTENT['templates'][base['id']]
    segs = ''.join(
        '      StorySegment(\n'
        f'        kind: {dart(s["kind"])},\n'
        f'        text:\n            {dart(s["text"])},\n'
        + (f'        citationId: {dart(s["citationId"])},\n' if 'citationId' in s else '')
        + '      ),\n'
        for s in segments(base['id'])
    )
    next_ids = ', '.join(dart(i) for i in base['nextIds'])
    image = 'assets/images/' + base['imagePath'].rsplit('/', 1)[1]
    return (
        '  StoryTemplate(\n'
        f'    id: {dart(base["id"])},\n'
        f'    siteId: {dart(base["siteId"])},\n'
        f'    title: {dart(t["title"])},\n'
        f'    subtitle: {dart(t["subtitle"])},\n'
        f'    image: {dart(image)},\n'
        f'    chapter: {base["chapter"]},\n'
        f'    genre: {dart(base["genre"])},\n'
        f'    style: {dart(base["style"])},\n'
        f'    mood: {dart(base["mood"])},\n'
        f'    seed: {dart(t["seed"])},\n'
        f'    segments: [\n{segs}    ],\n'
        f'    nextIds: [{next_ids}],\n'
        '    citations: [\n'
        + '\n'.join('    ' + line if line else line
                    for line in citation_dart(template_citation(base['id'])).split('\n'))
        + '    ],\n'
        '  ),\n'
    )


catalog = json.loads(CATALOG.read_text())
citations = {c['id']: c for c in CONTENT['citations']}

# Bundled Dart catalog.
source = DEMO.read_text()
for site_id, summary in CONTENT['sites'].items():
    source, n = re.subn(
        r'(id: "' + re.escape(site_id) + r'",\n(?:.*\n)*?    summary:\n        )".*?",',
        lambda m: m.group(1) + dart(summary) + ',',
        source,
        count=1,
    )
    assert n == 1, site_id
start = source.index('const demoCitations = <Citation>[')
end = source.index('];', start) + 2
source = (
    source[:start]
    + 'const demoCitations = <Citation>[\n'
    + ''.join(citation_dart(c) for c in CONTENT['citations'])
    + '];'
    + source[end:]
)
start = source.index('/// Original editorial fiction;')
end = source.index('];', source.index('const demoTemplates = <StoryTemplate>[')) + 2
source = (
    source[:start]
    + '/// Source-based retellings; each "context" block links to its citation.\n'
    + '/// Text lives in tool/sourced_content.json, with matching narration assets.\n'
    + 'const demoTemplates = <StoryTemplate>[\n'
    + ''.join(template_dart(t) for t in catalog['templates'])
    + '];'
    + source[end:]
)
DEMO.write_text(source)

# Cloud seed catalog.
for site in catalog['sites']:
    site['summary'] = CONTENT['sites'][site['id']]
for base in catalog['templates']:
    t = CONTENT['templates'][base['id']]
    base['title'], base['subtitle'], base['seed'] = t['title'], t['subtitle'], t['seed']
    base['segments'] = segments(base['id'])
    base['citations'] = [template_citation(base['id'])]
    base['contentVersion'] = base.get('contentVersion', 1) + 1
CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')

# Narration text.
manifest = json.loads(MANIFEST.read_text())
for item in manifest['templates']:
    t = CONTENT['templates'].get(item['id'])
    if t is None:
        continue
    item['title'] = t['title']
    body = '\n\n'.join(text for text, _ in t['segments'])
    item['text'] = f"{t['title']}. A story from historical sources.\n\n{body}"
MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
print('applied', len(CONTENT['templates']), 'templates')
