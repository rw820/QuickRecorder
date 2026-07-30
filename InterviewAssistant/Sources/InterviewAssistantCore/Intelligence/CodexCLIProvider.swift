import Foundation

public enum CodexCLIProviderError: LocalizedError {
    case executableNotFound
    case timedOut
    case processFailed(String)
    case emptyOutput
    case invalidOutput(String)

    public var errorDescription: String? {
        switch self {
        case .executableNotFound:
            "没有找到 Codex，请先安装或登录 Codex"
        case .timedOut:
            "Codex 分析超时"
        case let .processFailed(message):
            "Codex 分析失败：\(message)"
        case .emptyOutput:
            "Codex 没有返回内容"
        case let .invalidOutput(message):
            "Codex 返回格式不正确：\(message)"
        }
    }
}

public struct CodexCLIProvider: InterviewAnalysisProvider, Sendable {
    public let sessionDirectory: URL
    public let suggestionModel: String
    public let evaluationModel: String

    private let executableURL: URL

    public init(
        sessionDirectory: URL,
        executableURL: URL? = nil,
        suggestionModel: String = "gpt-5.6-luna",
        evaluationModel: String = "gpt-5.6-sol"
    ) throws {
        guard let executableURL = executableURL ?? Self.findExecutable()
        else {
            throw CodexCLIProviderError.executableNotFound
        }
        self.sessionDirectory = sessionDirectory
        self.executableURL = executableURL
        self.suggestionModel = suggestionModel
        self.evaluationModel = evaluationModel
    }

    public func generateResumeEvaluation(
        from resumeText: String
    ) async throws -> InterviewEvaluation {
        try await generateResumeEvaluation(
            from: resumeText,
            customRequirement: nil
        )
    }

    public func generateResumeEvaluation(
        from resumeText: String,
        customRequirement: String?
    ) async throws -> InterviewEvaluation {
        let output = try await run(
            prompt: AnalysisPrompts.resumeEvaluation(
                resume: String(resumeText.prefix(40_000)),
                customRequirement: customRequirement
            ),
            model: evaluationModel,
            timeout: 120
        )
        guard let evaluation = CompactResumeEvaluation.normalize(output)
        else {
            throw CodexCLIProviderError.invalidOutput(
                "简历初评缺少五个部分或五个建议问题"
            )
        }
        return evaluation
    }

    public func generateSuggestions(
        from transcript: [TranscriptLine],
        resumeText: String?
    ) async throws -> [InterviewSuggestion] {
        let text = AnalysisPrompts.transcriptText(
            transcript,
            maximumCharacters: 16_000
        )
        let output = try await run(
            prompt: AnalysisPrompts.suggestions(
                transcript: text,
                resume: resumeText.map {
                    String($0.prefix(30_000))
                }
            ),
            model: suggestionModel,
            timeout: 30
        )
        if output.trimmingCharacters(in: .whitespacesAndNewlines)
            == "暂无建议"
        {
            return []
        }
        let suggestions = Self.parseSuggestions(output)
        guard !suggestions.isEmpty else {
            throw CodexCLIProviderError.invalidOutput("无法解析实时建议")
        }
        return Array(suggestions.prefix(3))
    }

    public func generateEvaluation(
        from transcript: [TranscriptLine],
        resumeText: String?
    ) async throws -> InterviewEvaluation {
        try await generateEvaluation(
            from: transcript,
            resumeText: resumeText,
            customRequirement: nil
        )
    }

    public func generateEvaluation(
        from transcript: [TranscriptLine],
        resumeText: String?,
        customRequirement: String?
    ) async throws -> InterviewEvaluation {
        let text = AnalysisPrompts.transcriptText(transcript)
        let output = try await run(
            prompt: AnalysisPrompts.evaluation(
                transcript: text,
                resume: resumeText.map {
                    String($0.prefix(40_000))
                },
                customRequirement: customRequirement
            ),
            model: evaluationModel,
            timeout: 120
        )
        return try Self.validatedEvaluation(output)
    }

    private static func validatedEvaluation(
        _ output: String
    ) throws -> InterviewEvaluation {
        guard let evaluation = CompactInterviewEvaluation.normalize(output)
        else {
            throw CodexCLIProviderError.invalidOutput("缺少评价章节")
        }
        return evaluation
    }

    public static func parseSuggestions(
        _ output: String
    ) -> [InterviewSuggestion] {
        var result: [InterviewSuggestion] = []
        var question = ""
        var reason = ""
        var evidence = ""

        func value(
            in line: String,
            labels: [String]
        ) -> String? {
            for label in labels {
                guard let range = line.range(of: label) else { continue }
                let prefix = line[..<range.lowerBound]
                guard prefix.count <= 8 else { continue }
                return String(line[range.upperBound...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return nil
        }

        func appendCurrent() {
            guard
                !question.isEmpty,
                !reason.isEmpty,
                !evidence.isEmpty
            else {
                return
            }
            result.append(
                InterviewSuggestion(
                    question: question,
                    reason: reason,
                    evidence: evidence
                )
            )
            question = ""
            reason = ""
            evidence = ""
        }

        for rawLine in output.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if line.isEmpty {
                appendCurrent()
            } else if let next = value(
                in: line,
                labels: ["问题：", "问题:"]
            ) {
                appendCurrent()
                question = next
            } else if let next = value(
                in: line,
                labels: ["原因：", "原因:"]
            ) {
                reason = next
            } else if let next = value(
                in: line,
                labels: ["依据：", "依据:"]
            ) {
                evidence = next
            }
        }
        appendCurrent()
        return result
    }

    public static func findExecutable() -> URL? {
        let known = URL(
            fileURLWithPath:
                "/Applications/ChatGPT.app/Contents/Resources/codex"
        )
        if FileManager.default.isExecutableFile(atPath: known.path) {
            return known
        }

        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in path.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory))
                .appendingPathComponent("codex")
            if FileManager.default.isExecutableFile(
                atPath: candidate.path
            ) {
                return candidate
            }
        }
        return nil
    }

    private func run(
        prompt: String,
        model: String,
        timeout: TimeInterval
    ) async throws -> String {
        let executableURL = self.executableURL
        let sessionDirectory = self.sessionDirectory
        return try await Task.detached(priority: .userInitiated) {
            try Self.runBlocking(
                executableURL: executableURL,
                sessionDirectory: sessionDirectory,
                prompt: prompt,
                model: model,
                timeout: timeout
            )
        }.value
    }

    private static func runBlocking(
        executableURL: URL,
        sessionDirectory: URL,
        prompt: String,
        model: String,
        timeout: TimeInterval
    ) throws -> String {
        try FileManager.default.createDirectory(
            at: sessionDirectory,
            withIntermediateDirectories: true
        )
        let identifier = UUID().uuidString
        let outputURL = sessionDirectory
            .appendingPathComponent(".codex-output-\(identifier).txt")
        let logURL = sessionDirectory
            .appendingPathComponent(".codex-log-\(identifier).txt")
        FileManager.default.createFile(
            atPath: logURL.path,
            contents: nil
        )
        defer {
            try? FileManager.default.removeItem(at: outputURL)
            try? FileManager.default.removeItem(at: logURL)
        }

        let logHandle = try FileHandle(forWritingTo: logURL)
        defer { try? logHandle.close() }

        let process = Process()
        process.executableURL = executableURL
        process.currentDirectoryURL = sessionDirectory
        process.arguments = [
            "exec",
            "--ephemeral",
            "--skip-git-repo-check",
            "--ignore-rules",
            "--sandbox", "read-only",
            "--cd", sessionDirectory.path,
            "--model", model,
            "--config", "model_reasoning_effort=\"low\"",
            "--output-last-message", outputURL.path,
            prompt
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = logHandle
        process.standardError = logHandle

        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }
        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            throw CodexCLIProviderError.timedOut
        }
        guard process.terminationStatus == 0 else {
            let log = (try? String(
                contentsOf: logURL,
                encoding: .utf8
            )) ?? ""
            throw CodexCLIProviderError.processFailed(
                String(log.suffix(1_000))
            )
        }

        let output = try String(
            contentsOf: outputURL,
            encoding: .utf8
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty else {
            throw CodexCLIProviderError.emptyOutput
        }
        return output
    }
}
