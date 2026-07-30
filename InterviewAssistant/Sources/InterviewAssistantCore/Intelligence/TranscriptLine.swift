import Foundation

public struct TranscriptLine:
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
    public let id: UUID
    public let source: AudioSource
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String

    public init(
        id: UUID = UUID(),
        source: AudioSource,
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String
    ) {
        self.id = id
        self.source = source
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }

    public var speakerName: String {
        source == .system ? "候选人" : "面试官"
    }

    public var displayText: String {
        let seconds = max(0, Int(startTime))
        return String(
            format: "[%02d:%02d] %@：%@",
            seconds / 60,
            seconds % 60,
            speakerName,
            text
        )
    }
}
