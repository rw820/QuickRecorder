public protocol InterviewEvaluationRefreshing: Sendable {
    func refreshEvaluation(
        customRequirement: String?
    ) async throws -> InterviewEvaluation
}
