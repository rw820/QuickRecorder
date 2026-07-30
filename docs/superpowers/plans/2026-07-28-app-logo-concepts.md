# App Logo Concepts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 生成三张可供选择的“面试助手”macOS 图标参考图。

**Architecture:** 使用内置图像生成能力分别生成三种独立视觉方向。每张图使用同一构图标准，生成后检查主体、颜色、文字和小尺寸可辨识度，并直接在对话中展示。

**Tech Stack:** OpenAI 内置 imagegen

## Global Constraints

- 正方形 macOS 圆角方形图标。
- 不包含文字、字母、照片或水印。
- 本轮不修改应用资源。

---

### Task 1: 生成并检查三版图标

**Files:**
- Output: 内置 imagegen 默认预览目录

**Interfaces:**
- Consumes: `docs/superpowers/specs/2026-07-28-app-logo-concepts-design.md`
- Produces: 蓝色专业版、蓝紫 AI 版、橙红洞察版三张正方形参考图。

- [ ] **Step 1: 生成蓝色专业版**

使用对话气泡与对勾作为主体，蓝色系、稳重、简洁、无文字。

- [ ] **Step 2: 生成蓝紫 AI 版**

使用声波与四角星光作为主体，蓝紫渐变、科技感、无文字。

- [ ] **Step 3: 生成橙红洞察版**

使用抽象人物轮廓与聚焦框作为主体，橙红色系、醒目、无文字。

- [ ] **Step 4: 检查并展示**

确认三张图均为正方形、无文字和水印、主体居中清晰，然后按 A、B、C 展示给用户选择。
