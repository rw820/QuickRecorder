import AppKit
import CoreGraphics
import Foundation
import InterviewAssistantCore

enum ResumeTextExtractorTests {
    static let all = [
        TestCase(name: "可以提取 TXT 和 PDF 简历文字") {
            let directory = try temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let textURL = directory.appendingPathComponent("resume.txt")
            let pdfURL = directory.appendingPathComponent("resume.pdf")
            let content = "王小明 数据产品经理 八年零售数据经验"
            try content.write(
                to: textURL,
                atomically: true,
                encoding: .utf8
            )
            try makePDF(text: content, at: pdfURL)

            let extractor = ResumeTextExtractor()
            let textResult = try await extractor.extractText(from: textURL)
            let pdfResult = try await extractor.extractText(from: pdfURL)

            try expect(textResult.contains("数据产品经理"), "TXT 提取错误")
            try expect(pdfResult.contains("数据产品经理"), "PDF 提取错误")
        },
        TestCase(name: "可以提取 DOCX 和图片简历文字") {
            let directory = try temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let source = directory.appendingPathComponent("resume-source.txt")
            let docx = directory.appendingPathComponent("resume.docx")
            let image = directory.appendingPathComponent("resume.png")
            try "Resume Data Product Manager Experience".write(
                to: source,
                atomically: true,
                encoding: .utf8
            )
            try convertToDOCX(source: source, destination: docx)
            try makeImage(
                text: "Resume Data Product Manager",
                at: image
            )

            let extractor = ResumeTextExtractor()
            let wordResult = try await extractor.extractText(from: docx)
            let imageResult = try await extractor.extractText(from: image)

            try expect(wordResult.contains("Data Product"), "DOCX 提取错误")
            try expect(imageResult.contains("Resume"), "图片 OCR 错误")
        },
        TestCase(name: "伪文字层 PDF 会自动改用 OCR") {
            let directory = try temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let pdfURL = directory.appendingPathComponent("resume.pdf")
            try makePDFWithBogusTextLayer(
                visibleText: "Resume Finance Product Manager",
                at: pdfURL
            )

            let result = try await ResumeTextExtractor()
                .extractText(from: pdfURL)

            try expect(
                result.contains("Finance Product"),
                "重复乱码文字层应被忽略并改用 OCR，实际："
                    + String(result.prefix(160))
            )
        },
        TestCase(name: "不支持的简历格式会报错") {
            let directory = try temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let url = directory.appendingPathComponent("resume.csv")
            try "name,role".write(
                to: url,
                atomically: true,
                encoding: .utf8
            )

            do {
                _ = try await ResumeTextExtractor().extractText(from: url)
                throw TestFailure(description: "CSV 应被拒绝")
            } catch let error as ResumeExtractionError {
                try expect(
                    error == .unsupportedFormat("csv"),
                    "错误类型不正确"
                )
            }
        }
    ]

    private static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

    private static func makePDF(text: String, at url: URL) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard
            let consumer = CGDataConsumer(url: url as CFURL),
            let context = CGContext(
                consumer: consumer,
                mediaBox: &mediaBox,
                nil
            )
        else {
            throw TestFailure(description: "无法创建 PDF")
        }
        context.beginPDFPage(nil)
        let graphics = NSGraphicsContext(
            cgContext: context,
            flipped: false
        )
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        NSAttributedString(
            string: text,
            attributes: [.font: NSFont.systemFont(ofSize: 24)]
        ).draw(at: CGPoint(x: 50, y: 680))
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()
    }

    private static func makePDFWithBogusTextLayer(
        visibleText: String,
        at url: URL
    ) throws {
        let image = NSImage(size: NSSize(width: 1_200, height: 300))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 1_200, height: 300).fill()
        NSAttributedString(
            string: visibleText,
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 64),
                .foregroundColor: NSColor.black,
            ]
        ).draw(at: NSPoint(x: 40, y: 110))
        image.unlockFocus()

        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard
            let consumer = CGDataConsumer(url: url as CFURL),
            let context = CGContext(
                consumer: consumer,
                mediaBox: &mediaBox,
                nil
            )
        else {
            throw TestFailure(description: "无法创建伪文字层 PDF")
        }

        context.beginPDFPage(nil)
        let graphics = NSGraphicsContext(
            cgContext: context,
            flipped: false
        )
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        image.draw(in: NSRect(x: 40, y: 300, width: 532, height: 133))
        let bogusLine =
            "c6c5efc6ff0d9e301HJ939S_GVdYwIm-U_2WWOCglvfYNRRi"
        NSAttributedString(
            string: Array(repeating: bogusLine, count: 10)
                .joined(separator: "\n"),
            attributes: [
                .font: NSFont.systemFont(ofSize: 8),
                .foregroundColor: NSColor.white,
            ]
        ).draw(at: CGPoint(x: 20, y: 600))
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()
    }

    private static func convertToDOCX(
        source: URL,
        destination: URL
    ) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/textutil")
        process.arguments = [
            "-convert", "docx",
            "-output", destination.path,
            source.path
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw TestFailure(description: "无法生成 DOCX 测试文件")
        }
    }

    private static func makeImage(
        text: String,
        at url: URL
    ) throws {
        let image = NSImage(size: NSSize(width: 1200, height: 300))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 1200, height: 300).fill()
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 64),
                .foregroundColor: NSColor.black
            ]
        ).draw(at: NSPoint(x: 40, y: 110))
        image.unlockFocus()

        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let data = bitmap.representation(using: .png, properties: [:])
        else {
            throw TestFailure(description: "无法生成图片测试文件")
        }
        try data.write(to: url)
    }
}
