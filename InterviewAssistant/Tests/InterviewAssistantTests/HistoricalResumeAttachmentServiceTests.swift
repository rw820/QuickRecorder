import Foundation
import InterviewAssistantCore

private struct HistoricalResumeExtractorStub:
    ResumeTextExtracting,
    Sendable
{
    let text: String?

    func extractText(from url: URL) async throws -> String {
        guard let text else {
            throw ResumeExtractionError.invalidFile
        }
        return text
    }
}

enum HistoricalResumeAttachmentServiceTests {
    static let all = [
        TestCase(name: "历史面试可以保存独立简历附件") {
            let root = temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: root) }
            let session = root.appendingPathComponent(
                "session",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: session,
                withIntermediateDirectories: true
            )
            let source = root.appendingPathComponent("candidate.txt")
            try "源文件".write(
                to: source,
                atomically: true,
                encoding: .utf8
            )
            let service = HistoricalResumeAttachmentService(
                extractor: HistoricalResumeExtractorStub(
                    text: "候选人简历"
                )
            )

            let document = try await service.attachResume(
                from: source,
                to: session
            )

            try expect(
                document.originalFileName == "candidate.txt",
                "应保留原简历文件名"
            )
            let store = CurrentResumeStore(
                root: session.appendingPathComponent(
                    "AttachedResume",
                    isDirectory: true
                )
            )
            let saved = try store.load()
            try expect(
                saved?.text == "候选人简历",
                "应保存提取后的简历文字"
            )
            try expect(
                FileManager.default.fileExists(
                    atPath: store.root
                        .appendingPathComponent("original.txt")
                        .path
                ),
                "应保存简历原文件"
            )
        },
        TestCase(name: "历史简历提取失败时保留原附件") {
            let root = temporaryDirectory()
            defer { try? FileManager.default.removeItem(at: root) }
            let session = root.appendingPathComponent(
                "session",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: session,
                withIntermediateDirectories: true
            )
            let attachedRoot = session.appendingPathComponent(
                "AttachedResume",
                isDirectory: true
            )
            let oldSource = root.appendingPathComponent("old.txt")
            let newSource = root.appendingPathComponent("new.txt")
            try "旧源文件".write(
                to: oldSource,
                atomically: true,
                encoding: .utf8
            )
            try "新源文件".write(
                to: newSource,
                atomically: true,
                encoding: .utf8
            )
            _ = try CurrentResumeStore(root: attachedRoot).save(
                sourceURL: oldSource,
                text: "旧简历"
            )
            let service = HistoricalResumeAttachmentService(
                extractor: HistoricalResumeExtractorStub(text: nil)
            )

            var didThrow = false
            do {
                _ = try await service.attachResume(
                    from: newSource,
                    to: session
                )
            } catch {
                didThrow = true
            }

            try expect(didThrow, "提取失败应返回错误")
            let saved = try CurrentResumeStore(
                root: attachedRoot
            ).load()
            try expect(saved?.text == "旧简历", "原简历不应被覆盖")
            try expect(
                saved?.originalFileName == "old.txt",
                "原简历元数据不应改变"
            )
        }
    ]

    private static func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
