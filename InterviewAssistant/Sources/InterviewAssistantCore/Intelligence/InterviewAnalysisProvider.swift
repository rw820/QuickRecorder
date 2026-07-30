public protocol InterviewAnalysisProvider: Sendable {
    func generateResumeEvaluation(
        from resumeText: String
    ) async throws -> InterviewEvaluation

    func generateResumeEvaluation(
        from resumeText: String,
        customRequirement: String?
    ) async throws -> InterviewEvaluation

    func generateSuggestions(
        from transcript: [TranscriptLine],
        resumeText: String?
    ) async throws -> [InterviewSuggestion]

    func generateEvaluation(
        from transcript: [TranscriptLine],
        resumeText: String?
    ) async throws -> InterviewEvaluation

    func generateEvaluation(
        from transcript: [TranscriptLine],
        resumeText: String?,
        customRequirement: String?
    ) async throws -> InterviewEvaluation
}

public extension InterviewAnalysisProvider {
    func generateResumeEvaluation(
        from resumeText: String,
        customRequirement: String?
    ) async throws -> InterviewEvaluation {
        try await generateResumeEvaluation(from: resumeText)
    }

    func generateEvaluation(
        from transcript: [TranscriptLine],
        resumeText: String?,
        customRequirement: String?
    ) async throws -> InterviewEvaluation {
        try await generateEvaluation(
            from: transcript,
            resumeText: resumeText
        )
    }
}
