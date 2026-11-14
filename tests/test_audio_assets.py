"""Test vendored hashes and the device-bundle resource gate without an SDK."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class AudioAssets(unittest.TestCase):
    def test_pinned_files(self):
        subprocess.run([sys.executable, str(ROOT / 'scripts/verify-audio.py')],
                       check=True, capture_output=True)

    def test_bundle_requires_font_and_notices(self):
        temp = ROOT / 'build/tmp'
        temp.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=temp) as folder:
            app = Path(folder) / 'Test.app'
            (app / 'TinySoundFont').mkdir(parents=True)
            for source, target in {
                'ios/SoundFont/GeneralUser-GS-SoftSynth-1.44.sf2': 'GeneralUser-GS-SoftSynth-1.44.sf2',
                'ios/SoundFont/GeneralUser-LICENSE.txt': 'GeneralUser-LICENSE.txt',
                'third_party/TinySoundFont/LICENSE': 'TinySoundFont/LICENSE',
            }.items():
                # Same-volume hard links avoid copying 30 MB during this test.
                # The test reads/deletes links only; it never modifies content.
                os.link(ROOT / source, app / target)
            command = [sys.executable, str(ROOT / 'scripts/verify-app-audio.py'), str(app)]
            subprocess.run(command, check=True, capture_output=True)
            (app / 'GeneralUser-GS-SoftSynth-1.44.sf2').unlink()
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Missing or altered', result.stderr)


if __name__ == '__main__':
    unittest.main()
