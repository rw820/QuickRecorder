import Foundation

public protocol RecordingEngine: Sendable {
    func start(in directory: URL) async throws
    func stop() async throws
}
