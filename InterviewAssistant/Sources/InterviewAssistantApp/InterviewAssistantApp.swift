import InterviewAssistantCore
import SwiftUI

@main
@MainActor
struct InterviewAssistantApp: App {
    @StateObject private var controller: SessionController
    private let hub: AudioTapHub

    init() {
        let hub = AudioTapHub(capacitySeconds: 30)
        let resumeStore = CurrentResumeStore()
        let recorder = LiveInterviewRecorder(
            sources: [
                SystemAudioCapture(),
                MicrophoneCapture()
            ],
            sink: CAFFileSink(),
            hub: hub
        )
        let pipeline = InterviewIntelligencePipeline(
            hub: hub,
            providerFactory: { directory in
                try CodexCLIProvider(sessionDirectory: directory)
            },
            resumeStore: resumeStore
        )
        let resumeService = ResumeImportService(
            store: resumeStore,
            providerFactory: { directory in
                try CodexCLIProvider(sessionDirectory: directory)
            }
        )
        let engine = AssistedInterviewEngine(
            recorder: recorder,
            pipeline: pipeline
        )
        self.hub = hub
        _controller = StateObject(
            wrappedValue: SessionController(
                engine: engine,
                events: engine.events,
                resumeService: resumeService,
                interviewEvaluationRefresher: engine
            )
        )
    }

    var body: some Scene {
        WindowGroup("面试助手") {
            MainView(controller: controller, hub: hub)
        }
        .defaultSize(width: 860, height: 660)
        .windowResizability(.contentMinSize)
    }
}
