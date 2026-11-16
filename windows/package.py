"""Build a portable Windows x64 ZIP from official CPython and PyPI wheels."""
import shutil
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory
from urllib.request import urlretrieve
from zipfile import ZipFile

src = Path(__file__).resolve().parent
out = src.parent / "build"
out.mkdir(exist_ok=True)
with TemporaryDirectory() as temp:
    tmp = Path(temp)
    root = tmp / "pdf Converter"
    runtime = root / "runtime"
    runtime.mkdir(parents=True)
    urlretrieve("https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-amd64.zip",tmp/"python.zip")
    with ZipFile(tmp/"python.zip") as archive:
        archive.extractall(runtime)
    wheels = Path(sys.argv[1]).resolve() if len(sys.argv)>1 else tmp/"wheels"
    subprocess.run([sys.executable,"-m","pip","download","--platform","win_amd64","--python-version","312","--implementation","cp","--abi","cp312","--only-binary=:all:","--dest",str(wheels),"-r",str(src/"requirements.txt")],check=True)
    packages = runtime/"Lib/site-packages"
    for wheel in wheels.glob("*.whl"):
        with ZipFile(wheel) as archive:
            archive.extractall(packages)
    (runtime/"python312._pth").write_text("python312.zip\n.\n..\nLib/site-packages\nimport site\n")
    for name in ("app.pyw","converter.py","AppIcon.ico"):
        shutil.copy(src/name,root/name)
    shutil.copy(src.parent/"CREDITS.txt",root)
    (root/"pdf Converter.cmd").write_bytes(b'@echo off\r\ncd /d "%~dp0"\r\nstart "" "runtime\\pythonw.exe" "app.pyw"\r\n')
    target = shutil.make_archive(str(out/"pdf-Converter-Windows-x64"),"zip",tmp,root.name)
    print(target)
