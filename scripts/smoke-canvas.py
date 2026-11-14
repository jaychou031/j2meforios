"""Execute interface, virtual and legacy static Canvas key queries."""
import os
from pathlib import Path
import subprocess
import sys
import re
import tempfile
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tests'))
from canvas_fixture import create
temporary=root/'build/tmp'; temporary.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(dir=temporary) as folder:
    jar=Path(folder)/'probe.jar'; create(jar)
    env=dict(os.environ,XDG_CONFIG_HOME=folder,XDG_DATA_HOME=folder)
    result=subprocess.run([str(Path(sys.argv[1]).resolve()),'--port','headless','--fps','60','--run-frames','10','--rms-dir',folder,str(jar)],capture_output=True,timeout=30,env=env)
    output=(result.stdout+result.stderr).decode('utf-8','replace').replace('\r','')
    (root/'build/canvas-compat.log').write_text(output,encoding='utf-8')
    expected=[re.escape(f'{mode}_{method}=')+r'\s*'+str(value)+r'(?!\d)' for mode in ('IFACE','VIRTUAL','STATIC') for method,value in [('getGameAction',1),('getKeyCode',-1),('getKeyName',1)]]
    if result.returncode or any(not re.search(x,output) for x in expected) or 'AbstractMethodError' in output:
        raise SystemExit('Canvas dispatch regression failed:\n'+output)
print('Canvas key queries: all 9 interface/virtual/static results passed.')
