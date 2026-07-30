import Foundation

public struct InterviewHistoryRecord:
    Identifiable,
    Equatable,
    Sendable
{
    public let id: String
    public let directory: URL
    public let startedAt: Date
    public let displayName: String
    public let resumeFileName: String?
    public let resumeText: String?
    public let evaluation: String?
    public let transcript: String?
    public let systemAudioURL: URL?
    public let microphoneAudioURL: URL?

    public init(
        id: String,
        directory: URL,
        startedAt: Date,
        displayName: String,
        resumeFileName: String?,
        resumeText: String?,
        evaluation: String?,
        transcript: String?,
        systemAudioURL: URL?,
        microphoneAudioURL: URL?
    ) {
        self.id = id
        self.directory = directory
        self.startedAt = startedAt
        self.displayName = displayName
        self.resumeFileName = resumeFileName
        self.resumeText = resumeText
        self.evaluation = evaluation
        self.transcript = transcript
        self.systemAudioURL = systemAudioURL
        self.microphoneAudioURL = microphoneAudioURL
    }

    public var dateText: String {
        Self.displayDateFormatter.string(from: startedAt)
    }

    public func matches(_ query: String) -> Bool {
        let cleaned = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !cleaned.isEmpty else { return true }

        return [
            id,
            dateText,
            displayName,
            resumeFileName,
            resumeText,
            evaluation,
            transcript,
        ]
        .compactMap { $0 }
        .contains {
            $0.localizedCaseInsensitiveContains(cleaned)
        }
    }

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}
