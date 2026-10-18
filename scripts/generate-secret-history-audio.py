#!/usr/bin/env python3
"""Build a local 4-minute Mongolian prototype narration, aligned to map scenes.

Requires edge-tts 7.3.1, ffmpeg and ffprobe. Sends only the curated narration
to Microsoft's online voice service; never uploads the source manuscript.
This is an optional authoring tool, not a runtime dependency of the app.
"""
import argparse
import asyncio
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

import edge_tts


def run(*args):
    return subprocess.check_output(args, text=True).strip()


def seconds(path):
    return float(run('ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                     '-of', 'default=noprint_wrappers=1:nokey=1', str(path)))


async def build(source, output, voice):
    data = json.loads(source.read_text())
    chapter = data['chapters'][0]
    scenes = chapter['scenes']
    assert scenes[0]['startMs'] == 0
    assert scenes[-1]['endMs'] == chapter['durationMs'] == 240000
    assert all(a['endMs'] == b['startMs'] for a, b in zip(scenes, scenes[1:]))
    output.parent.mkdir(parents=True, exist_ok=True)
    report = {'chapterId': chapter['id'], 'voice': voice, 'contentVersion': chapter['contentVersion'],
              'narrationSha256': hashlib.sha256(chapter['narration'].encode()).hexdigest(),
              'scenes': []}
    with tempfile.TemporaryDirectory(prefix='ov-chapter-audio-') as folder:
        temp = Path(folder)
        for index, scene in enumerate(scenes):
            raw = temp / f'{index}.mp3'
            await edge_tts.Communicate(scene['narration'], voice).save(str(raw))
            original = seconds(raw)
            target = (scene['endMs'] - scene['startMs']) / 1000
            # A short pause separates the scenes without a long silent padded ending.
            speech_target = target - 0.18
            tempo = original / speech_target
            if not 0.55 <= tempo <= 1.65:
                raise RuntimeError(f"Scene {scene['id']} needs editorial timing adjustment: {tempo:.2f}")
            wav = temp / f'{index}.wav'
            run('ffmpeg', '-v', 'error', '-y', '-i', str(raw), '-af',
                f'atempo={tempo:.8f},apad,atrim=duration={target}',
                '-ar', '24000', '-ac', '1', '-c:a', 'pcm_s16le', str(wav))
            report['scenes'].append({'id': scene['id'], 'startMs': scene['startMs'],
                'endMs': scene['endMs'], 'originalSeconds': original, 'tempo': tempo})
            print(f"{scene['id']}: {original:.2f}s -> {target:.2f}s (tempo {tempo:.3f})", flush=True)
        manifest = temp / 'concat.txt'
        manifest.write_text(''.join(f"file '{index}.wav'\n" for index in range(len(scenes))))
        run('ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', str(manifest),
            '-af', 'apad,atrim=duration=240', '-c:a', 'libmp3lame', '-b:a', '96k', str(output))
    report['measuredSeconds'] = seconds(output)
    report['audioSha256'] = hashlib.sha256(output.read_bytes()).hexdigest()
    report['bytes'] = output.stat().st_size
    if abs(report['measuredSeconds'] - 240) > .15:
        raise RuntimeError('Unexpected encoded audio duration.')
    report_file = output.with_suffix('.production.json')
    report_file.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'audio': str(output), 'report': str(report_file),
                      'duration': report['measuredSeconds'], 'bytes': report['bytes']}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--voice', default='mn-MN-YesuiNeural')
    args = parser.parse_args()
    for binary in ['ffmpeg', 'ffprobe']:
        if not shutil.which(binary):
            parser.error(f'{binary} is required')
    asyncio.run(build(args.source, args.output, args.voice))
