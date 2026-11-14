"""Verify the vendored audio dependencies without downloading anything."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
lock = json.loads((root / 'audio-dependencies.lock.json').read_text(encoding='utf-8'))
for relative, expected in lock['files'].items():
    data = (root / relative).read_bytes()
    if hashlib.sha256(data).hexdigest() != expected:
        raise SystemExit(f'Audio dependency checksum mismatch: {relative}')
font = (root / 'ios/SoundFont/GeneralUser-GS-SoftSynth-1.44.sf2').read_bytes()
if font[:4] != b'RIFF' or font[8:12] != b'sfbk':
    raise SystemExit('The bundled SoundFont is not an SF2 bank')
print('SoundFont bank, synthesizer headers and licenses verified.')
