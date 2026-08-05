import Foundation
import InterviewAssistantCore

enum CodexCLIProviderRulesTests {
    static let all = [
        TestCase(name: "Codex评价返回实际使用的当前规则") {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: root) }
            try FileManager.default.createDirectory(
                at: root,
                withIntermediateDirectories: true
            )
            let executable = root.appendingPathComponent("fake-codex.zsh")
            try fakeCodexScript.write(
                to: executable,
                atomically: true,
                encoding: .utf8
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: executable.path
            )
            var configuration = EvaluationRulesConfiguration.default
            configuration.interview.dimensions[0].title = "分析逻辑"
            configuration.interview.dimensions[0].maximum = 30
            configuration.interview.dimensions[1].maximum = 15
            configuration.interview.dimensions =
                configuration.interview.dimensions.map { dimension in
                    var changed = dimension
                    changed.reasonMinimumCharacters = 1
                    return changed
                }
            configuration.interview.sections =
                configuration.interview.sections.map { section in
                    var changed = section
                    changed.minimumCharacters = 1
                    return changed
                }
            let rulesStore = EvaluationRulesStore(
                root: root.appendingPathComponent("Rules")
            )
            try rulesStore.save(configuration)
            let session = root.appendingPathComponent("Session")
            let provider = try CodexCLIProvider(
                sessionDirectory: session,
                executableURL: executable,
                rulesStore: rulesStore
            )

            let evaluation = try await provider.generateEvaluation(
                from: [
                    TranscriptLine(
                        source: .system,
                        startTime: 0,
                        endTime: 1,
                        text: "我负责项目。"
                    )
                ],
                resumeText: nil
            )

            try expect(
                evaluation.markdown.contains("分析逻辑：16/30"),
                "应按当前评分规则生成并解析"
            )
            try expect(
                evaluation.rulesConfiguration == configuration,
                "应返回生成时实际使用的规则"
            )
            try expect(
                !FileManager.default.fileExists(
                    atPath: session.appendingPathComponent(
                        "evaluation-rules.json"
                    ).path
                ),
                "生成器不应提前改写历史规则快照"
            )
        },
        TestCase(name: "简历初评格式不完整时自动纠正一次") {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            defer { try? FileManager.default.removeItem(at: root) }
            try FileManager.default.createDirectory(
                at: root,
                withIntermediateDirectories: true
            )
            let executable = root.appendingPathComponent("retry-codex.zsh")
            try resumeRetryScript.write(
                to: executable,
                atomically: true,
                encoding: .utf8
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: executable.path
            )
            let session = root.appendingPathComponent("Session")
            let provider = try CodexCLIProvider(
                sessionDirectory: session,
                executableURL: executable
            )

            let evaluation = try await provider.generateResumeEvaluation(
                from: "候选人具备产品经验"
            )

            try expect(
                CompactResumeEvaluation.questions(
                    in: evaluation.markdown
                ).count == 5,
                "纠正后应得到五个问题"
            )
            let calls = try String(
                contentsOf: session.appendingPathComponent("calls.txt"),
                encoding: .utf8
            )
            try expect(calls == "2", "格式失败后只应重试一次")
        }
    ]

    private static let fakeCodexScript = """
    #!/bin/zsh
    output=""
    prompt="${@: -1}"
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "--output-last-message" ]]; then
        shift
        output="$1"
      fi
      shift
    done
    [[ "$prompt" == *"分析逻辑：数字/30"* ]] || exit 2
    /usr/bin/printf '%s' '## 结论
    保留复核
    置信度：中
    理由：需要继续复核。

    ## 综合评分
    58/100

    ## 分项评分
    - 分析逻辑：16/30｜回答结构基本完整。
    - 岗位匹配：8/15｜具备相关经验。
    - 专业能力：12/20｜专业深度一般。
    - 成果证据：10/20｜量化证据不足。
    - 风险一致性：12/15｜信息基本一致。

    ## 逻辑分析
    - 结构完整：部分回答结论后置。

    ## 总评
    候选人具备一定岗位相关经验，但成果证据和专业深度仍需进一步复核。

    ## 优势
    - 具备相关项目经验。

    ## 劣势
    - 量化证据不足。

    ## 风险
    - 个人贡献待确认。' > "$output"
    """

    private static let resumeRetryScript = """
    #!/bin/zsh
    output=""
    while [[ $# -gt 0 ]]; do
      if [[ "$1" == "--output-last-message" ]]; then
        shift
        output="$1"
      fi
      shift
    done
    calls=0
    [[ -f "$PWD/calls.txt" ]] && calls=$(/bin/cat "$PWD/calls.txt")
    calls=$((calls + 1))
    /usr/bin/printf '%s' "$calls" > "$PWD/calls.txt"
    questions='1. 你的个人贡献是什么？
    2. 成果如何量化？
    3. 最大项目难点是什么？
    4. 如何安排需求优先级？'
    if [[ "$calls" -gt 1 ]]; then
      questions="$questions
    5. 为什么选择这个岗位？"
    fi
    /usr/bin/printf '%s' "## 总评
    经历与岗位基本匹配。
    ## 优势
    有相关项目经验。
    ## 劣势
    量化成果较少。
    ## 风险
    个人贡献需确认。
    ## 建议问题
    $questions" > "$output"
    """
}
