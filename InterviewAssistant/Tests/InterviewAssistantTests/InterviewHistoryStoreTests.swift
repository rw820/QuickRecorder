import Foundation
import InterviewAssistantCore

enum InterviewHistoryStoreTests {
    static let all = [
        TestCase(name: "历史记录按时间倒序加载完整场次") {
            let root = temporaryRoot()
            defer { try? FileManager.default.removeItem(at: root) }

            let older = try makeSession(
                root: root,
                name: "20260728-093000-older",
                resumeFileName: "李雷-产品经理.pdf",
                resumeText: "李雷有五年 B 端产品经验",
                evaluation: "优势：业务分析清晰",
                transcript: "候选人：负责资金系统",
                audioNames: ["system.caf"]
            )
            let newer = try makeSession(
                root: root,
                name: "20260729-143000-newer",
                resumeFileName: "HanMeimei-CV.pdf",
                resumeText: "Cross-border payment product",
                evaluation: "总评：适合资金产品岗位",
                transcript: "Candidate: led settlement platform",
                audioNames: ["system.caf", "microphone.caf"]
            )

            let records = InterviewHistoryStore(root: root).load()

            try expect(records.count == 2, "应加载两个场次")
            try expect(
                records.first?.id == newer.lastPathComponent,
                "最新场次应排在最前"
            )
            try expect(
                records.last?.id == older.lastPathComponent,
                "较早场次应排在后面"
            )
            try expect(
                records.first?.displayName == "HanMeimei-CV.pdf",
                "应使用简历原文件名作为场次名称"
            )
            try expect(
                records.first?.evaluation == "总评：适合资金产品岗位",
                "应加载最终评价"
            )
            try expect(
                records.first?.transcript
                    == "Candidate: led settlement platform",
                "应加载逐字稿"
            )
            try expect(
                records.first?.systemAudioURL?.lastPathComponent
                    == "system.caf",
                "应找到候选人录音"
            )
            try expect(
                records.first?.microphoneAudioURL?.lastPathComponent
                    == "microphone.caf",
                "应找到面试官录音"
            )
            try expect(
                records.last?.microphoneAudioURL == nil,
                "缺失的录音应显示为空"
            )
        },
        TestCase(name: "历史记录支持跨字段忽略大小写搜索") {
            let root = temporaryRoot()
            defer { try? FileManager.default.removeItem(at: root) }

            _ = try makeSession(
                root: root,
                name: "20260729-143000-search",
                resumeFileName: "HanMeimei-CV.pdf",
                resumeText: "Cross-border payment product",
                evaluation: "总评：适合资金产品岗位",
                transcript: "Candidate: led settlement platform",
                audioNames: []
            )
            guard let record = InterviewHistoryStore(root: root).load().first
            else {
                throw TestFailure(description: "应加载测试场次")
            }

            try expect(record.matches("hanmeimei"), "应搜索简历文件名")
            try expect(record.matches("PAYMENT"), "应搜索简历内容")
            try expect(record.matches("资金产品"), "应搜索评价")
            try expect(record.matches("SETTLEMENT"), "应搜索逐字稿")
            try expect(record.matches("2026-07-29"), "应搜索格式化日期")
            try expect(record.matches("   "), "空搜索应匹配全部记录")
            try expect(!record.matches("不存在的内容"), "无关内容不应匹配")
        },
        TestCase(name: "旧场次和损坏元数据不会阻塞历史记录") {
            let root = temporaryRoot()
            defer { try? FileManager.default.removeItem(at: root) }

            let old = try makeSession(
                root: root,
                name: "20260727-101500-old",
                resumeFileName: nil,
                resumeText: "旧简历",
                evaluation: nil,
                transcript: "旧逐字稿",
                audioNames: []
            )
            let corrupt = try makeSession(
                root: root,
                name: "20260728-101500-corrupt",
                resumeFileName: nil,
                resumeText: "仍可读取",
                evaluation: "可用评价",
                transcript: nil,
                audioNames: []
            )
            try Data("not-json".utf8).write(
                to: corrupt.appendingPathComponent("resume-metadata.json")
            )

            let records = InterviewHistoryStore(root: root).load()

            try expect(records.count == 2, "损坏元数据不应丢失整个场次")
            let oldRecord = records.first {
                $0.id == old.lastPathComponent
            }
            try expect(
                oldRecord?.displayName.contains("2026") == true,
                "旧场次应使用日期作为名称"
            )
            let corruptRecord = records.first {
                $0.id == corrupt.lastPathComponent
            }
            try expect(
                corruptRecord?.resumeText == "仍可读取",
                "元数据损坏时仍应读取其他字段"
            )
            try expect(
                corruptRecord?.evaluation == "可用评价",
                "元数据损坏时仍应读取评价"
            )
        },
    ]

    private static func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    @discardableResult
    private static func makeSession(
        root: URL,
        name: String,
        resumeFileName: String?,
        resumeText: String?,
        evaluation: String?,
        transcript: String?,
        audioNames: [String]
    ) throws -> URL {
        let directory = root.appendingPathComponent(
            name,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        if let resumeText {
            try resumeText.write(
                to: directory.appendingPathComponent("resume.txt"),
                atomically: true,
                encoding: .utf8
            )
        }
        if let evaluation {
            try evaluation.write(
                to: directory.appendingPathComponent(
                    "evaluation-report.md"
                ),
                atomically: true,
                encoding: .utf8
            )
        }
        if let transcript {
            try transcript.write(
                to: directory.appendingPathComponent("transcript.md"),
                atomically: true,
                encoding: .utf8
            )
        }
        if let resumeFileName {
            let document = ResumeDocument(
                originalFileName: resumeFileName,
                text: resumeText ?? "",
                localFileURL: directory.appendingPathComponent("original")
            )
            try JSONEncoder().encode(document).write(
                to: directory.appendingPathComponent(
                    "resume-metadata.json"
                )
            )
        }
        for name in audioNames {
            try Data([0, 1, 2]).write(
                to: directory.appendingPathComponent(name)
            )
        }
        return directory
    }
}
