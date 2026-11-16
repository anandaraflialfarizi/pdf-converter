import Foundation
import AppKit
import CoreGraphics
import ImageIO
import Vision
import CoreImage
import PDFKit
import Darwin

enum PDFConversionError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

enum PDFConverter {
    static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "bmp", "gif", "webp"]
    static let supportedExtensions: Set<String> = imageExtensions.union([
        "doc", "docx", "odt", "rtf", "txt", "xls", "xlsx", "ods", "csv", "ppt", "pptx", "odp", "pdf"
    ])

    static func convert(_ input: URL, to directory: URL, engine: URL, scanImages: Bool = false) throws -> URL {
        let fileManager = FileManager.default
        guard input.isFileURL, directory.isFileURL else {
            throw PDFConversionError.message(NSLocalizedString("Choose a local file and folder on your Mac.", comment: ""))
        }
        let properties: URLResourceValues
        do {
            properties = try input.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        } catch {
            throw PDFConversionError.message(NSLocalizedString("Cannot read the file. Check its location and permissions.", comment: ""))
        }
        guard properties.isRegularFile == true, fileManager.isReadableFile(atPath: input.path) else {
            throw PDFConversionError.message(NSLocalizedString("Choose a readable file.", comment: ""))
        }
        guard let size = properties.fileSize, size > 0, size <= 200 * 1_024 * 1_024 else {
            throw PDFConversionError.message(NSLocalizedString("The file must contain data and be no larger than 200 MB.", comment: ""))
        }
        let fileExtension = input.pathExtension.lowercased()
        guard supportedExtensions.contains(fileExtension) else {
            throw PDFConversionError.message(String(format: NSLocalizedString("The .%@ format is unsupported.", comment: ""), String(describing: fileExtension)))
        }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue, fileManager.isWritableFile(atPath: directory.path) else {
            throw PDFConversionError.message(NSLocalizedString("The output folder is unavailable or cannot be written to.", comment: ""))
        }

        let temporary = fileManager.temporaryDirectory.appendingPathComponent("PDFLokal-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporary) }
        let converted: URL
        if fileExtension == "pdf" {
            converted = input
        } else if imageExtensions.contains(fileExtension) {
            converted = temporary.appendingPathComponent("image.pdf")
            try convertImage(input, to: converted, scan: scanImages)
        } else {
            converted = try convertDocument(input, temporary: temporary, engine: engine)
        }
        guard let document = PDFDocument(url: converted), !document.isLocked, document.pageCount > 0 else {
            throw PDFConversionError.message(NSLocalizedString("Cannot read the PDF. It may be damaged or password protected.", comment: ""))
        }
        return try publish(converted, named: input.deletingPathExtension().lastPathComponent, in: directory)
    }

    private static func convertImage(_ input: URL, to output: URL, scan: Bool) throws {
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil), CGImageSourceGetCount(source) > 0 else {
            throw PDFConversionError.message(NSLocalizedString("Cannot read the image. It may be damaged or its format may be unavailable on this Mac.", comment: ""))
        }
        guard let consumer = CGDataConsumer(url: output as CFURL) else {
            throw PDFConversionError.message(NSLocalizedString("Cannot create the temporary PDF.", comment: ""))
        }
        var initialBounds = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        guard let context = CGContext(consumer: consumer, mediaBox: &initialBounds, nil) else {
            throw PDFConversionError.message(NSLocalizedString("Cannot start creating the PDF.", comment: ""))
        }
        defer { context.closePDF() }
        let isTIFF = ["tif", "tiff"].contains(input.pathExtension.lowercased())
        // shortcut: animasi memakai bingkai pertama; tambahkan pilihan bingkai jika ekspor animasi diperlukan.
        let pageCount = isTIFF ? CGImageSourceGetCount(source) : 1
        for index in 0..<pageCount {
            // Batasi memori saat meluruskan foto beresolusi besar.
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: scan ? 8_192 : 6_000,
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let original = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else {
                throw PDFConversionError.message(String(format: NSLocalizedString("Cannot read image page %@.", comment: ""), String(describing: index + 1)))
            }
            let image = scan ? try scanPage(original) : original
            let landscape = image.width > image.height
            var bounds = CGRect(x: 0, y: 0, width: landscape ? 841.89 : 595.28, height: landscape ? 595.28 : 841.89)
            let mediaBox = NSData(bytes: &bounds, length: MemoryLayout<CGRect>.size)
            context.beginPDFPage([kCGPDFContextMediaBox: mediaBox] as CFDictionary)
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(bounds)
            let area = scan ? bounds : bounds.insetBy(dx: 24, dy: 24)
            let scale = min(area.width / CGFloat(image.width), area.height / CGFloat(image.height))
            let width = CGFloat(image.width) * scale
            let height = CGFloat(image.height) * scale
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: (bounds.width - width) / 2, y: (bounds.height - height) / 2, width: width, height: height))
            context.endPDFPage()
        }
    }

    private static let scanContext = CIContext()
    static func scanPage(_ photo: CGImage) throws -> CGImage {
        let handler = VNImageRequestHandler(cgImage: photo)
        let segmentation = VNDetectDocumentSegmentationRequest()
        try? handler.perform([segmentation])
        var detected = segmentation.results?.first(where: { $0.confidence >= 0.65 && $0.boundingBox.width * $0.boundingBox.height > 0.10 })
        if detected == nil {
            let request = VNDetectRectanglesRequest()
            request.maximumObservations = 8
            request.minimumSize = 0.2
            request.minimumAspectRatio = 0.2
            request.quadratureTolerance = 35
            try handler.perform([request])
            let candidates = (request.results ?? []).filter { $0.boundingBox.width * $0.boundingBox.height > 0.12 }
            detected = candidates.max { $0.boundingBox.width * $0.boundingBox.height * CGFloat($0.confidence)
                < $1.boundingBox.width * $1.boundingBox.height * CGFloat($1.confidence) }
        }
        guard let page = detected else {
            throw PDFConversionError.message(NSLocalizedString("Cannot detect the paper edges. Choose a photo showing all four corners.", comment: ""))
        }
        func pixel(_ point: CGPoint) -> CIVector {
            CIVector(x: point.x * CGFloat(photo.width), y: point.y * CGFloat(photo.height))
        }
        let straight = CIImage(cgImage: photo).applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": pixel(page.topLeft), "inputTopRight": pixel(page.topRight),
            "inputBottomLeft": pixel(page.bottomLeft), "inputBottomRight": pixel(page.bottomRight)
        ])
        let gray = straight.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
        let paper = gray.clampedToExtent().applyingGaussianBlur(sigma: max(8, gray.extent.width / 55)).cropped(to: gray.extent)
        let cleaned = paper.applyingFilter("CIDivideBlendMode", parameters: [kCIInputBackgroundImageKey: gray])
            .applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.15])
        let sharpened = cleaned.applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: 0.3])
        guard let result = scanContext.createCGImage(sharpened, from: gray.extent) else {
            throw PDFConversionError.message(NSLocalizedString("Cannot process the photo. Try one with even lighting.", comment: ""))
        }
        return result
    }

    private static func convertDocument(_ input: URL, temporary: URL, engine: URL) throws -> URL {
        let fileManager = FileManager.default
        guard engine.isFileURL, fileManager.isExecutableFile(atPath: engine.path) else {
            throw PDFConversionError.message(NSLocalizedString("The document converter is missing. Use a complete copy of pdf Converter.", comment: ""))
        }
        let profile = temporary.appendingPathComponent("profile", isDirectory: true)
        let userProfile = profile.appendingPathComponent("user", isDirectory: true)
        let output = temporary.appendingPathComponent("result", isDirectory: true)
        try fileManager.createDirectory(at: userProfile, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: output, withIntermediateDirectories: true)
        let settings = """
        <?xml version="1.0" encoding="UTF-8"?>
        <oor:items xmlns:oor="http://openoffice.org/2001/registry">
          <item oor:path="/org.openoffice.Office.Common/Security/Scripting">
            <prop oor:name="MacroSecurityLevel" oor:op="fuse"><value>3</value></prop>
            <prop oor:name="DisableMacrosExecution" oor:op="fuse"><value>true</value></prop>
          </item>
        </oor:items>
        """
        try settings.write(to: userProfile.appendingPathComponent("registrymodifications.xcu"), atomically: true, encoding: .utf8)
        let logURL = temporary.appendingPathComponent("conversion.log")
        guard fileManager.createFile(atPath: logURL.path, contents: nil) else {
            throw PDFConversionError.message(NSLocalizedString("Cannot create the temporary conversion log.", comment: ""))
        }
        let log = try FileHandle(forWritingTo: logURL)
        defer { try? log.close() }
        let process = Process()
        process.executableURL = engine
        process.arguments = [
            "-env:UserInstallation=\(profile.absoluteString)",
            "--headless", "--norestore", "--nodefault", "--nofirststartwizard",
            "--convert-to", "pdf", "--outdir", output.path, input.path
        ]
        process.standardOutput = log
        process.standardError = log
        process.standardInput = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do {
            try process.run()
        } catch {
            throw PDFConversionError.message(String(format: NSLocalizedString("Cannot start the converter: %@", comment: ""), String(describing: error.localizedDescription)))
        }
        if finished.wait(timeout: .now() + 120) == .timedOut {
            process.terminate()
            if finished.wait(timeout: .now() + 3) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
            }
            process.waitUntilExit()
            throw PDFConversionError.message(NSLocalizedString("Conversion exceeded two minutes. Try a smaller document or check its password.", comment: ""))
        }
        // shortcut: tata letak Office mengikuti LibreOffice; gunakan ekspor aplikasi asal untuk kecocokan cetak yang persis.
        let result = output.appendingPathComponent(input.deletingPathExtension().lastPathComponent).appendingPathExtension("pdf")
        guard process.terminationStatus == 0, fileManager.fileExists(atPath: result.path) else {
            throw PDFConversionError.message(NSLocalizedString("Cannot convert the document. It may be damaged, password protected, or contain unsupported features.", comment: ""))
        }
        return result
    }

    private static func publish(_ source: URL, named baseName: String, in directory: URL) throws -> URL {
        let fileManager = FileManager.default
        let staged = directory.appendingPathComponent(".PDFLokal-\(UUID().uuidString).pdf")
        defer { try? fileManager.removeItem(at: staged) }
        do {
            try fileManager.copyItem(at: source, to: staged)
        } catch {
            throw PDFConversionError.message(NSLocalizedString("Cannot save the PDF. Check folder permissions and available storage.", comment: ""))
        }
        var suffix = 1
        while true {
            let name = suffix == 1 ? baseName : "\(baseName) (\(suffix))"
            let destination = directory.appendingPathComponent(name).appendingPathExtension("pdf")
            if renamex_np(staged.path, destination.path, UInt32(RENAME_EXCL)) == 0 {
                return destination
            }
            guard errno == EEXIST else {
                throw PDFConversionError.message(NSLocalizedString("Cannot safely save the PDF here. Choose another folder on your Mac.", comment: ""))
            }
            suffix += 1
        }
    }
}
