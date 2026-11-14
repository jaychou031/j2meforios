"""Run the actual upstream demo twice; assert input and persistent RMS results."""
import os
import pathlib
import subprocess
import sys
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]
temporary = root / 'build/tmp'
temporary.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(dir=temporary) as folder:
    env = dict(os.environ, XDG_CONFIG_HOME=folder, XDG_DATA_HOME=folder)
    for boot in (1, 2):
        command = [str(pathlib.Path(sys.argv[1]).resolve()), '--port', 'headless',
                   '--size', '240x320', '--heap', '32', '--device', 'nokia6230',
                   '--run-frames', '60', '--fps', '60', '--keys', '10:53',
                   '--rms-dir', folder, str(root / 'upstream/esp32s31-korvo-nano-j2me/assets/korvo_demo.jar')]
        result = subprocess.run(command, text=True, capture_output=True, timeout=45, env=env)
        output = result.stdout + result.stderr
        (root / f'build/demo-boot-{boot}.log').write_text(output, encoding='utf-8')
        if result.returncode or f'DEMO_RMS_BOOT={boot}' not in output or 'DEMO_KEY_DOWN=53' not in output:
            raise SystemExit(f'Demo smoke test failed on boot {boot}:\n{output}')
print('Actual core: demo startup, key event and RMS persistence passed.')
