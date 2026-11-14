"""Produce a small uploadable source archive; excludes downloads and upstream."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
root = Path(__file__).resolve().parents[1]
out = root / 'dist/j2meforios-source.zip'
out.parent.mkdir(exist_ok=True)
files = [root / x for x in ['.gitignore','AGENTS.md','CMakeLists.txt','upstream.lock.json','README.md','FEASIBILITY.md','STATUS.md']]
for folder in ['ios','scripts','tests','.github','cmake']:
    files.extend(p for p in (root / folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
with ZipFile(out, 'w', ZIP_DEFLATED) as archive:
    for path in sorted(files):
        archive.write(path, path.relative_to(root).as_posix())
with ZipFile(out) as archive:
    assert archive.testzip() is None
    assert '.github/workflows/ios.yml' in archive.namelist()
print(out)
