"""Build the CurseForge addon archive from the repository root."""

from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


root = Path(__file__).resolve().parent
addon = root / "CraftGlance"
toc = addon / "CraftGlance_Camelot.toc"
lines = toc.read_text(encoding="utf-8").splitlines()
version = next(line.split(": ", 1)[1] for line in lines if line.startswith("## Version: "))
output = root / "dist" / f"CraftGlance-{version}.zip"
output.parent.mkdir(exist_ok=True)

with ZipFile(output, "w", compression=ZIP_DEFLATED) as archive:
    for file in [toc, *(addon / line for line in lines if line and not line.startswith("#"))]:
        archive.write(file, f"CraftGlance/{file.name}")
    archive.write(root / "LICENSE", "CraftGlance/LICENSE")

print(output)
