# Interview History Browser and Logo Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a searchable local interview-history browser and refresh the selected “声音 M” app icon with a white background and thicker blue stroke.

**Architecture:** `InterviewHistoryStore` owns filesystem discovery and converts each session directory into a resilient `InterviewHistoryRecord`. `HistoryBrowserView` owns search, selection, detail display, and Finder/player actions, while `MainView` only presents the sheet. Resume metadata is copied into every new session so future records have stable names; older sessions keep a date-based fallback.

**Tech Stack:** Swift 6.1, SwiftUI, AppKit `NSWorkspace`, Foundation filesystem APIs, XCTest-style custom test runner, macOS ICNS tooling.

## Global Constraints

- Runs locally on macOS 14 or later with no new third-party dependency.
- Search is case-insensitive across session date/name, resume name/text, evaluation, and transcript.
- Missing or corrupt files affect only that field or session; the history browser remains usable.
- History is read-only: no delete action.
- The selected V3 “声音 M” composition stays recognizable; use a white background and one thicker, smooth blue stroke.

---

### Task 1: Preserve Resume Metadata in New Sessions

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Resume/CurrentResumeStore.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/CurrentResumeStoreTests.swift`

**Interfaces:**
- Consumes: `CurrentResumeStore.copyArtifacts(to:)`
- Produces: a `resume-metadata.json` copy in each newly created session directory

- [ ] **Step 1: Extend the artifact-copy test**

Add an assertion that `session/resume-metadata.json` exists and decodes to the original `ResumeDocument.originalFileName`.

- [ ] **Step 2: Run the tests and verify the new assertion fails**

Run: `cd InterviewAssistant && swift run InterviewAssistantTests`

Expected: FAIL because `copyArtifacts(to:)` does not yet copy `resume-metadata.json`.

- [ ] **Step 3: Copy the metadata artifact**

Change the artifact list to:

```swift
[
    "resume.txt",
    "resume-evaluation.md",
    "resume-metadata.json",
]
```

- [ ] **Step 4: Run the tests and verify they pass**

Run: `cd InterviewAssistant && swift run InterviewAssistantTests`

Expected: all existing tests plus the metadata assertion pass.

- [ ] **Step 5: Commit**

```bash
git add InterviewAssistant/Sources/InterviewAssistantCore/Resume/CurrentResumeStore.swift InterviewAssistant/Tests/InterviewAssistantTests/CurrentResumeStoreTests.swift
git commit -m "fix: preserve resume metadata in interview sessions"
```

### Task 2: Load and Search Interview History

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Session/InterviewHistoryRecord.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Session/InterviewHistoryStore.swift`
- Create: `InterviewAssistant/Tests/InterviewAssistantTests/InterviewHistoryStoreTests.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/TestSupport.swift`

**Interfaces:**
- Consumes: session folders created by `SessionDirectoryStore`
- Produces: `InterviewHistoryStore.load() -> [InterviewHistoryRecord]` and `InterviewHistoryRecord.matches(_:) -> Bool`

- [ ] **Step 1: Write store tests**

Cover newest-first sorting, resume filename loading, evaluation and transcript loading, both CAF URLs, case-insensitive search, old sessions without metadata, and corrupt metadata isolation.

- [ ] **Step 2: Register and run the tests**

Run: `cd InterviewAssistant && swift run InterviewAssistantTests`

Expected: build failure because the history types do not yet exist.

- [ ] **Step 3: Implement the record**

Create a `Sendable`, `Identifiable`, `Equatable` value containing:

```swift
public let id: String
public let directory: URL
public let startedAt: Date
public let displayName: String
public let resumeFileName: String?
public let resumeText: String?
public let evaluation: String?
public let transcript: String?
public let systemAudioURL: URL?
public let microphoneAudioURL: URL?
```

Implement `matches(_:)` by normalizing the query and searchable fields with `localizedCaseInsensitiveContains`.

- [ ] **Step 4: Implement the filesystem store**

Scan immediate subdirectories of `Sessions`, parse the `yyyyMMdd-HHmmss` prefix in Asia/Shanghai, read each text file independently, decode only the resume metadata needed for naming, detect audio-file existence, and sort descending by `startedAt`.

- [ ] **Step 5: Run the tests**

Run: `cd InterviewAssistant && swift run InterviewAssistantTests`

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add InterviewAssistant/Sources/InterviewAssistantCore/Session/InterviewHistoryRecord.swift InterviewAssistant/Sources/InterviewAssistantCore/Session/InterviewHistoryStore.swift InterviewAssistant/Tests/InterviewAssistantTests/InterviewHistoryStoreTests.swift InterviewAssistant/Tests/InterviewAssistantTests/TestSupport.swift
git commit -m "feat: load and search interview history"
```

### Task 3: Add the History Browser Sheet

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantApp/HistoryBrowserView.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/MainView.swift`

**Interfaces:**
- Consumes: `InterviewHistoryStore.load()` and `InterviewHistoryRecord`
- Produces: a “历史记录” header button and a two-column history sheet

- [ ] **Step 1: Build the history browser**

Create a two-column SwiftUI view with a search field and newest-first record list on the left. On the right, show segmented sections for evaluation, transcript, and recordings, with “未记录” for missing fields.

- [ ] **Step 2: Add file actions**

Use `NSWorkspace.shared.open(_:)` for candidate audio, interviewer audio, and the session directory. Show a short alert when an available URL cannot be opened.

- [ ] **Step 3: Present the browser from the header**

Add `@State private var showsHistory = false`, a “历史记录” button before the resume button, and:

```swift
.sheet(isPresented: $showsHistory) {
    HistoryBrowserView(store: InterviewHistoryStore())
}
```

- [ ] **Step 4: Build and run the automated tests**

Run: `cd InterviewAssistant && swift run InterviewAssistantTests`

Expected: all tests pass and the app target compiles.

- [ ] **Step 5: Commit**

```bash
git add InterviewAssistant/Sources/InterviewAssistantApp/HistoryBrowserView.swift InterviewAssistant/Sources/InterviewAssistantApp/MainView.swift
git commit -m "feat: add searchable interview history browser"
```

### Task 4: Refresh the Selected App Icon

**Files:**
- Modify: `InterviewAssistant/Resources/AppIconSource.png`
- Modify: `InterviewAssistant/Resources/AppIcon.icns`

**Interfaces:**
- Consumes: the current V3 third “声音 M” source artwork
- Produces: a white-background, thick-blue-stroke PNG and ICNS

- [ ] **Step 1: Inspect the current icon**

Open `InterviewAssistant/Resources/AppIconSource.png` and confirm it is the selected V3 third concept.

- [ ] **Step 2: Edit the icon artwork**

Use image editing with the current PNG as the reference. Preserve the exact centered waveform/M silhouette, replace the dark background with white, make the blue rounded stroke about 1.6 times thicker, and avoid text, gradients, extra colors, or decorative elements.

- [ ] **Step 3: Replace the source and rebuild ICNS**

Copy the accepted generated image to `AppIconSource.png`, generate the standard 16–1024 px iconset with `sips`, and run `iconutil -c icns`.

- [ ] **Step 4: Verify the resources**

Run:

```bash
sips -g pixelWidth -g pixelHeight InterviewAssistant/Resources/AppIconSource.png
file InterviewAssistant/Resources/AppIcon.icns
```

Expected: a square high-resolution PNG and a valid macOS icon resource.

- [ ] **Step 5: Commit**

```bash
git add InterviewAssistant/Resources/AppIconSource.png InterviewAssistant/Resources/AppIcon.icns
git commit -m "design: refresh interview assistant app icon"
```

### Task 5: Build, Install, and Verify

**Files:**
- Verify: `InterviewAssistant/Scripts/build-app.sh`
- Install: `/Users/ben/Applications/面试助手.app`

**Interfaces:**
- Consumes: all implementation and icon commits
- Produces: a signed, installed, running app with working history access

- [ ] **Step 1: Run the complete test suite**

Run: `cd InterviewAssistant && swift run InterviewAssistantTests`

Expected: all tests pass with zero failures.

- [ ] **Step 2: Build the signed app**

Run: `zsh InterviewAssistant/Scripts/build-app.sh`

Expected: `.build/app/面试助手.app` is produced and signed.

- [ ] **Step 3: Replace the installed app**

Quit the current app, copy the built bundle to `/Users/ben/Applications/面试助手.app`, refresh Launch Services, and open one fresh instance.

- [ ] **Step 4: Verify installation**

Check `codesign --verify --deep --strict`, `CFBundleIconFile`, the running process count, and that opening “历史记录” shows existing sessions with searchable evaluation, transcript, and recording actions.

- [ ] **Step 5: Commit any verification-only source corrections**

If verification exposes a source issue, fix it with a focused test and commit. Otherwise leave the worktree clean.
