"""Prepare reproducible prototype assets with official fonts and local macOS TTS.

Run from app/: python3 tool/prepare_assets.py
Narration reads the exact prepared story text; it does not call an AI service.
"""
import concurrent.futures
import json
from pathlib import Path
import subprocess
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
FONTS = {
    'Poppins-Regular.ttf': 'ofl/poppins/Poppins-Regular.ttf',
    'Poppins-Medium.ttf': 'ofl/poppins/Poppins-Medium.ttf',
    'Poppins-SemiBold.ttf': 'ofl/poppins/Poppins-SemiBold.ttf',
    'Inter.ttf': 'ofl/inter/Inter%5Bopsz,wght%5D.ttf',
    'Poppins-OFL.txt': 'ofl/poppins/OFL.txt',
    'Inter-OFL.txt': 'ofl/inter/OFL.txt',
}


def font_asset(item):
    name, remote = item
    target = ROOT / 'assets/fonts' / name
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists():
        urllib.request.urlretrieve('https://raw.githubusercontent.com/google/fonts/main/' + remote, target)
    return name


def speech_asset(job):
    voice, story_id, text = job
    target = ROOT / 'assets/audio' / voice['id'] / (story_id + '.m4a')
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and target.stat().st_size > 1000:
        return str(target.relative_to(ROOT))
    with tempfile.TemporaryDirectory(prefix='ov-narration-') as temporary:
        text_path = Path(temporary) / 'story.txt'
        audio_path = Path(temporary) / 'story.aiff'
        text_path.write_text(text)
        subprocess.run(['say', '-v', voice['systemVoice'], '-r', '155', '-f', str(text_path), '-o', str(audio_path)], check=True, capture_output=True)
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(audio_path), '-c:a', 'aac', '-b:a', '64k', '-movflags', '+faststart', str(target)], check=True, capture_output=True)
    return str(target.relative_to(ROOT))


if __name__ == '__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for name in pool.map(font_asset, FONTS.items()):
            print('Font:', name, flush=True)
    manifest = json.loads((ROOT / 'tool/narration_manifest.json').read_text())
    jobs = []
    for voice in manifest['voices']:
        jobs.append((voice, 'preview', 'Welcome to Öv. Every place on the steppe has a story. This is a prepared demo narration, ready to accompany your journey.'))
        for story in manifest['templates']:
            jobs.append((voice, story['id'], story['text']))
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for path in pool.map(speech_asset, jobs):
            print('Narration:', path, flush=True)
    print('Prepared', len(jobs), 'audio assets.', flush=True)
