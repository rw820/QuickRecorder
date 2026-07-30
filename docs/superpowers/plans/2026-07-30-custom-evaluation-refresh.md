# Custom Evaluation Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users refresh resume and interview evaluations with an optional one-time manual requirement.

**Architecture:** Add optional refresh requirements at the prompt and provider boundary. Resume refresh continues through `ResumeImportService`; interview refresh delegates from `SessionController` to `AssistedInterviewEngine` and the active `InterviewIntelligencePipeline`, which reuses the completed transcript and overwrites the saved evaluation. `MainView` presents one small refresh sheet for both evaluation types.

**Tech Stack:** Swift 6, SwiftUI, Foundation concurrency, existing local Codex CLI provider and custom Swift test runner.

## Global Constraints

- Empty or whitespace-only requirements behave like the existing default refresh.
- Custom requirements apply to one refresh only and are not persisted.
- Fixed evaluation sections and evidence constraints remain mandatory.
- Refresh failure preserves the previous evaluation.
- Interview refresh is unavailable while recording or before a completed transcript exists.

---

### Task 1: Prompt and Provider Requirement Support

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/AnalysisPrompts.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/InterviewAnalysisProvider.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/CodexCLIProvider.swift`
- Test: `InterviewAssistant/Tests/InterviewAssistantTests/AnalysisPromptTests.swift`

**Interfaces:**
- Produces: `generateResumeEvaluation(from:customRequirement:)`
- Produces: `generateEvaluation(from:resumeText:customRequirement:)`

- [ ] **Step 1: Write failing prompt tests**

Add tests that call:

```swift
AnalysisPrompts.resumeEvaluation(
    resume: "候选人简历",
    customRequirement: "重点评价数据能力"
)
AnalysisPrompts.evaluation(
    transcript: "候选人回答",
    customRequirement: "总评控制在八十字"
)
```

Assert each non-empty requirement appears in the prompt and a whitespace-only requirement does not add a “本次刷新要求” section.

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
cd InterviewAssistant && swift run InterviewAssistantTests
```

Expected: compile failure because the prompt overloads do not accept `customRequirement`.

- [ ] **Step 3: Implement provider overloads and prompt sections**

Add protocol requirements with default implementations so existing providers remain source-compatible:

```swift
func generateResumeEvaluation(
    from resumeText: String,
    customRequirement: String?
) async throws -> InterviewEvaluation

func generateEvaluation(
    from transcript: [TranscriptLine],
    resumeText: String?,
    customRequirement: String?
) async throws -> InterviewEvaluation
```

Normalize requirements with `trimmingCharacters(in:)`. Append a section only when non-empty:

```swift
本次刷新要求：
\(requirement)
在保持固定输出结构和事实约束的前提下，优先满足以上要求。
```

Make the existing Codex provider methods delegate to the new overloads with `nil`.

- [ ] **Step 4: Run tests and verify GREEN**

Run the full Swift test command and expect all existing plus new prompt tests to pass.

- [ ] **Step 5: Commit**

```bash
git add InterviewAssistant/Sources/InterviewAssistantCore/Intelligence InterviewAssistant/Tests/InterviewAssistantTests/AnalysisPromptTests.swift
git commit -m "feat: support custom evaluation requirements"
```

### Task 2: Resume Refresh Requirement Flow

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Resume/ResumeImportService.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Session/SessionController.swift`
- Test: `InterviewAssistant/Tests/InterviewAssistantTests/ResumeImportServiceTests.swift`
- Test: `InterviewAssistant/Tests/InterviewAssistantTests/SessionControllerTests.swift`

**Interfaces:**
- Consumes: `generateResumeEvaluation(from:customRequirement:)`
- Produces: `refreshEvaluation(customRequirement:)`
- Produces: `refreshResumeEvaluation(customRequirement:)`

- [ ] **Step 1: Write failing resume refresh tests**

Capture the requirement in a test provider and assert:

```swift
let result = try await service.refreshEvaluation(
    customRequirement: "重点核对管理报表经验"
)
```

passes the exact requirement to the provider and saves the returned evaluation. Update the controller spy to capture the same value and assert forwarding.

- [ ] **Step 2: Run tests and verify RED**

Run the full test command. Expected: compile failure because the refresh methods lack the parameter.

- [ ] **Step 3: Implement resume refresh forwarding**

Keep `refreshEvaluation()` as a convenience method that calls:

```swift
refreshEvaluation(customRequirement: nil)
```

The custom overload loads the current resume, calls the new provider overload, saves the evaluation, and returns it. Give `SessionController.refreshResumeEvaluation` a defaulted optional parameter and forward it.

- [ ] **Step 4: Run tests and verify GREEN**

Run all tests and confirm both old no-argument refresh and custom refresh pass.

- [ ] **Step 5: Commit**

```bash
git add InterviewAssistant/Sources/InterviewAssistantCore/Resume InterviewAssistant/Sources/InterviewAssistantCore/Session/SessionController.swift InterviewAssistant/Tests/InterviewAssistantTests
git commit -m "feat: refresh resume evaluation with instructions"
```

### Task 3: Completed Interview Refresh

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Session/InterviewEvaluationRefreshing.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Session/AssistedInterviewEngine.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/InterviewIntelligencePipeline.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Session/SessionController.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/InterviewAssistantApp.swift`
- Test: `InterviewAssistant/Tests/InterviewAssistantTests/InterviewIntelligencePipelineTests.swift`
- Test: `InterviewAssistant/Tests/InterviewAssistantTests/SessionControllerTests.swift`

**Interfaces:**
- Produces: `InterviewEvaluationRefreshing.refreshEvaluation(customRequirement:)`
- Produces: `SessionController.refreshCurrentEvaluation(customRequirement:)`
- Produces: `SessionController.isRefreshingEvaluation`

- [ ] **Step 1: Write failing interview refresh tests**

After `pipeline.finish()`, call:

```swift
let refreshed = try await pipeline.refreshEvaluation(
    customRequirement: "重点评价架构能力"
)
```

Assert the provider received the existing transcript, current resume, and exact requirement; assert `evaluation-report.md` contains the refreshed result. Add a controller test using an `InterviewEvaluationRefreshing` spy and assert the current interview evaluation is replaced.

- [ ] **Step 2: Run tests and verify RED**

Run all tests. Expected: compile failure because the refresh protocol and methods do not exist.

- [ ] **Step 3: Implement interview refresh**

Create:

```swift
public protocol InterviewEvaluationRefreshing: Sendable {
    func refreshEvaluation(
        customRequirement: String?
    ) async throws -> InterviewEvaluation
}
```

Have `AssistedInterviewEngine` delegate to the pipeline. The pipeline must require a completed directory and non-empty transcript, recreate the provider if needed, generate the evaluation with the requirement, overwrite `evaluation-report.md`, and return the result.

Inject the refresher into `SessionController`. Add separate resume/interview busy flags and a unified `refreshCurrentEvaluation(customRequirement:)` dispatcher. Preserve the old evaluation on errors.

- [ ] **Step 4: Run tests and verify GREEN**

Run all tests and confirm the saved refreshed interview report, forwarding, and failure behavior.

- [ ] **Step 5: Commit**

```bash
git add InterviewAssistant/Sources/InterviewAssistantCore InterviewAssistant/Sources/InterviewAssistantApp/InterviewAssistantApp.swift InterviewAssistant/Tests/InterviewAssistantTests
git commit -m "feat: refresh completed interview evaluations"
```

### Task 4: Unified SwiftUI Refresh Sheet and Installation

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/MainView.swift`

**Interfaces:**
- Consumes: `refreshCurrentEvaluation(customRequirement:)`
- Consumes: `isRefreshingEvaluation`

- [ ] **Step 1: Add refresh sheet state and UI**

Add `showsEvaluationRefresh` and `evaluationRefreshRequirement`. Show a refresh button for either evaluation type. Clicking opens a sheet with a multiline input, “取消”, and “刷新”; submitting trims the requirement and calls the unified controller method.

- [ ] **Step 2: Build and run all tests**

Run:

```bash
cd InterviewAssistant && swift run InterviewAssistantTests
cd .. && zsh Scripts/build-app.sh
```

Expected: all tests pass and the signed application build completes.

- [ ] **Step 3: Install and verify**

Replace `/Users/ben/Applications/面试助手.app`, verify with:

```bash
codesign --verify --deep --strict --verbose=2 /Users/ben/Applications/面试助手.app
```

Open the app and confirm both evaluation types expose the refresh sheet.

- [ ] **Step 4: Commit**

```bash
git add InterviewAssistant/Sources/InterviewAssistantApp/MainView.swift
git commit -m "feat: add custom refresh requirement sheet"
```
