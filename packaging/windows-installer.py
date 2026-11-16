from pathlib import Path
from zipfile import ZipFile
import subprocess

repo = Path(__file__).resolve().parents[1]
build = repo / "build"
payload = build / "windows-payload"
with ZipFile(build / "pdf-Converter-Windows-x64.zip") as archive:
    archive.extractall(payload)
root = payload / "pdf Converter"
commands = []
for path in sorted(root.rglob("*"), key=lambda p: len(p.parts), reverse=True):
    relative = str(path.relative_to(root)).replace("/", "\\")
    action = "RMDir" if path.is_dir() else "Delete"
    commands.append(f'{action} "$INSTDIR\\{relative}"')
(build / "remove-payload.nsh").write_text("\n".join(commands))
subprocess.run(["makensis", "windows.nsi"], cwd=repo/"packaging", check=True)
