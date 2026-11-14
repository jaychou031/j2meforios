"""Exercise ZIP structure and failure paths without pretending to compile iOS."""
import pathlib
import plistlib
import subprocess
import struct
import sys
import tempfile
import unittest
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]

class Packaging(unittest.TestCase):
    def test_device_archive_and_wrong_architecture(self):
        temp_root = ROOT / 'build/tmp'
        temp_root.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=temp_root) as directory:
            directory = pathlib.Path(directory)
            app = directory / 'Test.app'
            app.mkdir()
            (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable':'Test','MinimumOSVersion':'15.5'}))
            # Synthetic Mach-O header: tests only packaging, not executable validity.
            binary = app / 'Test'
            header = struct.pack('<IIIIIIII', 0xFEEDFACF, 0x100000C, 0, 2, 1, 24, 0, 0)
            command = struct.pack('<IIIIII', 0x32, 24, 2, 0x000F0500, 0x00120500, 0)
            binary.write_bytes(header + command)
            output = directory / 'Test.ipa'
            command = [sys.executable, str(ROOT / 'scripts/package-ipa.py'), str(app), str(output)]
            subprocess.run(command, check=True, capture_output=True)
            with zipfile.ZipFile(output) as archive:
                self.assertEqual(set(archive.namelist()), {'Payload/Test.app/Test','Payload/Test.app/Info.plist'})
                self.assertEqual(archive.getinfo('Payload/Test.app/Test').external_attr >> 16, 0o100755)
            binary.write_bytes(b'\xcf\xfa\xed\xfe\x07\x00\x00\x01' + b'\x00'*24)
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('arm64', result.stderr)
            binary.write_bytes(header + struct.pack('<IIIIII', 0x32, 24, 7, 0x000F0500, 0x00120500, 0))
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('simulator', result.stderr)

    def test_orientation_and_deployment(self):
        info = plistlib.loads((ROOT / 'ios/Info.plist').read_bytes())
        self.assertEqual(info['MinimumOSVersion'], '15.5')
        self.assertEqual(set(info['UISupportedInterfaceOrientations']), {
            'UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'})
        self.assertNotIn('UIBackgroundModes', info)

if __name__ == '__main__':
    unittest.main()
