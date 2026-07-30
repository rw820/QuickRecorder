# 面试助手 Logo 概念 V3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 生成 E、F、G、H 四张新的“面试助手”macOS 图标参考图。

**Architecture:** 使用内置 imagegen 为四个方向分别生成独立 PNG。每张图沿用统一深灰加蓝色规范，生成后检查尺寸、颜色、线条、文字和小尺寸辨识度。

**Tech Stack:** 内置 imagegen、PNG。

## Global Constraints

- 深灰背景，主体使用单一蓝色，最多加入少量白色。
- 使用细一些的连续平滑曲线、圆角和圆形端点。
- 不使用明显 3D、强阴影、光晕、文字、水印或复杂装饰。
- macOS 圆角方形构图，主体居中，留白充足。
- 本轮不替换软件现有图标。

---

### Task 1: 生成并检查四张参考图

**Files:**
- Reference: `docs/superpowers/specs/2026-07-29-app-logo-concepts-v3-design.md`
- Output: imagegen 默认目录中的四张正方形 PNG

**Interfaces:**
- Consumes: E、F、G、H 四个视觉方向
- Produces: 四张可直接比较的图标参考图

- [ ] **Step 1: 生成 E 倾听**

生成极简耳朵轮廓与一条对话弧线，保持图形简洁且小尺寸可辨识。

- [ ] **Step 2: 生成 F 问答**

生成两个圆润重叠的对话气泡与少量圆点，避免复杂细节。

- [ ] **Step 3: 生成 G 声音 M**

生成一条连续声波曲线隐约形成 M，避免直接使用排版字母。

- [ ] **Step 4: 生成 H 聚焦评价**

生成两个相对圆弧围绕中心圆点，保持对称和平衡。

- [ ] **Step 5: 检查和展示**

确认四张图片均为正方形、文件完整、无文字水印、颜色和线条符合 V3 规范，并在对话中按 E、F、G、H 展示。
