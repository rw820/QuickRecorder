import AppKit
import Foundation
import ImageIO
import PDFKit
import Vision

public protocol ResumeTextExtracting: Sendable {
    func extractText(from url: URL) async throws -> String
}

public struct ResumeTextExtractor: ResumeTextExtracting, Sendable {
    public init() {}

    public func extractText(from url: URL) async throws -> String {
        let fileExtension = url.pathExtension.lowercased()
        let text = try await Task.detached(priority: .userInitiated) {
            switch fileExtension {
            case "pdf":
                try Self.extractPDF(url)
            case "doc", "docx":
                try Self.extractAttributedDocument(url)
            case "txt":
                try Self.extractPlainText(url)
            case "png", "jpg", "jpeg":
                try Self.recognizeImageFile(url)
            default:
                throw ResumeExtractionError.unsupportedFormat(
                    fileExtension.isEmpty ? "未知格式" : fileExtension
                )
            }
        }.value

        let cleaned = Self.clean(text)
        guard cleaned.count >= 2 else {
            throw ResumeExtractionError.noText
        }
        return cleaned
    }

    private static func extractPlainText(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        for encoding in [
            String.Encoding.utf8,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            .isoLatin1
        ] {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }
        throw ResumeExtractionError.invalidFile
    }

    private static func extractAttributedDocument(
        _ url: URL
    ) throws -> String {
        do {
            return try NSAttributedString(
                url: url,
                options: [:],
                documentAttributes: nil
            ).string
        } catch {
            throw ResumeExtractionError.invalidFile
        }
    }

    private static func extractPDF(_ url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw ResumeExtractionError.invalidFile
        }
        let directText = clean(document.string ?? "")
        if isUsefulPDFText(directText) {
            return directText
        }

        var pages: [String] = []
        for index in 0..<document.pageCount {
            guard
                let page = document.page(at: index),
                let image = pageImage(page)
            else {
                continue
            }
            let text = try recognize(image)
            if !text.isEmpty {
                pages.append(text)
            }
        }
        let recognized = pages.joined(separator: "\n\n")
        if !recognized.isEmpty {
            return recognized
        }
        return directText.count < 20 ? directText : ""
    }

    private static func isUsefulPDFText(_ text: String) -> Bool {
        guard text.count >= 20 else { return false }

        let lines = text.components(separatedBy: "\n")
            .map {
                $0.filter { !$0.isWhitespace }
            }
            .filter { !$0.isEmpty }
        guard lines.count >= 4 else { return true }

        let uniqueLineCount = Set(lines).count
        if uniqueLineCount * 3 <= lines.count {
            return false
        }

        let frequencies = Dictionary(grouping: lines, by: { $0 })
            .mapValues(\.count)
        let mostRepeated = frequencies.values.max() ?? 0
        return mostRepeated * 2 < lines.count
    }

    private static func pageImage(_ page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let width: CGFloat = 2_000
        let height = max(1, width * bounds.height / bounds.width)
        let image = page.thumbnail(
            of: NSSize(width: width, height: height),
            for: .mediaBox
        )
        var rect = NSRect(origin: .zero, size: image.size)
        return image.cgImage(
            forProposedRect: &rect,
            context: nil,
            hints: nil
        )
    }

    private static func recognizeImageFile(_ url: URL) throws -> String {
        guard
            let source = CGImageSourceCreateWithURL(
                url as CFURL,
                nil
            ),
            let image = CGImageSourceCreateImageAtIndex(
                source,
                0,
                nil
            )
        else {
            throw ResumeExtractionError.invalidFile
        }
        return try recognize(image)
    }

    private static func recognize(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        let handler = VNImageRequestHandler(
            cgImage: image,
            orientation: .up
        )
        try handler.perform([request])

        let observations = (request.results ?? []).sorted {
            let yDifference =
                $0.boundingBox.maxY - $1.boundingBox.maxY
            if abs(yDifference) > 0.02 {
                return yDifference > 0
            }
            return $0.boundingBox.minX < $1.boundingBox.minX
        }
        return observations.compactMap {
            $0.topCandidates(1).first?.string
        }.joined(separator: "\n")
    }

    private static func clean(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var lines: [String] = []
        var previousWasEmpty = false
        for rawLine in normalized.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if line.isEmpty {
                if !previousWasEmpty {
                    lines.append("")
                }
                previousWasEmpty = true
            } else {
                lines.append(line)
                previousWasEmpty = false
            }
        }
        return lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
