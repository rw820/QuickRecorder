public protocol InterviewAnalysisProvider: Sendable {
    func generateResumeEvaluation(
        from resumeText: String
    ) async throws -> InterviewEvaluation

    func generateSuggestions(
        from transcript: [TranscriptLine],
        resumeText: String?
    ) async throws -> [InterviewSuggestion]

    func generateEvaluation(
        from transcript: [TranscriptLine],
        resumeText: String?
    ) async throws -> InterviewEvaluation
}
