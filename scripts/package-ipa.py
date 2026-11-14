"""Package a device .app without requiring an Apple signing certificate."""
import pathlib
import plistlib
import sys
import struct
import zipfile

app, out = map(pathlib.Path, sys.argv[1:])
info = plistlib.loads((app / 'Info.plist').read_bytes())
binary = app / info['CFBundleExecutable']
data = binary.read_bytes()
header = data[:12]
assert header[:4] == b'\xcf\xfa\xed\xfe', 'Expected a 64-bit Mach-O executable'
assert int.from_bytes(header[4:8], 'little') == 0x100000C, 'Expected arm64 device executable'
assert len(data) >= 32, 'Truncated Mach-O header'
ncmds, sizeofcmds = struct.unpack_from('<II', data, 16)
assert 32 + sizeofcmds <= len(data), 'Truncated load commands'
offset = 32
device = False
for _ in range(ncmds):
    assert offset + 8 <= 32 + sizeofcmds, 'Truncated load command'
    command, size = struct.unpack_from('<II', data, offset)
    assert size >= 8 and offset + size <= 32 + sizeofcmds, 'Invalid load command size'
    if command == 0x32:  # LC_BUILD_VERSION; arm64 alone does not exclude a simulator build.
        assert size >= 24
        platform, minimum = struct.unpack_from('<II', data, offset + 8)
        assert platform == 2, 'Expected iOS device platform, not simulator/macOS'
        assert minimum == 0x000F0500, 'Expected binary deployment target iOS 15.5'
        device = True
    offset += size
assert device, 'Missing device platform load command'
assert info['MinimumOSVersion'] == '15.5'
out.parent.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as archive:
    for file in sorted(app.rglob('*')):
        if file.is_file():
            entry = zipfile.ZipInfo('Payload/' + app.name + '/' + file.relative_to(app).as_posix())
            entry.create_system = 3
            entry.external_attr = (0o100755 if file == binary else 0o100644) << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, file.read_bytes())
with zipfile.ZipFile(out) as archive:
    assert archive.testzip() is None
print(out)
