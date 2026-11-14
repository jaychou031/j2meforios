"""Reproduce Windows clean conversion, then check the Linux checkout bytes."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class GitAudio(unittest.TestCase):
    def test_pinned_bytes_survive_autocrlf_and_checkout(self):
        lock = json.loads((ROOT / 'audio-dependencies.lock.json').read_text(encoding='utf-8'))
        temp = ROOT / 'build/tmp'
        temp.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=temp) as folder:
            repo = Path(folder) / 'repo'
            repo.mkdir()

            def git(*args):
                return subprocess.run(['git', '-c', f'safe.directory={repo.as_posix()}',
                                       '-C', str(repo), *args], check=True, capture_output=True).stdout

            git('init', '--quiet')
            git('config', '--local', 'core.autocrlf', 'true')
            git('config', '--local', 'core.safecrlf', 'false')
            # Original files, without attributes: reproduce the failed upload.
            for name in lock['files']:
                target = repo / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / name, target)
            git('add', '--', *lock['files'])
            name = 'third_party/TinySoundFont/tsf.h'
            self.assertNotEqual(hashlib.sha256(git('show', ':' + name)).hexdigest(), lock['files'][name])

            shutil.copyfile(ROOT / '.gitattributes', repo / '.gitattributes')
            git('add', '.gitattributes')
            git('add', '--renormalize', '--', *lock['files'])
            exported = Path(folder) / 'linux-checkout'
            exported.mkdir()
            git('-c', 'core.autocrlf=false', 'checkout-index', '--all',
                '--prefix=' + exported.as_posix() + '/')
            for name, expected in lock['files'].items():
                self.assertEqual(hashlib.sha256(git('show', ':' + name)).hexdigest(), expected, name)
                self.assertEqual(hashlib.sha256((exported / name).read_bytes()).hexdigest(), expected, name)


if __name__ == '__main__':
    unittest.main()
