"""Verify cooperative yield makes bounded progress in the actual Java VM."""
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tests'))
from yield_fixture import create
temporary=root/'build/tmp'; temporary.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(dir=temporary) as folder:
    jar=Path(folder)/'yield.jar'; create(jar)
    env=dict(os.environ,XDG_CONFIG_HOME=folder,XDG_DATA_HOME=folder)
    result=subprocess.run([str(Path(sys.argv[1]).resolve()),'--port','headless','--fps','60','--run-frames','120','--rms-dir',folder,str(jar)],capture_output=True,timeout=30,env=env)
    output=(result.stdout+result.stderr).decode('utf-8','replace').replace('\r','')
    (root/'build/yield-compat.log').write_text(output,encoding='utf-8')
    found=re.search(r'YIELD_ELAPSED_MS=\s*(\d+)',output)
    if result.returncode or not found or not 96 <= int(found[1]) < 10000:
        raise SystemExit('Yield clock/suspension regression failed:\n'+output)
print('Cooperative yield: 96 calls completed and the VM clock advanced.')
