import Foundation

public struct InterviewSuggestion:
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
    public let id: UUID
    public let question: String
    public let reason: String
    public let evidence: String

    public init(
        id: UUID = UUID(),
        question: String,
        reason: String,
        evidence: String
    ) {
        self.id = id
        self.question = question
        self.reason = reason
        self.evidence = evidence
    }
}
