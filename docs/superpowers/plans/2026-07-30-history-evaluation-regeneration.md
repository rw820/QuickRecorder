# History Evaluation Regeneration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users regenerate any saved interview evaluation from its original transcript and optional resume using the current evaluation rules.

**Architecture:** Add a core service that loads structured transcript JSONL, invokes an injected `InterviewAnalysisProvider`, and atomically replaces the saved evaluation only after generation succeeds. Add a button and loading/error state to the existing history detail view, then reload the selected history record after success.

**Tech Stack:** Swift 6, SwiftUI, Foundation JSONL decoding and atomic file writes, existing Codex CLI provider.

## Global Constraints

- Regeneration must not modify audio, transcript, resume, or metadata.
- A failed generation must preserve the previous evaluation file.
- Historical regeneration must use the current scored interview evaluation prompt.
- Records without a valid structured transcript cannot be regenerated.
- The UI must prevent duplicate regeneration while one request is running.

---

### Task 1: Historical Evaluation Regenerator

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/History/HistoricalEvaluationRegenerator.swift`
- Create: `InterviewAssistant/Tests/InterviewAssistantTests/HistoricalEvaluationRegeneratorTests.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/TestSupport.swift`

**Interfaces:**
- Produces: `HistoricalEvaluationRegenerating.regenerate(in:customRequirement:)`
- Produces: `HistoricalEvaluationRegenerator`
- Consumes: `InterviewAnalysisProvider.generateEvaluation(from:resumeText:customRequirement:)`

- [ ] **Step 1: Write failing tests**

Add tests that create a temporary session with two JSONL `TranscriptLine` values,
an optional `resume.txt`, and an existing `evaluation-report.md`. Inject a provider
stub and assert:

```swift
let result = try await regenerator.regenerate(
    in: directory,
    customRequirement: nil
)
try expect(result.markdown.contains("## 结论"), "应返回新版评价")
try expect(provider.transcriptCount == 2, "应读取完整结构化逐字稿")
try expect(provider.resumeText == "候选人简历", "应传入该场简历")
```

Add separate cases for a missing transcript and a throwing provider. Both must
leave the previous `evaluation-report.md` unchanged.

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
cd InterviewAssistant
swift run InterviewAssistantTests
```

Expected: compilation fails because `HistoricalEvaluationRegenerator` does not exist.

- [ ] **Step 3: Implement minimal regeneration service**

Create:

```swift
public protocol HistoricalEvaluationRegenerating: Sendable {
    func regenerate(
        in directory: URL,
        customRequirement: String?
    ) async throws -> InterviewEvaluation
}
```

The concrete service must:

1. Decode every non-empty line of `transcript.jsonl` as `TranscriptLine`.
2. Reject an absent, empty, or corrupt transcript.
3. Read optional UTF-8 `resume.txt`.
4. Create a provider for the selected directory.
5. Generate the evaluation with the current provider API.
6. Write the new markdown atomically to `evaluation-report.md`.

- [ ] **Step 4: Run tests and verify GREEN**

Run the full test suite and confirm all historical regeneration and existing tests pass.

- [ ] **Step 5: Commit**

```bash
git add InterviewAssistant/Sources/InterviewAssistantCore/History \
  InterviewAssistant/Tests/InterviewAssistantTests
git commit -m "feat: regenerate saved interview evaluations"
```

### Task 2: History Regeneration Interface

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/HistoryBrowserView.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/InterviewAssistantApp.swift`

**Interfaces:**
- Consumes: `any HistoricalEvaluationRegenerating`
- Produces: a “重新生成评价” button in history evaluation detail

- [ ] **Step 1: Add regeneration state and action**

Inject a regenerator into `HistoryBrowserView`. Add:

```swift
@State private var regeneratingID: InterviewHistoryRecord.ID?
@State private var regenerationError: String?
```

In the evaluation detail header, show “重新生成评价”. Disable it when the
selected record has no transcript or a request is already running. While running,
show a small progress indicator.

- [ ] **Step 2: Reload the selected record after success**

Call:

```swift
let evaluation = try await regenerator.regenerate(
    in: record.directory,
    customRequirement: nil
)
```

Then replace the matching record with a newly loaded record from
`InterviewHistoryStore`, keeping the same selection and showing the new evaluation.
On error, retain the old record and present `error.localizedDescription`.

- [ ] **Step 3: Build and verify**

Run:

```bash
cd InterviewAssistant
swift run InterviewAssistantTests
zsh Scripts/build-app.sh
```

Expected: all tests pass and the production app builds and signs successfully.

- [ ] **Step 4: Install and manually verify**

Install the new app, open History, select the July 30 afternoon interview, click
“重新生成评价”, and confirm the evaluation now contains 结论、综合评分、分项评分、
逻辑分析、总评、优势、劣势和风险.

- [ ] **Step 5: Commit**

```bash
git add InterviewAssistant/Sources/InterviewAssistantApp
git commit -m "feat: regenerate evaluations from history"
```
