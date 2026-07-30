# Interview Assistant Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 做出一个独立运行的 Mac 面试助手，支持一键开始和停止，并同时保存系统声音与麦克风录音。

**Architecture:** 新 App 不使用 QuickRecorder 的原界面，只参考并改造它基于 ScreenCaptureKit 和 AVAudioEngine 的录音方式。录音回调把音频交给独立的 `AudioTapHub`，录音文件保存与后续转写共用同一份音频流，但彼此不阻塞。

**Tech Stack:** Swift 6、SwiftUI、ScreenCaptureKit、AVFoundation、Swift Package Manager、XCTest、macOS 14+

## Global Constraints

- 这是独立的 Mac App，不是 QuickRecorder 的功能入口。
- 日常使用只有“开始面试”和“停止面试”两个主操作。
- 系统声音和麦克风分别保存。
- 任何分析模块故障都不能影响原始录音。
- 第一阶段不接入 ASR 和大模型，只提供稳定的音频分流接口。
- 当前机器没有完整 Xcode，必须支持使用 Command Line Tools 构建和测试。
- 所有新代码放在 `InterviewAssistant/`，不修改 QuickRecorder 原有录制流程。

## 后续阶段

本规格拆成四个可独立验收的开发阶段：

1. 本计划：独立 App、录音、音频分流和场次保存。
2. 流式转写：本地 ASR、临时文字、稳定文字和字幕窗口。
3. 面试建议：自动/手动触发、本地模型、OpenAI 和兼容 Provider。
4. 完整评价：线下说话人区分、材料导入、报告和故障恢复。

---

### Task 1: 建立独立 App 和命令行打包流程

**Files:**
- Create: `InterviewAssistant/Package.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/InterviewAssistantCore.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantApp/InterviewAssistantApp.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantApp/MainView.swift`
- Create: `InterviewAssistant/Resources/Info.plist`
- Create: `InterviewAssistant/Resources/InterviewAssistant.entitlements`
- Create: `InterviewAssistant/Scripts/build-app.sh`

**Interfaces:**
- Produces: Swift Package 产品 `InterviewAssistantCore` 和可执行产品 `InterviewAssistantApp`
- Produces: `.build/app/面试助手.app`

- [ ] **Step 1: 创建 Swift Package**

`InterviewAssistant/Package.swift`：

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "InterviewAssistant",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "InterviewAssistantCore", targets: ["InterviewAssistantCore"]),
        .executable(name: "InterviewAssistantApp", targets: ["InterviewAssistantApp"])
    ],
    targets: [
        .target(name: "InterviewAssistantCore"),
        .executableTarget(
            name: "InterviewAssistantApp",
            dependencies: ["InterviewAssistantCore"]
        ),
        .testTarget(
            name: "InterviewAssistantCoreTests",
            dependencies: ["InterviewAssistantCore"]
        )
    ]
)
```

`InterviewAssistant/Sources/InterviewAssistantCore/InterviewAssistantCore.swift`：

```swift
public enum InterviewAssistantCore {
    public static let displayName = "面试助手"
}
```

- [ ] **Step 2: 创建最小 SwiftUI App**

`InterviewAssistant/Sources/InterviewAssistantApp/InterviewAssistantApp.swift`：

```swift
import SwiftUI

@main
struct InterviewAssistantApp: App {
    var body: some Scene {
        WindowGroup("面试助手") {
            MainView()
        }
        .windowResizability(.contentSize)
    }
}
```

`InterviewAssistant/Sources/InterviewAssistantApp/MainView.swift`：

```swift
import InterviewAssistantCore
import SwiftUI

struct MainView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text(InterviewAssistantCore.displayName)
                .font(.title2.bold())
            Text("准备录音")
                .foregroundStyle(.secondary)
            Button("开始面试") {}
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(width: 320)
    }
}
```

- [ ] **Step 3: 创建 App 元数据和权限声明**

`InterviewAssistant/Resources/Info.plist` 必须包含：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>InterviewAssistantApp</string>
    <key>CFBundleIdentifier</key>
    <string>local.ben.InterviewAssistant</string>
    <key>CFBundleName</key>
    <string>面试助手</string>
    <key>CFBundleDisplayName</key>
    <string>面试助手</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>面试助手需要使用麦克风录制面试官声音。</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>面试助手需要录制系统声音。</string>
</dict>
</plist>
```

`InterviewAssistant/Resources/InterviewAssistant.entitlements`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 4: 创建本地打包脚本**

`InterviewAssistant/Scripts/build-app.sh` 必须执行：

```bash
#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
build_root="${project_dir}/.build"
app_dir="${build_root}/app/面试助手.app"
contents_dir="${app_dir}/Contents"

swift build --package-path "${project_dir}" -c release
mkdir -p "${contents_dir}/MacOS" "${contents_dir}/Resources"
cp "${build_root}/release/InterviewAssistantApp" \
   "${contents_dir}/MacOS/InterviewAssistantApp"
cp "${project_dir}/Resources/Info.plist" "${contents_dir}/Info.plist"
codesign --force --deep --sign - \
  --entitlements "${project_dir}/Resources/InterviewAssistant.entitlements" \
  "${app_dir}"
codesign --verify --deep --strict "${app_dir}"
echo "${app_dir}"
```

- [ ] **Step 5: 验证构建**

Run:

```bash
swift build --package-path InterviewAssistant
zsh InterviewAssistant/Scripts/build-app.sh
```

Expected:

- `swift build` 退出码为 0；
- 脚本输出 `.build/app/面试助手.app`；
- `codesign --verify` 退出码为 0。

- [ ] **Step 6: 提交**

```bash
git add InterviewAssistant
git commit -m "feat: scaffold standalone interview assistant"
```

---

### Task 2: 场次目录和开始/停止状态

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Session/RecordingEngine.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Session/SessionDirectoryStore.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Session/SessionController.swift`
- Create: `InterviewAssistant/Tests/InterviewAssistantCoreTests/SessionDirectoryStoreTests.swift`
- Create: `InterviewAssistant/Tests/InterviewAssistantCoreTests/SessionControllerTests.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/InterviewAssistantApp.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/MainView.swift`

**Interfaces:**
- Produces: `RecordingEngine.start(in:)` 和 `RecordingEngine.stop()`
- Produces: `SessionDirectoryStore.createSessionDirectory()`
- Produces: `SessionController.start()`、`SessionController.stop()` 和 `RecordingState`

- [ ] **Step 1: 写场次目录失败测试**

`SessionDirectoryStoreTests.swift`：

```swift
import XCTest
@testable import InterviewAssistantCore

final class SessionDirectoryStoreTests: XCTestCase {
    func testCreateSessionDirectoryUsesTimestampAndUniqueID() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let store = SessionDirectoryStore(root: root)

        let first = try store.createSessionDirectory(now: Date(timeIntervalSince1970: 0))
        let second = try store.createSessionDirectory(now: Date(timeIntervalSince1970: 0))

        XCTAssertNotEqual(first, second)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path))
        XCTAssertTrue(first.lastPathComponent.hasPrefix("19700101-080000-"))
    }
}
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```bash
swift test --package-path InterviewAssistant \
  --filter SessionDirectoryStoreTests
```

Expected: FAIL，原因是 `SessionDirectoryStore` 不存在。

- [ ] **Step 3: 实现场次目录**

`SessionDirectoryStore.swift`：

```swift
import Foundation

public struct SessionDirectoryStore: Sendable {
    public let root: URL

    public init(root: URL? = nil) {
        if let root {
            self.root = root
        } else {
            let support = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            self.root = support
                .appendingPathComponent("InterviewAssistant", isDirectory: true)
                .appendingPathComponent("Sessions", isDirectory: true)
        }
    }

    public func createSessionDirectory(now: Date = Date()) throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "\(formatter.string(from: now))-\(UUID().uuidString.lowercased())"
        let directory = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}
```

- [ ] **Step 4: 写状态流转失败测试**

`SessionControllerTests.swift`：

```swift
import XCTest
@testable import InterviewAssistantCore

private actor RecordingEngineSpy: RecordingEngine {
    private(set) var starts: [URL] = []
    private(set) var stopCount = 0

    func start(in directory: URL) async throws {
        starts.append(directory)
    }

    func stop() async throws {
        stopCount += 1
    }

    func snapshot() -> (Int, Int) {
        (starts.count, stopCount)
    }
}

final class SessionControllerTests: XCTestCase {
    @MainActor
    func testStartAndStopDriveEngineAndState() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let engine = RecordingEngineSpy()
        let controller = SessionController(
            engine: engine,
            store: SessionDirectoryStore(root: root)
        )

        await controller.start()
        guard case .recording = controller.state else {
            return XCTFail("expected recording")
        }

        await controller.stop()
        XCTAssertEqual(controller.state, .idle)
        let counts = await engine.snapshot()
        XCTAssertEqual(counts.0, 1)
        XCTAssertEqual(counts.1, 1)
    }
}
```

- [ ] **Step 5: 运行测试并确认失败**

Run:

```bash
swift test --package-path InterviewAssistant \
  --filter SessionControllerTests
```

Expected: FAIL，原因是 `RecordingEngine`、`SessionController` 或 `RecordingState` 不存在。

- [ ] **Step 6: 实现状态控制**

`RecordingEngine.swift`：

```swift
import Foundation

public protocol RecordingEngine: Sendable {
    func start(in directory: URL) async throws
    func stop() async throws
}
```

`SessionController.swift`：

```swift
import Combine
import Foundation

public enum RecordingState: Equatable, Sendable {
    case idle
    case starting
    case recording(URL)
    case stopping
    case failed(String)
}

@MainActor
public final class SessionController: ObservableObject {
    @Published public private(set) var state: RecordingState = .idle

    private let engine: any RecordingEngine
    private let store: SessionDirectoryStore

    public init(
        engine: any RecordingEngine,
        store: SessionDirectoryStore = SessionDirectoryStore()
    ) {
        self.engine = engine
        self.store = store
    }

    public func start() async {
        guard state == .idle else { return }
        state = .starting
        do {
            let directory = try store.createSessionDirectory()
            try await engine.start(in: directory)
            state = .recording(directory)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    public func stop() async {
        guard case .recording = state else { return }
        state = .stopping
        do {
            try await engine.stop()
            state = .idle
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    public func dismissError() {
        if case .failed = state {
            state = .idle
        }
    }
}
```

- [ ] **Step 7: 接入 App UI**

`MainView` 根据 `RecordingState` 显示：

- `idle`：蓝色“开始面试”；
- `starting`：进度图标和“正在启动”；
- `recording`：红色“停止面试”和场次目录名；
- `stopping`：进度图标和“正在保存”；
- `failed`：错误文字和“返回”；“返回”调用 `controller.dismissError()`。

按钮只调用：

```swift
Task {
    if case .recording = controller.state {
        await controller.stop()
    } else {
        await controller.start()
    }
}
```

- [ ] **Step 8: 验证并提交**

```bash
swift test --package-path InterviewAssistant
swift build --package-path InterviewAssistant
git add InterviewAssistant
git commit -m "feat: add interview session lifecycle"
```

Expected: tests PASS，build 退出码为 0。

---

### Task 3: 音频分流和 30 秒缓冲

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Audio/AudioSource.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Audio/AudioChunk.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Audio/AudioRingBuffer.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Audio/AudioTapHub.swift`
- Create: `InterviewAssistant/Tests/InterviewAssistantCoreTests/AudioRingBufferTests.swift`
- Create: `InterviewAssistant/Tests/InterviewAssistantCoreTests/AudioTapHubTests.swift`

**Interfaces:**
- Produces: `AudioChunk(source:timestamp:buffer:)`
- Produces: `AudioTapHub.ingest(_:) -> Int`
- Produces: `AudioTapHub.stream`，供下一阶段 ASR 消费

- [ ] **Step 1: 写缓冲区失败测试**

`AudioRingBufferTests.swift`：

```swift
import AVFoundation
import XCTest
@testable import InterviewAssistantCore

final class AudioRingBufferTests: XCTestCase {
    func testDropsOldestChunksBeyondCapacity() throws {
        var buffer = AudioRingBuffer(capacitySeconds: 0.04)
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 1,
            interleaved: false
        )!

        func chunk(_ timestamp: TimeInterval) -> AudioChunk {
            let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 960)!
            pcm.frameLength = 960
            return AudioChunk(source: .microphone, timestamp: timestamp, buffer: pcm)
        }

        XCTAssertEqual(buffer.append(chunk(0.00)), 0)
        XCTAssertEqual(buffer.append(chunk(0.02)), 0)
        XCTAssertEqual(buffer.append(chunk(0.04)), 1)
        XCTAssertEqual(buffer.chunks.map(\.timestamp), [0.02, 0.04])
    }
}
```

- [ ] **Step 2: 运行并确认失败**

```bash
swift test --package-path InterviewAssistant \
  --filter AudioRingBufferTests
```

Expected: FAIL，原因是音频类型不存在。

- [ ] **Step 3: 实现音频类型和缓冲区**

`AudioSource.swift`：

```swift
public enum AudioSource: String, Codable, Sendable {
    case system
    case microphone
}
```

`AudioChunk.swift`：

```swift
import AVFoundation

public struct AudioChunk: @unchecked Sendable {
    public let source: AudioSource
    public let timestamp: TimeInterval
    public let buffer: AVAudioPCMBuffer

    public var duration: TimeInterval {
        Double(buffer.frameLength) / buffer.format.sampleRate
    }

    public init(
        source: AudioSource,
        timestamp: TimeInterval,
        buffer: AVAudioPCMBuffer
    ) {
        self.source = source
        self.timestamp = timestamp
        self.buffer = buffer
    }
}
```

`AudioRingBuffer.swift`：

```swift
public struct AudioRingBuffer {
    public let capacitySeconds: TimeInterval
    public private(set) var chunks: [AudioChunk] = []
    private var duration: TimeInterval = 0

    public init(capacitySeconds: TimeInterval) {
        self.capacitySeconds = capacitySeconds
    }

    @discardableResult
    public mutating func append(_ chunk: AudioChunk) -> Int {
        chunks.append(chunk)
        duration += chunk.duration
        var dropped = 0
        while duration > capacitySeconds, !chunks.isEmpty {
            duration -= chunks.removeFirst().duration
            dropped += 1
        }
        return dropped
    }
}
```

- [ ] **Step 4: 写分流测试**

`AudioTapHubTests.swift`：

```swift
import AVFoundation
import XCTest
@testable import InterviewAssistantCore

final class AudioTapHubTests: XCTestCase {
    func testIngestPublishesAndRetainsChunk() async throws {
        let hub = AudioTapHub(capacitySeconds: 30)
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 1,
            interleaved: false
        )!
        let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480)!
        pcm.frameLength = 480
        let chunk = AudioChunk(source: .microphone, timestamp: 1, buffer: pcm)

        let next = Task { await hub.stream.first(where: { _ in true }) }
        XCTAssertEqual(hub.ingest(chunk), 0)
        let published = await next.value

        XCTAssertEqual(published?.timestamp, 1)
        XCTAssertEqual(hub.snapshot(source: .microphone).count, 1)
    }
}
```

- [ ] **Step 5: 实现 AudioTapHub**

`AudioTapHub.swift`：

```swift
import Foundation

public final class AudioTapHub: @unchecked Sendable {
    public let stream: AsyncStream<AudioChunk>

    private let continuation: AsyncStream<AudioChunk>.Continuation
    private let lock = NSLock()
    private var buffers: [AudioSource: AudioRingBuffer]

    public init(capacitySeconds: TimeInterval = 30) {
        let pair = AsyncStream.makeStream(
            of: AudioChunk.self,
            bufferingPolicy: .bufferingNewest(1_500)
        )
        stream = pair.stream
        continuation = pair.continuation
        buffers = [
            .system: AudioRingBuffer(capacitySeconds: capacitySeconds),
            .microphone: AudioRingBuffer(capacitySeconds: capacitySeconds)
        ]
    }

    @discardableResult
    public func ingest(_ chunk: AudioChunk) -> Int {
        let dropped = lock.withLock {
            buffers[chunk.source, default: AudioRingBuffer(capacitySeconds: 30)]
                .append(chunk)
        }
        continuation.yield(chunk)
        return dropped
    }

    public func snapshot(source: AudioSource) -> [AudioChunk] {
        lock.withLock { buffers[source]?.chunks ?? [] }
    }
}
```

- [ ] **Step 6: 验证并提交**

```bash
swift test --package-path InterviewAssistant \
  --filter AudioRingBufferTests
swift test --package-path InterviewAssistant \
  --filter AudioTapHubTests
git add InterviewAssistant
git commit -m "feat: add nonblocking audio tap hub"
```

Expected: 两组测试 PASS。

---

### Task 4: 系统声音、麦克风和分轨文件

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Recording/AudioCaptureSource.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Recording/PCMBufferCopy.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Recording/SampleBufferPCM.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Recording/SystemAudioCapture.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Recording/MicrophoneCapture.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Recording/AudioFileSink.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Recording/LiveInterviewRecorder.swift`
- Create: `InterviewAssistant/Tests/InterviewAssistantCoreTests/LiveInterviewRecorderTests.swift`

**Interfaces:**
- Consumes: `AudioTapHub.ingest(_:)`
- Produces: `LiveInterviewRecorder: RecordingEngine`
- Produces: 每场 `system.caf` 和 `microphone.caf`

- [ ] **Step 1: 写录音编排失败测试**

测试使用两个假的采集源和一个假的文件保存器：

```swift
import AVFoundation
import XCTest
@testable import InterviewAssistantCore

private final class CaptureSourceSpy: AudioCaptureSource, @unchecked Sendable {
    let source: AudioSource
    private var handler: (@Sendable (AudioChunk) -> Void)?
    private(set) var starts = 0
    private(set) var stops = 0

    init(source: AudioSource) {
        self.source = source
    }

    func start(handler: @escaping @Sendable (AudioChunk) -> Void) async throws {
        starts += 1
        self.handler = handler
    }

    func stop() async {
        stops += 1
    }

    func emit(_ chunk: AudioChunk) {
        handler?(chunk)
    }
}

private final class AudioFileSinkSpy: AudioFileSink, @unchecked Sendable {
    private let lock = NSLock()
    private var received: [AudioSource: Int] = [:]

    func start(in directory: URL) throws {}

    func append(_ chunk: AudioChunk) {
        lock.withLock {
            received[chunk.source, default: 0] += 1
        }
    }

    func finish() throws {}

    func count(_ source: AudioSource) -> Int {
        lock.withLock {
            received[source, default: 0]
        }
    }
}

final class LiveInterviewRecorderTests: XCTestCase {
    func testEveryChunkGoesToTapHubAndFileSink() async throws {
        let system = CaptureSourceSpy(source: .system)
        let microphone = CaptureSourceSpy(source: .microphone)
        let sink = AudioFileSinkSpy()
        let hub = AudioTapHub()
        let recorder = LiveInterviewRecorder(
            sources: [system, microphone],
            sink: sink,
            hub: hub
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        try await recorder.start(in: directory)
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 1,
            interleaved: false
        )!
        let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 480)!
        pcm.frameLength = 480
        microphone.emit(AudioChunk(source: .microphone, timestamp: 0, buffer: pcm))
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(hub.snapshot(source: .microphone).count, 1)
        XCTAssertEqual(sink.count(.microphone), 1)
        try await recorder.stop()
        XCTAssertEqual(system.stops, 1)
        XCTAssertEqual(microphone.stops, 1)
    }
}
```

- [ ] **Step 2: 运行并确认失败**

```bash
swift test --package-path InterviewAssistant \
  --filter LiveInterviewRecorderTests
```

Expected: FAIL，原因是采集源、文件保存器和录音器不存在。

- [ ] **Step 3: 定义采集和保存接口**

`AudioCaptureSource.swift`：

```swift
import Foundation

public protocol AudioCaptureSource: Sendable {
    var source: AudioSource { get }
    func start(handler: @escaping @Sendable (AudioChunk) -> Void) async throws
    func stop() async
}

public protocol AudioFileSink: Sendable {
    func start(in directory: URL) throws
    func append(_ chunk: AudioChunk)
    func finish() throws
}
```

- [ ] **Step 4: 实现 PCM 深拷贝**

`PCMBufferCopy.swift` 提供：

```swift
import AVFoundation

extension AVAudioPCMBuffer {
    func ownedCopy() -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameLength
        ) else {
            return nil
        }
        copy.frameLength = frameLength
        let source = UnsafeMutableAudioBufferListPointer(mutableAudioBufferList)
        let target = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for index in 0..<min(source.count, target.count) {
            guard let sourceData = source[index].mData,
                  let targetData = target[index].mData else { continue }
            memcpy(
                targetData,
                sourceData,
                Int(min(source[index].mDataByteSize, target[index].mDataByteSize))
            )
        }
        return copy
    }
}
```

所有系统和麦克风回调必须先调用 `ownedCopy()`，再创建 `AudioChunk`。

- [ ] **Step 5: 实现系统声音采集**

`SampleBufferPCM.swift` 先把系统音频转成自有 PCM：

```swift
import AVFoundation
import CoreMedia

extension CMSampleBuffer {
    func ownedPCMBuffer() -> AVAudioPCMBuffer? {
        try? withAudioBufferList { list, _ in
            guard let description = formatDescription?
                .audioStreamBasicDescription,
                  let format = AVAudioFormat(
                    standardFormatWithSampleRate: description.mSampleRate,
                    channels: description.mChannelsPerFrame
                  ),
                  let borrowed = AVAudioPCMBuffer(
                    pcmFormat: format,
                    bufferListNoCopy: list.unsafePointer
                  ) else {
                return nil
            }
            return borrowed.ownedCopy()
        }
    }
}
```

`SystemAudioCapture` 按 QuickRecorder 已验证的方式：

1. 使用 `SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true)`；
2. 选择鼠标所在显示器，找不到时使用第一个显示器；
3. 使用 `SCContentFilter(display:excludingApplications:exceptingWindows:)`；
4. `SCStreamConfiguration` 设置 `width = 2`、`height = 2`、`capturesAudio = true`、`sampleRate = 48_000`、`channelCount = 2`；
5. 添加 `.audio` 输出；
6. 在 `SCStreamOutput` 回调中调用 `sampleBuffer.ownedPCMBuffer()`；
7. 使用 `CMSampleBufferGetPresentationTimeStamp` 生成秒级时间并调用 handler；
8. `stop()` 调用 `stopCapture()` 并移除输出。

权限被拒绝时抛出：

```swift
public enum CaptureError: LocalizedError {
    case noDisplay
    case screenPermissionDenied
    case microphonePermissionDenied

    public var errorDescription: String? {
        switch self {
        case .noDisplay: "没有找到可录制的显示器"
        case .screenPermissionDenied: "请在系统设置中允许录屏权限"
        case .microphonePermissionDenied: "请在系统设置中允许麦克风权限"
        }
    }
}
```

- [ ] **Step 6: 实现麦克风采集**

`MicrophoneCapture`：

1. 使用 `AVCaptureDevice.requestAccess(for: .audio)` 请求权限；
2. 使用 `AVAudioEngine.inputNode`；
3. 在 bus 0 安装 `bufferSize: 1024` 的 tap；
4. 对每个 `AVAudioPCMBuffer` 做深拷贝；
5. 用 `AVAudioTime.sampleTime / sampleRate` 生成时间；
6. 调用 handler；
7. `stop()` 移除 tap 并停止 engine。

- [ ] **Step 7: 实现分轨文件保存**

`CAFFileSink` 使用串行队列写入。`append` 只排队，`finish` 等待已经排队的写入完成后再关闭文件，避免停止时丢掉尾部音频：

```swift
import AVFoundation

public final class CAFFileSink: AudioFileSink, @unchecked Sendable {
    private let queue = DispatchQueue(label: "InterviewAssistant.CAFFileSink")
    private var files: [AudioSource: AVAudioFile] = [:]
    private var directory: URL?
    private var firstError: Error?

    public init() {}

    public func start(in directory: URL) throws {
        queue.sync {
            self.directory = directory
            self.firstError = nil
        }
    }

    public func append(_ chunk: AudioChunk) {
        queue.async {
            guard let directory = self.directory, self.firstError == nil else {
                return
            }
            do {
                let file: AVAudioFile
                if let existing = self.files[chunk.source] {
                    file = existing
                } else {
                    let name = chunk.source == .system
                        ? "system.caf"
                        : "microphone.caf"
                    file = try AVAudioFile(
                        forWriting: directory.appendingPathComponent(name),
                        settings: chunk.buffer.format.settings,
                        commonFormat: chunk.buffer.format.commonFormat,
                        interleaved: chunk.buffer.format.isInterleaved
                    )
                    self.files[chunk.source] = file
                }
                try file.write(from: chunk.buffer)
            } catch {
                self.firstError = error
            }
        }
    }

    public func finish() throws {
        let result: Result<Void, Error> = queue.sync {
            defer {
                files.removeAll()
                directory = nil
                firstError = nil
            }
            if let firstError {
                return .failure(firstError)
            }
            return .success(())
        }
        try result.get()
    }
}
```

- [ ] **Step 8: 实现录音编排**

`LiveInterviewRecorder`：

```swift
public final class LiveInterviewRecorder: RecordingEngine, @unchecked Sendable {
    private let sources: [any AudioCaptureSource]
    private let sink: any AudioFileSink
    public let hub: AudioTapHub

    public init(
        sources: [any AudioCaptureSource],
        sink: any AudioFileSink,
        hub: AudioTapHub
    ) {
        self.sources = sources
        self.sink = sink
        self.hub = hub
    }

    public func start(in directory: URL) async throws {
        try sink.start(in: directory)
        do {
            for source in sources {
                try await source.start { [hub, sink] chunk in
                    hub.ingest(chunk)
                    sink.append(chunk)
                }
            }
        } catch {
            for source in sources {
                await source.stop()
            }
            try? sink.finish()
            throw error
        }
    }

    public func stop() async throws {
        for source in sources {
            await source.stop()
        }
        try sink.finish()
    }
}
```

- [ ] **Step 9: 验证并提交**

```bash
swift test --package-path InterviewAssistant \
  --filter LiveInterviewRecorderTests
swift test --package-path InterviewAssistant
git add InterviewAssistant
git commit -m "feat: record system and microphone audio"
```

Expected: tests PASS。

---

### Task 5: 接入真实录音器并完成最小验收

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/InterviewAssistantApp.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/MainView.swift`
- Create: `InterviewAssistant/README.md`

**Interfaces:**
- Consumes: `LiveInterviewRecorder`
- Consumes: `SessionController`
- Produces: 用户可直接运行的 `.app`

- [ ] **Step 1: 在 App 中组装真实依赖**

`InterviewAssistantApp` 初始化：

```swift
@main
@MainActor
struct InterviewAssistantApp: App {
    @StateObject private var controller: SessionController

    init() {
        let hub = AudioTapHub(capacitySeconds: 30)
        let recorder = LiveInterviewRecorder(
            sources: [
                SystemAudioCapture(),
                MicrophoneCapture()
            ],
            sink: CAFFileSink(),
            hub: hub
        )
        _controller = StateObject(
            wrappedValue: SessionController(engine: recorder)
        )
    }

    var body: some Scene {
        WindowGroup("面试助手") {
            MainView(controller: controller)
        }
        .windowResizability(.contentSize)
    }
}
```

- [ ] **Step 2: 完成一键界面**

`MainView` 只显示：

- 当前状态；
- 一个开始/停止按钮；
- 录音中的场次目录；
- 权限或录音错误；
- “系统声音”和“麦克风”两个活动指示灯。

不加入模型、语言、声道或格式选择。

- [ ] **Step 3: 写运行说明**

`InterviewAssistant/README.md` 包含以下命令：

```bash
swift test --package-path InterviewAssistant
zsh InterviewAssistant/Scripts/build-app.sh
open InterviewAssistant/.build/app/面试助手.app
```

并说明首次启动需要在“系统设置 → 隐私与安全性”中允许：

- 屏幕与系统音频录制；
- 麦克风。

- [ ] **Step 4: 完成自动验证**

Run:

```bash
swift test --package-path InterviewAssistant
swift build --package-path InterviewAssistant -c release
zsh InterviewAssistant/Scripts/build-app.sh
codesign --verify --deep --strict \
  InterviewAssistant/.build/app/面试助手.app
```

Expected: 所有命令退出码为 0。

- [ ] **Step 5: 完成人工冒烟测试**

1. 打开一个会播放人声的网页或会议软件；
2. 启动面试助手；
3. 点击“开始面试”；
4. 播放系统声音并对麦克风说话 20 秒；
5. 点击“停止面试”；
6. 确认场次目录存在 `system.caf` 和 `microphone.caf`；
7. 分别播放两个文件；
8. 确认系统声音只在 `system.caf`，麦克风声音在 `microphone.caf`；
9. 确认停止后两个文件都能正常打开。

- [ ] **Step 6: 提交**

```bash
git add InterviewAssistant
git commit -m "feat: deliver one-click interview recording"
```

---

## 完成标准

本计划完成时必须满足：

- 面试助手是独立 App；
- 一键开始和停止；
- 系统声音与麦克风同时采集；
- 两路音频分别保存；
- `AudioTapHub` 能把音频提供给后续 ASR；
- `swift test` 全部通过；
- App 可以在没有完整 Xcode 的当前机器上打包；
- 20 秒人工录音测试成功。
