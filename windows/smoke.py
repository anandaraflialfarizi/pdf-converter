"""Run with the bundled interpreter to exercise the Windows UI and conversion."""
import sys
from pathlib import Path
from tempfile import TemporaryDirectory
from PIL import Image, ImageDraw
from pypdf import PdfReader
from converter import ConversionError, convert

with TemporaryDirectory() as tmp:
    root = Path(tmp)
    image = Image.new("RGB",(700,900),"#29292a")
    draw = ImageDraw.Draw(image)
    draw.polygon([(75,70),(610,110),(650,845),(50,810)],fill="white")
    draw.text((180,200),"pdf Converter",fill="black")
    image.save(root/"page.jpg")
    for scan in (False, True):
        output = convert(root/"page.jpg", root, scan)
        assert len(PdfReader(output).pages) == 1
    assert output.name == "page (2).pdf"
    assert convert(output,root).read_bytes() == output.read_bytes()
    try:
        convert(root/"missing.zip",root)
    except ConversionError:
        pass
    else:
        raise AssertionError("Unsupported format accepted")
    if sys.platform == "win32":
        import runpy, wx
        # Use the installed package's actual UI entry point.
        Window = runpy.run_path(str(Path(__import__("converter").__file__).with_name("app.pyw")))["Window"]
        app = wx.App(False)
        frame = Window()
        frame.language.SetSelection(1)
        frame.labels()
        assert frame.add.Label == "Tambah file…"
        frame.language.SetSelection(0)
        frame.labels()
        assert frame.add.Label == "Add files…"
        frame.Destroy()
print("PASS")
