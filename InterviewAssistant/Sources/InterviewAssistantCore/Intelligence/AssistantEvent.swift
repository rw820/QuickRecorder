public enum AssistantEvent: Sendable {
    case status(String)
    case partialTranscript(source: AudioSource, text: String)
    case transcript(TranscriptLine)
    case suggestions([InterviewSuggestion])
    case evaluation(InterviewEvaluation)
    case warning(String)
}
