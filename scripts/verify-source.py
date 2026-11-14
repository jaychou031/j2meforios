"""Read-only validation of the manually downloaded source and pinned CI checkout."""
import json
import pathlib
import subprocess
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
lock = json.loads((ROOT / 'upstream.lock.json').read_text())
board = ROOT / 'upstream/esp32s31-korvo-nano-j2me'
core = board / 'third_party/nano_j2me'
for path, expected in [(board, lock['commit']), (core, lock['core_commit'])]:
    actual = subprocess.check_output(['git', '-c', f'safe.directory={path.as_posix()}', '-C', str(path), 'rev-parse', 'HEAD'], text=True).strip()
    if actual != expected:
        raise SystemExit(f'Unexpected source revision: {path}: {actual}, expected {expected}')
for path in [core / 'include/nj2me/nj_port.h', core / 'LICENSE', board / 'assets/korvo_demo.jar']:
    if not path.is_file():
        raise SystemExit(f'Missing source: {path}')
with zipfile.ZipFile(board / 'assets/korvo_demo.jar') as jar:
    assert jar.testzip() is None
    assert 'MIDlet-1:' in jar.read('META-INF/MANIFEST.MF').decode()
print('Pinned board/core revisions and demo archive verified.')
