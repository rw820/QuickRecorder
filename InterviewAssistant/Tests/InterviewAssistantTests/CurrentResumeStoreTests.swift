import Foundation
import InterviewAssistantCore

enum CurrentResumeStoreTests {
    static let all = [
        TestCase(name: "当前简历可以保存恢复复制和清除") {
            let base = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            let root = base.appendingPathComponent(
                "CurrentCandidate",
                isDirectory: true
            )
            let source = base.appendingPathComponent("张三简历.txt")
            let session = base.appendingPathComponent(
                "Session",
                isDirectory: true
            )
            defer { try? FileManager.default.removeItem(at: base) }
            try FileManager.default.createDirectory(
                at: base,
                withIntermediateDirectories: true
            )
            try "张三，数据产品负责人，八年经验。".write(
                to: source,
                atomically: true,
                encoding: .utf8
            )

            let store = CurrentResumeStore(root: root)
            let document = try store.save(
                sourceURL: source,
                text: "张三，数据产品负责人，八年经验。"
            )
            try expect(
                document.originalFileName == "张三简历.txt",
                "应保存原始文件名"
            )
            let restored = try store.load()
            try expect(
                restored?.text == document.text,
                "应恢复提取后的文字"
            )

            let evaluation = InterviewEvaluation(
                markdown: "## 总评\nA\n## 优势\nB\n## 劣势\nC\n## 风险\nD"
            )
            try store.saveEvaluation(evaluation)
            try store.copyArtifacts(to: session)

            try expect(
                FileManager.default.fileExists(
                    atPath: session.appendingPathComponent(
                        "resume.txt"
                    ).path
                ),
                "场次目录应包含简历文字"
            )
            let copiedMetadataURL = session.appendingPathComponent(
                "resume-metadata.json"
            )
            try expect(
                FileManager.default.fileExists(
                    atPath: copiedMetadataURL.path
                ),
                "场次目录应包含简历元数据"
            )
            let copiedDocument = try JSONDecoder().decode(
                ResumeDocument.self,
                from: Data(contentsOf: copiedMetadataURL)
            )
            try expect(
                copiedDocument.originalFileName == "张三简历.txt",
                "场次简历元数据应保留原始文件名"
            )
            let restoredEvaluation = try store.loadEvaluation()
            try expect(
                restoredEvaluation == evaluation,
                "应恢复简历初评"
            )

            try store.clear()
            let cleared = try store.load()
            try expect(cleared == nil, "清除后不应恢复简历")
        }
    ]
}
