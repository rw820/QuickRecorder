# Attach Resume to Interview History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add or replace a resume on any historical interview and automatically regenerate its evaluation from that resume and the saved transcript.

**Architecture:** Store newly attached resumes in each session’s isolated `AttachedResume` directory using the existing atomic `CurrentResumeStore`. Make history loading and evaluation regeneration prefer that directory while retaining fallback support for legacy root-level resume files. The history view runs attachment followed by regeneration as one user action and reloads the selected record.

**Tech Stack:** Swift 6, SwiftUI file importer, existing resume extraction/OCR, current resume store, Codex evaluation provider, custom Swift test runner.

## Global Constraints

- Attaching a historical resume must not change the homepage current resume.
- Supported formats are PDF, DOC, DOCX, TXT, PNG, JPG, and JPEG.
- Audio and transcript files are read-only.
- New evaluation replaces the old one only after successful generation and validation.
- If generation fails after attachment, keep the new resume and old evaluation.
- Legacy root-level session resumes remain readable.

---

### Task 1: Historical Resume Attachment Service

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/History/HistoricalResumeAttachmentService.swift`
- Create: `InterviewAssistant/Tests/InterviewAssistantTests/HistoricalResumeAttachmentServiceTests.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/TestSupport.swift`

**Interfaces:**
- Produces: `HistoricalResumeAttaching.attachResume(from:to:)`
- Produces: `HistoricalResumeAttachmentService`
- Consumes: `ResumeTextExtracting` and `CurrentResumeStore`

- [ ] **Step 1: Write failing service tests**

Inject a resume extractor stub, attach a TXT fixture to a temporary session, and assert:

```swift
let document = try await service.attachResume(
    from: sourceURL,
    to: sessionDirectory
)
try expect(document.originalFileName == "candidate.txt", "应保留文件名")
let store = CurrentResumeStore(
    root: sessionDirectory.appendingPathComponent("AttachedResume")
)
try expect(try store.load()?.text == "候选人简历", "应保存提取文字")
try expect(FileManager.default.fileExists(atPath:
    store.root.appendingPathComponent("original.txt").path),
    "应保存原文件")
```

Also test that an extractor failure leaves an existing attached resume unchanged.

- [ ] **Step 2: Run tests and verify RED**

Run `cd InterviewAssistant && swift run InterviewAssistantTests`.

Expected: compilation fails because the historical attachment types do not exist.

- [ ] **Step 3: Implement attachment service**

Define:

```swift
public protocol HistoricalResumeAttaching: Sendable {
    func attachResume(from sourceURL: URL, to sessionDirectory: URL)
        async throws -> ResumeDocument
}
```

The concrete actor starts security-scoped access, extracts text, creates
`CurrentResumeStore(root: sessionDirectory/AttachedResume)`, and calls
`save(sourceURL:text:)`.

- [ ] **Step 4: Run tests and verify GREEN**

Run all tests and confirm both the successful attachment and failure rollback pass.

- [ ] **Step 5: Commit**

```bash
git add InterviewAssistant/Sources/InterviewAssistantCore/History \
  InterviewAssistant/Tests/InterviewAssistantTests
git commit -m "feat: attach resumes to historical interviews"
```

### Task 2: Prefer Attached Historical Resume

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Session/InterviewHistoryStore.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/History/HistoricalEvaluationRegenerator.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/InterviewHistoryStoreTests.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/HistoricalEvaluationRegeneratorTests.swift`

**Interfaces:**
- Consumes: `AttachedResume/resume.txt` and `AttachedResume/resume-metadata.json`
- Produces: attached-resume-first loading with root-level fallback

- [ ] **Step 1: Write failing preference tests**

Create a session with a root legacy resume and a different resume inside
`AttachedResume`. Assert History uses the attached file name and text. In the
regenerator test, assert the provider receives attached resume text instead of
the root legacy text.

- [ ] **Step 2: Run tests and verify RED**

Run all tests.

Expected: preference assertions fail because both readers currently use root-level files.

- [ ] **Step 3: Implement preference and fallback**

In both readers, first check the `AttachedResume` directory. If its metadata or
text file is absent, use the existing root-level session file. Preserve the
existing behavior for all old sessions.

- [ ] **Step 4: Run tests and verify GREEN**

Run all tests and confirm attached preference and legacy compatibility pass.

- [ ] **Step 5: Commit**

```bash
git add InterviewAssistant/Sources/InterviewAssistantCore \
  InterviewAssistant/Tests/InterviewAssistantTests
git commit -m "feat: use attached resumes in historical evaluations"
```

### Task 3: One-Click Historical Resume UI

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/HistoryBrowserView.swift`

**Interfaces:**
- Consumes: `any HistoricalResumeAttaching`
- Consumes: `any HistoricalEvaluationRegenerating`
- Produces: “添加简历” / “替换简历” file-import workflow

- [ ] **Step 1: Add importer and processing state**

Inject `HistoricalResumeAttachmentService`, add the supported file importer,
remember the selected record ID, and show:

```swift
Label(
    record.resumeText == nil ? "添加简历" : "替换简历",
    systemImage: "doc.badge.plus"
)
```

While processing, show “正在添加并生成” and disable both resume attachment and
evaluation regeneration buttons.

- [ ] **Step 2: Attach then regenerate**

After file selection, call:

```swift
_ = try await resumeAttacher.attachResume(
    from: url,
    to: record.directory
)
_ = try await regenerator.regenerate(
    in: record.directory,
    customRequirement: nil
)
```

Reload `InterviewHistoryStore` and preserve the selected record. If the second
call fails, reload anyway so the new resume appears, retain the old evaluation,
and show an error explaining that only evaluation generation failed.

- [ ] **Step 3: Run tests and build**

Run:

```bash
cd InterviewAssistant
swift run InterviewAssistantTests
zsh Scripts/build-app.sh
```

Expected: all tests pass and the production app builds without warnings.

- [ ] **Step 4: Install and manually verify**

Install the app, open History, select a session, add a resume, and confirm the
record name changes to that resume and the regenerated evaluation contains the
scored eight-section format.

- [ ] **Step 5: Commit**

```bash
git add InterviewAssistant/Sources/InterviewAssistantApp/HistoryBrowserView.swift
git commit -m "feat: add resumes from interview history"
```
