# Live Transcript Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 录音时持续显示真实音频活动和临时转写。

**Architecture:** `AudioTapHub` 暴露每路音频最后到达时间，界面按时间窗口显示绿灯。转写通道发布独立的临时转写事件，控制器按音源更新一条临时内容，最终结果到达时清除临时内容。

**Tech Stack:** Swift 6、SwiftUI、SpeechAnalyzer、Swift Testing

## Global Constraints

- 临时转写不保存、不参与 AI 分析。
- 最终转写保持现有保存和分析流程。
- 音频指示不依赖环形缓冲区数量。

---

### Task 1: 音频活动时间

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Audio/AudioTapHub.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/MainView.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/AudioTapHubTests.swift`

- [ ] 写测试：`latestTimestamp(source:)` 在缓冲容量稳定后仍更新。
- [ ] 运行测试并确认缺少接口而失败。
- [ ] 在 `ingest` 时保存每路最新时间；界面以当前 uptime 与时间差小于 1 秒判断绿色。
- [ ] 运行测试确认通过。

### Task 2: 临时转写

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/AssistantEvent.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/SpeechRecognitionChannel.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/LiveTranscriptionService.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Session/SessionController.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/MainView.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/SessionControllerTests.swift`

- [ ] 写测试：临时事件按音源更新，正式行到达时清除对应临时文字。
- [ ] 运行测试并确认事件缺失而失败。
- [ ] 新增 `partialTranscript(source:text:)` 事件并贯通到控制器。
- [ ] `SpeechRecognitionChannel` 对非最终结果发布临时文本，对最终结果清空临时文本并沿用正式发布。
- [ ] 界面在正式逐字稿下显示两路“识别中…”内容。
- [ ] 运行 29 项以上测试和正式构建。
- [ ] 安装后实际录音，确认绿灯和临时/正式文字可见且无崩溃。
