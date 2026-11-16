import AppKit
import PDFKit

@main
struct ConverterTests {
    static func main() throws {
        precondition(CommandLine.arguments.count == 4, "Usage: tests FIXTURES OUTPUT ENGINE")
        _ = NSApplication.shared
        let fixtures = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        let engine = URL(fileURLWithPath: CommandLine.arguments[3])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var checks = 0

        func require(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }
        func convert(_ filename: String, pages: Int? = nil, text: String? = nil) throws -> URL {
            let source = fixtures.appendingPathComponent(filename)
            let original = try Data(contentsOf: source)
            let result = try PDFConverter.convert(source, to: output, engine: engine)
            let document = PDFDocument(url: result)
            require(document != nil && document!.pageCount > 0, "Unreadable PDF: \(filename)")
            if let pages { require(document!.pageCount == pages, "Page count: \(filename)") }
            if let text {
                let normalized = (document!.string ?? "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
                require(normalized.contains(text), "Missing text in \(filename): \(normalized)")
            }
            let unchanged = try Data(contentsOf: source)
            require(unchanged == original, "Original changed: \(filename)")
            print("PASS \(filename) -> \(result.lastPathComponent), \(document!.pageCount) page(s)")
            return result
        }
        func expectFailure(_ filename: String, destination: URL? = nil) {
            do {
                _ = try PDFConverter.convert(fixtures.appendingPathComponent(filename), to: destination ?? output, engine: engine)
                preconditionFailure("Expected rejection: \(filename)")
            } catch {
                require(!error.localizedDescription.isEmpty, "Missing failure message")
                print("PASS rejected \(filename): \(error.localizedDescription)")
            }
        }
        func coloredBounds(_ file: URL) -> CGRect {
            let document = PDFDocument(url: file)!
            let page = document.page(at: 0)!
            let image = withExtendedLifetime(document) {
                page.thumbnail(of: NSSize(width: 400, height: 600), for: .mediaBox)
            }
            let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
            var minX = bitmap.pixelsWide, minY = bitmap.pixelsHigh, maxX = 0, maxY = 0
            for y in stride(from: 0, to: bitmap.pixelsHigh, by: 2) {
                for x in stride(from: 0, to: bitmap.pixelsWide, by: 2) {
                    guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                    if max(color.redComponent, color.blueComponent) > 0.6 && color.greenComponent < 0.3 {
                        minX = min(minX, x); minY = min(minY, y)
                        maxX = max(maxX, x); maxY = max(maxY, y)
                    }
                }
            }
            require(maxX > minX && maxY > minY, "No image content rendered")
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }

        let png = try convert("gambar.png", pages: 1)
        let originalPDF = try Data(contentsOf: png)
        let jpg = try convert("gambar.jpg", pages: 1)
        require(png != jpg, "Same stem overwrote output")
        let afterCollision = try Data(contentsOf: png)
        require(afterCollision == originalPDF, "Existing PDF changed on collision")
        let repeatPNG = try convert("gambar.png", pages: 1)
        require(repeatPNG != png && repeatPNG != jpg, "Repeated name collision")
        let oriented = try convert("orientasi.jpg", pages: 1)
        let plainBounds = coloredBounds(jpg), rotatedBounds = coloredBounds(oriented)
        require(plainBounds.width > plainBounds.height * 1.8, "JPEG aspect ratio changed")
        require(rotatedBounds.height > rotatedBounds.width * 1.8, "EXIF orientation ignored")
        _ = try convert("dua-halaman.tiff", pages: 2)
        _ = try convert("animasi.gif", pages: 1)
        for filename in ["dokumen.docx", "lembar.xlsx", "presentasi.pptx", "catatan.txt", "catatan.rtf", "tabel.csv"] {
            _ = try convert(filename, text: "Uji konversi Indonesia 123")
        }
        let copied = try PDFConverter.convert(png, to: output, engine: engine)
        let copiedBytes = try Data(contentsOf: copied)
        require(copied != png && copiedBytes == originalPDF, "PDF copy should preserve bytes and original")
        expectFailure("unsupported.xyz")
        expectFailure("rusak.png")
        expectFailure("missing.png")
        expectFailure("gambar.png", destination: fixtures.appendingPathComponent("catatan.txt"))
        expectFailure("gambar.png", destination: output.appendingPathComponent("not-created"))
        expectFailure(".")
        print("PASS: \(checks) assertions; originals preserved, conversion, orientation and error cases verified.")
    }
}
