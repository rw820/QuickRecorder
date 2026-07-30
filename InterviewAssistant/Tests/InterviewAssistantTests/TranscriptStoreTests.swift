import Foundation
import InterviewAssistantCore

enum TranscriptStoreTests {
    static let all = [
        TestCase(name: "逐字稿按时间保存为 JSONL 和 Markdown") {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: directory) }

            let store = try TranscriptStore(directory: directory)
            try store.append(
                TranscriptLine(
                    source: .microphone,
                    startTime: 4,
                    endTime: 6,
                    text: "请介绍这个项目。"
                )
            )
            try store.append(
                TranscriptLine(
                    source: .system,
                    startTime: 1,
                    endTime: 3,
                    text: "我负责数据产品。"
                )
            )
            try store.finish()

            let jsonl = try String(
                contentsOf: directory.appendingPathComponent("transcript.jsonl"),
                encoding: .utf8
            )
            let markdown = try String(
                contentsOf: directory.appendingPathComponent("transcript.md"),
                encoding: .utf8
            )

            try expect(
                jsonl.split(separator: "\n").count == 2,
                "JSONL 应包含两条记录"
            )
            try expect(
                markdown.contains("[00:01] 候选人：我负责数据产品。"),
                "Markdown 应包含候选人发言"
            )
            try expect(
                markdown.firstRange(of: "候选人")!.lowerBound
                    < markdown.firstRange(of: "面试官")!.lowerBound,
                "Markdown 应按时间排序"
            )
        }
    ]
}
