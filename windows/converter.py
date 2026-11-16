import os
import shutil
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory

import cv2
import numpy as np
from PIL import Image, ImageOps
from pypdf import PdfReader

IMAGES = set("png jpg jpeg tif tiff bmp gif webp".split())
DOCUMENTS = set("doc docx odt xls xlsx ods csv ppt pptx odp rtf txt".split())
SUPPORTED = IMAGES | DOCUMENTS | {"pdf"}


class ConversionError(Exception):
    def __init__(self, en, id):
        super().__init__(en)
        self.id = id


def scan(photo):
    rgb = np.asarray(photo)
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    ratio = min(1, 1400 / max(gray.shape))
    preview = cv2.resize(gray, None, fx=ratio, fy=ratio, interpolation=cv2.INTER_AREA)
    edges = cv2.Canny(cv2.GaussianBlur(preview, (5, 5), 0), 35, 110)
    edges = cv2.morphologyEx(edges, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
    contours, _ = cv2.findContours(edges, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    for contour in sorted(contours, key=cv2.contourArea, reverse=True):
        if cv2.contourArea(contour) < preview.size * 0.1:
            break
        quad = cv2.approxPolyDP(contour, 0.02 * cv2.arcLength(contour, True), True)
        if len(quad) != 4 or not cv2.isContourConvex(quad):
            continue
        corners = quad.reshape(4, 2).astype(np.float32) / ratio
        center = corners.mean(axis=0)
        corners = corners[np.argsort(np.arctan2(corners[:, 1]-center[1], corners[:, 0]-center[0]))]
        corners = np.roll(corners, -corners.sum(axis=1).argmin(), axis=0)
        a, b, c, d = corners
        w = round(max(np.linalg.norm(a-b), np.linalg.norm(c-d)))
        h = round(max(np.linalg.norm(a-d), np.linalg.norm(b-c)))
        if min(w, h) < 2:
            continue
        matrix = cv2.getPerspectiveTransform(corners, np.float32([[0,0],[w-1,0],[w-1,h-1],[0,h-1]]))
        page = cv2.warpPerspective(gray, matrix, (w, h))
        small = cv2.resize(page, (max(1,w//16), max(1,h//16)), interpolation=cv2.INTER_AREA)
        light = cv2.resize(cv2.GaussianBlur(small, (0,0), max(1,w/880)), (w,h))
        return Image.fromarray(cv2.divide(page, np.maximum(light,1), scale=255))
    raise ConversionError("Show all four paper corners in the photo.", "Gunakan foto dengan keempat sudut kertas terlihat.")


def office_engine():
    for key in ("ProgramFiles", "ProgramFiles(x86)"):
        path = Path(os.environ.get(key, "")) / "LibreOffice/program/soffice.com"
        if path.is_file():
            return str(path)
    return shutil.which("soffice.com") or shutil.which("soffice")


def convert(src, folder, scan_images=False):
    ext = src.suffix.lower()[1:]
    if ext not in SUPPORTED or not src.is_file() or not 0 < src.stat().st_size <= 200*1024**2:
        raise ConversionError("Choose a supported file up to 200 MB.", "Pilih file yang didukung hingga 200 MB.")
    with TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        output = tmp / (src.stem + ".pdf")
        if ext == "pdf":
            output = src
        elif ext in IMAGES:
            with Image.open(src) as im:
                pages = []
                for i in range(im.n_frames if ext in {"tif","tiff"} else 1):
                    im.seek(i)
                    photo = ImageOps.exif_transpose(im).convert("RGB")
                    photo.thumbnail((8192,8192), Image.Resampling.LANCZOS)
                    pages.append(scan(photo) if scan_images else photo)
                pages[0].save(output, "PDF", resolution=300, quality=95, save_all=True, append_images=pages[1:])
        else:
            engine = office_engine()
            if not engine:
                raise ConversionError("Install LibreOffice to convert Office files.", "Pasang LibreOffice untuk mengonversi dokumen Office.")
            profile = tmp / "profile"
            (profile/"user").mkdir(parents=True)
            (profile/"user/registrymodifications.xcu").write_text('<oor:items xmlns:oor="http://openoffice.org/2001/registry"><item oor:path="/org.openoffice.Office.Common/Security/Scripting"><prop oor:name="DisableMacrosExecution" oor:op="fuse"><value>true</value></prop></item></oor:items>')
            subprocess.run([engine, "-env:UserInstallation="+profile.as_uri(), "--headless", "--norestore", "--convert-to","pdf","--outdir",str(tmp),str(src)], check=True, timeout=120, capture_output=True)
        if not output.is_file() or not len(PdfReader(output).pages):
            raise ConversionError("No readable PDF was produced.", "PDF tidak dapat dibaca.")
        # Reserve the name exclusively, including on shared destination folders.
        suffix = 1
        while True:
            dst = folder / ((src.stem if suffix == 1 else f"{src.stem} ({suffix})") + ".pdf")
            try:
                handle = dst.open("xb")
            except FileExistsError:
                suffix += 1
                continue
            try:
                with handle, output.open("rb") as reader:
                    shutil.copyfileobj(reader, handle)
            except BaseException:
                dst.unlink(missing_ok=True)
                raise
            return dst
