"""Validate generated icon slots and PNG headers without Pillow on CI."""
import json
from pathlib import Path
import plistlib
import struct
import unittest
ROOT=Path(__file__).resolve().parents[1]

class Icons(unittest.TestCase):
    def test_iphone_icon_catalog(self):
        folder=ROOT/'ios/Assets.xcassets/AppIcon.appiconset'
        images=json.loads((folder/'Contents.json').read_text())['images']
        slots={(i['idiom'],i['size'],i['scale']) for i in images}
        expected={('iphone',size,scale) for size in ('20x20','29x29','40x40','60x60') for scale in ('2x','3x')}
        self.assertEqual(slots,expected|{('ios-marketing','1024x1024','1x')})
        for item in images:
            data=(folder/item['filename']).read_bytes()
            self.assertEqual(data[:8],b'\x89PNG\r\n\x1a\n')
            w,h,depth,color=struct.unpack('>IIBB',data[16:26])
            expected_size=int(item['size'].split('x')[0])*int(item['scale'][0])
            self.assertEqual((w,h),(expected_size,expected_size))
            self.assertEqual((depth,color),(8,2)) # RGB, no alpha channel
        info=plistlib.loads((ROOT/'ios/Info.plist').read_bytes())
        self.assertEqual(info['CFBundleIcons']['CFBundlePrimaryIcon']['CFBundleIconName'],'AppIcon')
