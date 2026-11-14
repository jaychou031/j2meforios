"""Fail a device build if the sound bank or required notices missed the bundle."""
import hashlib
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
app = Path(sys.argv[1])
lock = json.loads((root / 'audio-dependencies.lock.json').read_text(encoding='utf-8'))
for source, bundled in {
    'ios/SoundFont/GeneralUser-GS-SoftSynth-1.44.sf2': 'GeneralUser-GS-SoftSynth-1.44.sf2',
    'ios/SoundFont/GeneralUser-LICENSE.txt': 'GeneralUser-LICENSE.txt',
    'third_party/TinySoundFont/LICENSE': 'TinySoundFont/LICENSE',
}.items():
    file = app / bundled
    if not file.is_file() or hashlib.sha256(file.read_bytes()).hexdigest() != lock['files'][source]:
        raise SystemExit(f'Missing or altered bundled audio resource: {file}')
print('Device app contains the verified SoundFont and license notices.')
