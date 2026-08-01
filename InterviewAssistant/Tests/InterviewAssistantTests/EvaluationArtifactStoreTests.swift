import Foundation
import InterviewAssistantCore

enum EvaluationArtifactStoreTests {
    static let all = [
        TestCase(name: "评价正文和实际规则作为一组保存") {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            var rules = EvaluationRulesConfiguration.default
            rules.interview.dimensions[0].instruction = "实际使用规则"
            let evaluation = InterviewEvaluation(
                markdown: "新评价",
                rulesConfiguration: rules
            )
            let store = EvaluationArtifactStore(directory: directory)

            try store.save(
                evaluation,
                reportName: "evaluation-report.md",
                snapshotName: "evaluation-rules.json"
            )

            let report = try String(
                contentsOf: directory.appendingPathComponent(
                    "evaluation-report.md"
                ),
                encoding: .utf8
            )
            let snapshot = try JSONDecoder().decode(
                EvaluationRulesConfiguration.self,
                from: Data(
                    contentsOf: directory.appendingPathComponent(
                        "evaluation-rules.json"
                    )
                )
            )
            try expect(report == "新评价", "应保存评价正文")
            try expect(snapshot == rules, "应保存实际使用的规则")
            try "损坏的兼容正文".write(
                to: directory.appendingPathComponent(
                    "evaluation-report.md"
                ),
                atomically: true,
                encoding: .utf8
            )
            let loaded = try store.load(
                reportName: "evaluation-report.md",
                snapshotName: "evaluation-rules.json"
            )
            try expect(
                loaded == evaluation,
                "兼容文件异常时仍应从单一原子产物读取正文和规则"
            )
        },
        TestCase(name: "无规则评价不会遗留错误快照") {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = EvaluationArtifactStore(directory: directory)
            try store.save(
                InterviewEvaluation(
                    markdown: "旧评价",
                    rulesConfiguration: .default
                ),
                reportName: "evaluation-report.md",
                snapshotName: "evaluation-rules.json"
            )
            try store.save(
                InterviewEvaluation(markdown: "无快照评价"),
                reportName: "evaluation-report.md",
                snapshotName: "evaluation-rules.json"
            )
            try expect(
                !FileManager.default.fileExists(
                    atPath: directory.appendingPathComponent(
                        "evaluation-rules.json"
                    ).path
                ),
                "没有规则时应删除旧快照，避免正文和规则不一致"
            )
        }
    ]
}
