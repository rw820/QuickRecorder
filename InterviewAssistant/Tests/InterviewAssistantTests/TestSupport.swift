import Darwin

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

struct TestCase {
    let name: String
    let body: @MainActor () async throws -> Void
}

func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) throws {
    guard condition() else {
        throw TestFailure(description: message)
    }
}

@main
@MainActor
enum TestMain {
    static func main() async {
        let tests =
            DisplayNameTests.all
            + SessionDirectoryStoreTests.all
            + InterviewHistoryStoreTests.all
            + HistoricalEvaluationRegeneratorTests.all
            + HistoricalResumeAttachmentServiceTests.all
            + SessionControllerTests.all
            + AudioRingBufferTests.all
            + AudioTapHubTests.all
            + LiveInterviewRecorderTests.all
            + CAFFileSinkTests.all
            + IntelligenceModelTests.all
            + TranscriptStoreTests.all
            + AnalysisPromptTests.all
            + EvaluationRulesTests.all
            + EvaluationRulesEditorModelTests.all
            + EvaluationArtifactStoreTests.all
            + EvaluationPromptComposerTests.all
            + CodexCLIProviderRulesTests.all
            + InterviewIntelligencePipelineTests.all
            + CurrentResumeStoreTests.all
            + ResumeTextExtractorTests.all
            + ResumeImportServiceTests.all
            + SpeechAudioConverterTests.all
        var failureCount = 0

        for test in tests {
            do {
                try await test.body()
                print("通过：\(test.name)")
            } catch {
                failureCount += 1
                print("失败：\(test.name) — \(error)")
            }
        }

        guard failureCount == 0 else {
            print("共 \(failureCount) 项失败")
            Darwin.exit(1)
        }

        print("全部 \(tests.count) 项测试通过")
    }
}
