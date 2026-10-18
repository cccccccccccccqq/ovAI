#!/usr/bin/env python3
"""Build four-minute English narration with the demo's four macOS voices.

Reads only the curated English chapter catalog and generates local AAC assets.
No manuscript, text, or credentials are sent to a remote service. Each scene
gets its own timing adjustment, keeping the narrated paragraph and map cue aligned.
Requires macOS say, ffmpeg and ffprobe; no extra Python packages are needed.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

VOICES = {'samantha': 'Samantha', 'daniel': 'Daniel', 'karen': 'Karen', 'moira': 'Moira'}


def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE).strip()


def seconds(path):
    return float(run('ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                     '-of', 'default=noprint_wrappers=1:nokey=1', str(path)))


def build(job):
    template, voice_id, assets, rate = job
    scenes = template['scenes']
    assert scenes[0]['startMs'] == 0
    assert scenes[-1]['endMs'] == template['durationMs'] == 240000
    assert all(a['endMs'] == b['startMs'] for a, b in zip(scenes, scenes[1:]))
    assert '\n\n'.join(s['narration'] for s in scenes) == '\n\n'.join(s['text'] for s in template['segments'])
    target = assets / voice_id / (template['id'] + '.m4a')
    target.parent.mkdir(parents=True, exist_ok=True)
    narration_hash = hashlib.sha256('\n\n'.join(s['narration'] for s in scenes).encode()).hexdigest()
    report = {'templateId': template['id'], 'voiceId': voice_id,
              'systemVoice': VOICES[voice_id], 'language': 'en',
              'contentVersion': template['contentVersion'], 'narrationSha256': narration_hash,
              'scenes': []}
    with tempfile.TemporaryDirectory(prefix='ov-history-en-') as folder:
        temp = Path(folder)
        for index, scene in enumerate(scenes):
            text_file = temp / f'{index}.txt'
            text_file.write_text(scene['narration'])
            raw = temp / f'{index}.aiff'
            run('say', '-v', VOICES[voice_id], '-r', str(rate), '-f', str(text_file), '-o', str(raw))
            original = seconds(raw)
            duration = (scene['endMs'] - scene['startMs']) / 1000
            tempo = original / (duration - 0.2)
            if not 0.5 <= tempo <= 1.8:
                raise RuntimeError(f"{voice_id}/{template['id']}/{index}: editorial timing adjustment required ({tempo:.3f})")
            aligned = temp / f'{index}.wav'
            run('ffmpeg', '-v', 'error', '-y', '-i', str(raw), '-af',
                f'atempo={tempo:.10f},apad,atrim=duration={duration}',
                '-ar', '24000', '-ac', '1', '-c:a', 'pcm_s16le', str(aligned))
            report['scenes'].append({'id': scene['id'], 'startMs': scene['startMs'],
                'endMs': scene['endMs'], 'originalSeconds': original, 'tempo': round(tempo, 6)})
        manifest = temp / 'concat.txt'
        manifest.write_text(''.join(f"file '{index}.wav'\n" for index in range(len(scenes))))
        run('ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', str(manifest),
            '-af', 'apad,atrim=duration=240', '-c:a', 'aac', '-b:a', '64k',
            '-movflags', '+faststart', str(target))
    report['measuredSeconds'] = seconds(target)
    report['audioSha256'] = hashlib.sha256(target.read_bytes()).hexdigest()
    report['bytes'] = target.stat().st_size
    report['assetPath'] = 'assets/audio/' + voice_id + '/' + target.name
    if abs(report['measuredSeconds'] - 240) > 0.15:
        raise RuntimeError(f"Unexpected duration: {target} {report['measuredSeconds']}")
    print(f"{voice_id}/{template['id']}: {report['measuredSeconds']:.3f}s, {report['bytes']} bytes", flush=True)
    return report


def main():
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=repo / 'seed/secret-history-english.json')
    parser.add_argument('--output-root', type=Path, default=repo / 'app/assets/audio')
    parser.add_argument('--report', type=Path, default=repo / 'seed/secret-history-english-audio.production.json')
    parser.add_argument('--rate', type=int, default=150)
    parser.add_argument('--workers', type=int, default=4)
    args = parser.parse_args()
    for binary in ['say', 'ffmpeg', 'ffprobe']:
        if not shutil.which(binary):
            parser.error(f'{binary} is required')
    data = json.loads(args.source.read_text())
    templates = data['templates']
    if any(t['language'] != 'en' for t in templates):
        parser.error('English templates required')
    jobs = [(t, v, args.output_root, args.rate) for t in templates for v in VOICES]
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        report = list(pool.map(build, jobs))
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps({'schemaVersion': 1, 'engine': 'macOS say',
        'catalogSha256': hashlib.sha256(args.source.read_bytes()).hexdigest(),
        'assets': report}, ensure_ascii=False, indent=2) + '\n')
    print(f'Verified {len(report)} English voice assets; report: {args.report}', flush=True)


if __name__ == '__main__':
    main()
