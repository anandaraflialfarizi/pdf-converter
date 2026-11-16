# pdf Converter

A desktop app for macOS and Windows for converting Office documents, text files and images to PDF. Scan mode detects paper edges in a photo, corrects perspective and improves text contrast. Files are processed locally.

## Build on macOS

Install Xcode Command Line Tools and LibreOffice for your Mac, then run:

```sh
bash build.sh /Applications/LibreOffice.app
```

Open **build/pdf Converter.app**, or copy it to Applications. The build includes the supplied LibreOffice engine with its original license notices.

## English

Choose **Add files…**, optionally select **Scan documents from photos**, then choose **Save PDFs…**. Each input produces a separate PDF. Existing output files receive a numbered suffix when names collide.

## Bahasa Indonesia

Pilih **Tambah file…**, centang **Scan dokumen dari foto** untuk memindai foto kertas, lalu klik **Simpan PDF…**. Setiap file menghasilkan satu PDF. Jika nama sudah digunakan, aplikasi menambahkan nomor pada nama hasil.

## Language / Bahasa

The app follows your preferred macOS language. To override it for this app, open **System Settings → General → Language & Region → Applications**, select **pdf Converter**, choose **English** or **Bahasa Indonesia**, then reopen the app.

## Windows 10/11 (x64)

Download the Windows ZIP from [Releases](../../releases), extract the entire folder and double-click **pdf Converter.cmd**. Python and the image converter are included. Install [LibreOffice for Windows](https://www.libreoffice.org/download/download-libreoffice/) for Word, Excel, PowerPoint, RTF, text and OpenDocument input. For PDFs and supported images, the app works independently. Windows photo inputs are JPG, PNG, TIFF, BMP, GIF and WebP. For animated images the first frame is used. Choose English or Bahasa Indonesia in the window.

**Bahasa Indonesia.** Ekstrak seluruh ZIP, lalu klik dua kali **pdf Converter.cmd**. Pasang LibreOffice untuk mengubah dokumen Office. Untuk scan, pilih foto, centang **Scan dokumen dari foto**, lalu klik **Simpan PDF…**.

To build the portable ZIP, run `python windows/package.py` with Python 3 and pip. This downloads official Windows x64 wheels and the embeddable CPython distribution.

## Credits / Kredit

LibreOffice by The Document Foundation and its contributors powers Office conversion. macOS uses Apple frameworks for the interface, scanning and PDF output. Windows uses Python, wxPython/wxWidgets, Pillow, NumPy, OpenCV and pypdf. Project links, license information and attribution are available in [CREDITS.txt](CREDITS.txt) and through the app's **Third-party credits / Kredit pihak ketiga** command.
