# Filter Empty History Records Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show only real interview sessions in History and keep them sorted newest first.

**Architecture:** Filter session directories inside `InterviewHistoryStore` before creating records. A directory is valid when at least one interview artifact exists and has a file size greater than zero; existing date-based sorting remains the single ordering source.

**Tech Stack:** Swift 6, Foundation file resource values, existing custom Swift test runner.

## Global Constraints

- Empty session directories must not appear in History.
- Sessions with non-empty audio must remain visible even when transcription failed.
- Valid sessions must remain sorted by start time descending.
- Search behavior and old-session compatibility must remain unchanged.

---

### Task 1: Filter Empty Session Directories

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Session/InterviewHistoryStore.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/InterviewHistoryStoreTests.swift`

**Interfaces:**
- Consumes: session directories created by `SessionDirectoryStore`
- Produces: `InterviewHistoryStore.load() -> [InterviewHistoryRecord]` without empty records

- [ ] **Step 1: Write the failing regression test**

Create three session directories: one empty, one with a non-empty
`transcript.jsonl`, and one newer directory with non-empty `system.caf`.
Assert:

```swift
let records = InterviewHistoryStore(root: root).load()
try expect(records.count == 2, "空场次不应显示")
try expect(records.first?.id == audioSession.lastPathComponent,
           "最新有效场次应排在最前")
try expect(!records.contains { $0.id == empty.lastPathComponent },
           "空目录不应成为历史记录")
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
cd InterviewAssistant
swift run InterviewAssistantTests
```

Expected: the new test fails because the empty directory is currently returned.

- [ ] **Step 3: Implement meaningful-artifact filtering**

Add a private helper in `InterviewHistoryStore`:

```swift
private func hasInterviewContent(in directory: URL) -> Bool {
    [
        "transcript.jsonl", "transcript.md", "evaluation-report.md",
        "system.caf", "microphone.caf"
    ].contains { name in
        let url = directory.appendingPathComponent(name)
        guard let size = try? url.resourceValues(
            forKeys: [.fileSizeKey]
        ).fileSize else {
            return false
        }
        return size > 0
    }
}
```

Require this helper to return true before calling `makeRecord`. Do not change the
existing descending sort comparator.

- [ ] **Step 4: Run tests and build**

Run:

```bash
cd InterviewAssistant
swift run InterviewAssistantTests
zsh Scripts/build-app.sh
```

Expected: all tests pass and the signed app builds.

- [ ] **Step 5: Install and verify**

Install and reopen the app. Open History and confirm the empty July 30 time entries
are gone and the latest real interview is at the top.

- [ ] **Step 6: Commit**

```bash
git add InterviewAssistant/Sources/InterviewAssistantCore/Session/InterviewHistoryStore.swift \
  InterviewAssistant/Tests/InterviewAssistantTests/InterviewHistoryStoreTests.swift
git commit -m "fix: hide empty interview history records"
```
