# pdf Converter

A native macOS app for converting Office documents, text files and images to PDF. Scan mode detects paper edges in a photo, corrects perspective and improves text contrast. Files are processed locally.

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
