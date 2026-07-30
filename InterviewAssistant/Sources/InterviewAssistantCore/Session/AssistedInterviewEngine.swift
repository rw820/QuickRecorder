import Foundation

public final class AssistedInterviewEngine:
    RecordingEngine,
    InterviewEvaluationRefreshing,
    @unchecked Sendable
{
    public let events: AsyncStream<AssistantEvent>

    private let recorder: any RecordingEngine
    private let pipeline: InterviewIntelligencePipeline

    public init(
        recorder: any RecordingEngine,
        pipeline: InterviewIntelligencePipeline
    ) {
        self.recorder = recorder
        self.pipeline = pipeline
        events = pipeline.events
    }

    public func start(in directory: URL) async throws {
        try await pipeline.start(in: directory)
        do {
            try await recorder.start(in: directory)
        } catch {
            await pipeline.cancel()
            throw error
        }
    }

    public func stop() async throws {
        do {
            try await recorder.stop()
        } catch {
            await pipeline.finish()
            throw error
        }
        await pipeline.finish()
    }

    public func refreshEvaluation(
        customRequirement: String?
    ) async throws -> InterviewEvaluation {
        try await pipeline.refreshEvaluation(
            customRequirement: customRequirement
        )
    }
}
