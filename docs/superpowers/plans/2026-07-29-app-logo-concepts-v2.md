# 面试助手 Logo 概念 V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 生成四张深灰加蓝色、线条圆润顺滑的“面试助手”macOS 图标参考图。

**Architecture:** 使用内置图像生成能力对 A、B、C、D 四个方向分别生成独立图片。生成后逐张检查颜色、构图、线条、文字和小尺寸辨识度，只展示符合统一标准的结果。

**Tech Stack:** 内置 imagegen、PNG。

## Global Constraints

- 深灰色背景，主体使用单一蓝色，最多加入少量白色。
- 不使用彩虹渐变、紫色、橙红色、星光或复杂装饰。
- 图形轮廓采用连续圆滑曲线，端点和转角全部圆润。
- 轻微层次感即可，避免厚重 3D、强阴影和高亮光晕。
- macOS 圆角方形构图，主体居中，留白充足。
- 不放文字、中文、完整单词或水印。
- 小尺寸下仍能识别。

---

### Task 1: 生成四版参考图

**Files:**
- Reference: `docs/superpowers/specs/2026-07-29-app-logo-concepts-v2-design.md`
- Output: imagegen 默认生成目录中的四张 PNG 参考图

**Interfaces:**
- Consumes: A、B、C、D 四个方向和统一视觉约束
- Produces: 四张独立的正方形 PNG 图标参考图

- [ ] **Step 1: 生成 A 对话声波**

使用 logo-brand 提示词生成圆润对话气泡与简化声波组合，限制为深灰、蓝和少量白色。

- [ ] **Step 2: 生成 B 双人交流**

使用 logo-brand 提示词生成两个极简人物轮廓和一条柔和连接弧线，限制为深灰、蓝和少量白色。

- [ ] **Step 3: 生成 C 文档洞察**

使用 logo-brand 提示词生成圆角文档轮廓与单条流畅波形，限制为深灰、蓝和少量白色。

- [ ] **Step 4: 生成 D 抽象 i**

使用 logo-brand 提示词生成由圆点和连续弧线构成的抽象小写 i，并隐约形成对话气泡。

- [ ] **Step 5: 逐张视觉检查**

检查每张图只有指定色系、没有文字或水印、主体居中、曲线连续、阴影克制；不符合要求时只针对问题项重做一次。

- [ ] **Step 6: 展示结果**

在对话中按 A、B、C、D 顺序展示四张图片，供用户选择，不修改应用资源。
