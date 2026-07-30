# Scored Interview Evaluation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add job-related logic analysis, weighted scoring, confidence, and three-level interview recommendations to completed interview evaluations.

**Architecture:** Keep `InterviewEvaluation` markdown-compatible for history and persistence. Add a focused scorecard parser that validates the new structured sections, then let `CompactInterviewEvaluation` canonicalize scored output while preserving legacy four-section evaluations. `MainView` renders scorecards only for interview evaluations that contain the new structure.

**Tech Stack:** Swift 6, SwiftUI, Foundation regular expressions, existing local Codex CLI provider and custom Swift test runner.

## Global Constraints

- Scores total 100: logic 25, role fit 20, professional capability 20, evidence 20, consistency risk 15.
- Recommendations are `建议通过`, `保留复核`, or `不建议通过`.
- Scores of 75 or more allow `建议通过`; 60–74 allow at most `保留复核`; 59 or less allow at most `不建议通过`.
- Insufficient transcript evidence allows at most `保留复核`.
- Evaluation must ignore age, gender, marital or parental status, hometown, and other job-irrelevant attributes.
- ASR errors and isolated filler words must not directly reduce logic score.
- Legacy interview evaluations and resume evaluations remain readable.

---

### Task 1: Scorecard Model and Validation

**Files:**
- Create: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/InterviewEvaluationScorecard.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/CompactInterviewEvaluation.swift`
- Test: `InterviewAssistant/Tests/InterviewAssistantTests/IntelligenceModelTests.swift`

**Interfaces:**
- Produces: `InterviewEvaluationScorecard.parse(from:)`
- Produces: `InterviewRecommendation`
- Produces: `InterviewEvaluationDimension`
- Produces: `CompactInterviewEvaluation.normalize(_:)` support for scored and legacy output

- [ ] **Step 1: Write failing scorecard tests**

Use scored markdown containing:

```swift
## 结论
保留复核
置信度：中
理由：回答结构与量化证据仍需复核。

## 综合评分
58/100

## 分项评分
- 逻辑表达：11/25｜多次回答未先给结论。
- 岗位匹配：13/20｜具备财务数据场景经验。
- 专业能力：12/20｜技术全链路说明不完整。
- 成果证据：10/20｜量化结果不足。
- 风险一致性：12/15｜职责边界存在差异。

## 逻辑分析
- 答非所问：价值判断问题回答成既定任务描述。
- 因果不完整：缺少行动后的量化结果。
```

Assert parsing returns total 58, five dimensions, `保留复核`, confidence `中`, and two logic findings. Add cases that reject an out-of-range score, recalculate a mismatched total, cap an overly positive recommendation, and continue accepting legacy four-section markdown.

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
cd InterviewAssistant && swift run InterviewAssistantTests
```

Expected: compile failure because the scorecard types and parser do not exist.

- [ ] **Step 3: Implement scorecard types and parser**

Create immutable `Sendable` structs and enums. Parse exact headings with `CompactInterviewEvaluation.section`, validate the five expected maxima, sum dimension scores, and normalize recommendation with:

```swift
let thresholdRecommendation: InterviewRecommendation =
    total >= 75 ? .recommended
    : total >= 60 ? .review
    : .notRecommended
let recommendation = min(
    modelRecommendation,
    thresholdRecommendation
)
```

When any scored heading is present, require the complete scorecard. Keep the existing normalization path when none of the scored headings exists.

- [ ] **Step 4: Run tests and verify GREEN**

Run all tests and confirm scored validation and legacy compatibility pass.

- [ ] **Step 5: Commit**

```bash
git add InterviewAssistant/Sources/InterviewAssistantCore/Intelligence InterviewAssistant/Tests/InterviewAssistantTests/IntelligenceModelTests.swift
git commit -m "feat: parse scored interview evaluations"
```

### Task 2: Deeper Logic and Scoring Prompt

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/AnalysisPrompts.swift`
- Modify: `InterviewAssistant/Sources/InterviewAssistantCore/Intelligence/CodexCLIProvider.swift`
- Test: `InterviewAssistant/Tests/InterviewAssistantTests/AnalysisPromptTests.swift`

**Interfaces:**
- Consumes: `CompactInterviewEvaluation.normalize(_:)`
- Produces: a fixed eight-section scored interview evaluation prompt

- [ ] **Step 1: Write failing prompt tests**

Assert `AnalysisPrompts.evaluation` contains:

```swift
["## 结论", "## 综合评分", "## 分项评分", "## 逻辑分析",
 "## 总评", "## 优势", "## 劣势", "## 风险"]
```

Also assert it contains all five weights, the three recommendations, semantic question-answer reconstruction, the six logic checks, ASR-noise protection, insufficient-evidence cap, and job-irrelevant sensitive-information exclusions.

- [ ] **Step 2: Run tests and verify RED**

Run all tests. Expected: new prompt assertions fail because only the four legacy sections are requested.

- [ ] **Step 3: Implement the scored prompt**

Require this exact structure:

```markdown
## 结论
三档建议之一
置信度：高/中/低
理由：一句岗位相关理由

## 综合评分
数字/100

## 分项评分
- 逻辑表达：数字/25｜一句理由
- 岗位匹配：数字/20｜一句理由
- 专业能力：数字/20｜一句理由
- 成果证据：数字/20｜一句理由
- 风险一致性：数字/15｜一句理由

## 逻辑分析
- 最多三条“问题类型：具体表现和改进方向”
```

Tell the model to reconstruct questions and answers semantically, evaluate directness, structure, causality, specificity, consistency, and evidence across repeated answers, and never use protected or job-irrelevant traits. Keep the current concise limits for the four existing sections.

- [ ] **Step 4: Run tests and verify GREEN**

Run all tests and confirm the prompt contract passes without breaking resume evaluation.

- [ ] **Step 5: Commit**

```bash
git add InterviewAssistant/Sources/InterviewAssistantCore/Intelligence InterviewAssistant/Tests/InterviewAssistantTests/AnalysisPromptTests.swift
git commit -m "feat: generate scored logic-aware evaluations"
```

### Task 3: Scorecard Interface

**Files:**
- Modify: `InterviewAssistant/Sources/InterviewAssistantApp/MainView.swift`

**Interfaces:**
- Consumes: `InterviewEvaluationScorecard.parse(from:)`
- Produces: conclusion, total score, confidence, five dimension scores, and logic-analysis cards

- [ ] **Step 1: Render scorecard only for interview evaluations**

In `evaluationView`, parse a scorecard only when `evaluationTitle == "本次面试评价"`. Add:

```swift
if let scorecard {
    recommendationCard(scorecard)
    dimensionScores(scorecard.dimensions)
    evaluationSection(
        "逻辑分析",
        text: scorecard.logicFindings.map { "- \($0)" }
            .joined(separator: "\n"),
        color: .indigo
    )
}
```

Use green for `建议通过`, orange for `保留复核`, and red for `不建议通过`. Show total as `58/100` and confidence as `置信度：中`. Do not show empty scoring placeholders for legacy or resume evaluations.

- [ ] **Step 2: Build and run all tests**

Run:

```bash
cd InterviewAssistant
swift run InterviewAssistantTests
zsh Scripts/build-app.sh
```

Expected: all tests pass and the signed production app builds.

- [ ] **Step 3: Install and verify**

Replace `/Users/ben/Applications/面试助手.app`, verify its signature, open the app, and confirm a scored evaluation renders the new cards while existing resume evaluation remains unchanged.

- [ ] **Step 4: Commit**

```bash
git add InterviewAssistant/Sources/InterviewAssistantApp/MainView.swift
git commit -m "feat: display interview scores and recommendation"
```
