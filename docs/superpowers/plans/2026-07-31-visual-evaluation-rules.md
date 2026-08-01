# Visual Evaluation Rules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a local visual editor for resume and interview evaluation rules, including structured configuration, advanced full-prompt editing, validation, prompt generation, and safe fallback.

**Architecture:** Introduce a Codable rules model with one store and validator in `InterviewAssistantCore`. Prompt composition and result normalization consume the same active rules so configurable scoring and sections remain parseable. A SwiftUI rules sheet edits a draft and only activates it after validation; Codex providers load the active rules for every generation.

**Tech Stack:** Swift 6.1, SwiftUI, Foundation Codable/JSON, existing Codex CLI provider and custom executable test harness.

## Global Constraints

- Keep all configuration local under `~/Library/Application Support/InterviewAssistant/EvaluationRules/`.
- Default rules must reproduce the current five score dimensions, 75/60 thresholds, interview sections, and five resume questions.
- Draft changes do not affect generation until “保存并启用” succeeds.
- Invalid configuration never replaces the current or last-valid rule.
- Existing evaluations without rule snapshots continue to load with default rules.
- No cloud sync, multi-user collaboration, job-specific rule libraries, or version-history browser in this release.

---

### Task 1: Rules model, validation, and local persistence

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/EvaluationRules/EvaluationRulesConfiguration.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/EvaluationRules/EvaluationRulesValidator.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/EvaluationRules/EvaluationRulesStore.swift`
- Create: `InterviewAssistant/Tests/InterviewAssistantTests/EvaluationRulesTests.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/TestSupport.swift`

**Interfaces:**
- Produces: `EvaluationRulesConfiguration.default`, `EvaluationRulesValidator.validate(_:)`, `EvaluationRulesStore.load()`, `save(_:)`, and `restoreDefault()`.

- [ ] **Step 1: Write failing model and store tests**

Test that defaults total 100, thresholds are 75/60, both advanced templates contain required variables, valid JSON round-trips, corrupt `current.json` falls back to `last-valid.json`, and invalid totals/thresholds/duplicate IDs/missing variables are rejected.

- [ ] **Step 2: Run the tests and confirm missing-type failures**

Run: `cd InterviewAssistant && swift run InterviewAssistantTests`

Expected: compilation fails because `EvaluationRulesConfiguration` does not exist.

- [ ] **Step 3: Implement the Codable model and defaults**

Define `PromptEditingMode`, `ScoreDimensionRule`, `DecisionThresholdRules`, `EvaluationSectionKind`, `EvaluationSectionRule`, `InterviewEvaluationRules`, `ResumeEvaluationRules`, and `EvaluationRulesConfiguration`. Use stable UUID-like string IDs and mutable public properties so SwiftUI can bind drafts.

- [ ] **Step 4: Implement validation and atomic persistence**

Validation returns field-specific Chinese `LocalizedError` messages. `save` validates first, copies an existing valid current file to `last-valid.json`, then atomically writes `current.json`. `load` tries current, last-valid, then defaults.

- [ ] **Step 5: Run tests and commit**

Run: `cd InterviewAssistant && swift run InterviewAssistantTests`

Expected: all tests pass.

Commit: `feat: add editable evaluation rules model`

### Task 2: Rule-driven prompt composition

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/EvaluationRules/EvaluationPromptComposer.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/AnalysisPrompts.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/AnalysisPromptTests.swift`
- Create: `InterviewAssistant/Tests/InterviewAssistantTests/EvaluationPromptComposerTests.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/TestSupport.swift`

**Interfaces:**
- Consumes: `EvaluationRulesConfiguration` from Task 1.
- Produces: `EvaluationPromptComposer.interview(...)`, `resume(...)`, and `preview(...)`.

- [ ] **Step 1: Write failing prompt tests**

Test custom dimensions and maximum scores, custom decision thresholds, reordered/custom sections, custom question count, structured mode, and advanced variable replacement for `{{transcript}}`, `{{resume}}`, `{{customRequirement}}`, and `{{outputContract}}`.

- [ ] **Step 2: Run tests and confirm failures**

Run: `cd InterviewAssistant && swift run InterviewAssistantTests`

Expected: compilation fails because `EvaluationPromptComposer` is missing.

- [ ] **Step 3: Implement one output-contract builder**

Build Markdown headings and exact dimension lines from section and dimension rules. Structured mode surrounds the contract with evidence/logic instructions; advanced mode replaces variables in the full template. Keep `AnalysisPrompts` overloads with defaults for source compatibility.

- [ ] **Step 4: Run tests and commit**

Run: `cd InterviewAssistant && swift run InterviewAssistantTests`

Expected: all tests pass.

Commit: `feat: compose prompts from evaluation rules`

### Task 3: Rule-driven parsing, provider use, and safe snapshots

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/InterviewEvaluationScorecard.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/CompactInterviewEvaluation.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/CompactResumeEvaluation.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/CodexCLIProvider.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/History/HistoricalEvaluationRegenerator.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/IntelligenceModelTests.swift`
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/HistoricalEvaluationRegeneratorTests.swift`

**Interfaces:**
- Consumes: rules store and prompt composer from Tasks 1–2.
- Produces: `normalize(_:rules:)` overloads and rule snapshots named `evaluation-rules.json` / `resume-evaluation-rules.json`.

- [ ] **Step 1: Write failing parsing tests**

Test non-default dimension names and maxima, thresholds, reordered sections, a custom output section, and changed resume question count. Test that an invalid model response leaves an existing evaluation and snapshot untouched.

- [ ] **Step 2: Run tests and confirm the fixed parser rejects custom rules**

Run: `cd InterviewAssistant && swift run InterviewAssistantTests`

Expected: the new custom-rule cases fail.

- [ ] **Step 3: Make score and section parsing consume rules**

Validate returned dimensions against configured IDs/order/totals, clamp recommendations to configured thresholds, normalize required and optional sections in configured order, and retain default overloads for old records.

- [ ] **Step 4: Load current rules per generation and write snapshots only after success**

`CodexCLIProvider` loads the active rule immediately before composing each evaluation. Save the corresponding JSON snapshot only after prompt output validates. Historical regeneration writes new evaluation and snapshot through staging files so either both replace the old pair or neither does.

- [ ] **Step 5: Run tests and commit**

Run: `cd InterviewAssistant && swift run InterviewAssistantTests`

Expected: all tests pass.

Commit: `feat: evaluate candidates with active rules`

### Task 4: Visual rules editor

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantApp/EvaluationRulesView.swift`
- Create: `InterviewAssistant/Sources/InterviewAssistantApp/EvaluationRulesViewModel.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/MainView.swift`

**Interfaces:**
- Consumes: `EvaluationRulesStore`, validator, and prompt preview.
- Produces: a sheet launched by the main-window “评价规则” button.

- [ ] **Step 1: Add the main-window entry and sheet state**

Place `Label("评价规则", systemImage: "slider.horizontal.3")` next to “历史记录”. Opening the sheet creates an isolated draft loaded from the store.

- [ ] **Step 2: Build the three-tab editor**

Implement “面试评价 / 简历初评 / 高级提示词”. The structured tabs show a left navigation, central flow cards, and a right editor. Provide add/delete/move controls for dimensions and optional sections while disabling deletion of required sections.

- [ ] **Step 3: Add save, reset, and preview behavior**

“恢复默认” only resets the draft. “查看最终提示词” opens a selectable preview. “保存并启用” validates and persists; errors appear in a Chinese alert without closing the sheet.

- [ ] **Step 4: Build and commit**

Run: `cd InterviewAssistant && swift build && swift run InterviewAssistantTests`

Expected: app builds and all tests pass.

Commit: `feat: add visual evaluation rules editor`

### Task 5: Final verification, installation, and remote sync

**Files:**
- Modify only if verification reveals a defect.

- [ ] **Step 1: Verify source and release bundle**

Run: `cd InterviewAssistant && swift build && swift run InterviewAssistantTests && zsh Scripts/build-app.sh`

Expected: build exits 0, all tests pass, and `.build/app/面试助手.app` has a valid signature.

- [ ] **Step 2: Install and relaunch**

Quit the old app, copy the signed bundle to `/Users/ben/Applications/面试助手.app`, verify with `codesign --verify --deep --strict`, and open one fresh process.

- [ ] **Step 3: Manually verify the UI without modifying user data**

Open “评价规则”; confirm all three tabs, five default dimensions, 75/60 thresholds, default output sections, preview, restore, and save buttons. Do not click save during the smoke test.

- [ ] **Step 4: Sync to `rw820/QuickRecorder`**

Push a privacy-safe commit tree to `fork/main` and verify `HEAD^{tree}` equals `fork/main^{tree}`.
