# 安装选定应用图标 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 V3 第三个“声音 M”图标设置为“面试助手”的正式 macOS 应用图标。

**Architecture:** 保存选定 PNG 源图，使用 macOS `sips` 和 `iconutil` 生成标准多尺寸 `AppIcon.icns`。`Info.plist` 声明图标文件，构建脚本把 `.icns` 复制到应用资源目录后再签名。

**Tech Stack:** PNG、ICNS、sips、iconutil、zsh、Swift 测试。

## Global Constraints

- 使用 V3 第三个“声音 M”图标。
- 保持现有应用签名身份和权限不变。
- 图标必须包含 16、32、128、256、512 和 1024 像素资源。
- 安装到 `/Users/ben/Applications/面试助手.app` 并重新打开。

---

### Task 1: 增加图标配置测试

**Files:**
- Modify: `InterviewAssistant/Tests/InterviewAssistantTests/DisplayNameTests.swift`

**Interfaces:**
- Consumes: `InterviewAssistant/Resources/Info.plist`
- Produces: 对 `CFBundleIconFile` 和 `AppIcon.icns` 存在性的回归检查

- [ ] **Step 1: 写失败测试**

从 `#filePath` 定位 `InterviewAssistant/Resources`，断言 `Info.plist` 的 `CFBundleIconFile` 为 `AppIcon`，并断言 `AppIcon.icns` 存在。

- [ ] **Step 2: 运行测试确认失败**

Run: `swift run --package-path InterviewAssistant InterviewAssistantTests`

Expected: 图标声明或资源不存在，测试失败。

### Task 2: 生成并接入图标资源

**Files:**
- Create: `InterviewAssistant/Resources/AppIconSource.png`
- Create: `InterviewAssistant/Resources/AppIcon.icns`
- Modify: `InterviewAssistant/Resources/Info.plist`
- Modify: `InterviewAssistant/Scripts/build-app.sh`

**Interfaces:**
- Consumes: `/Users/ben/.codex/generated_images/019f91ee-5953-75a2-a401-18cc399c8e2f/call_IjJ3Cx3voqIJi7xTAPUG84Nc.png`
- Produces: `AppIcon.icns` 和带图标的应用包

- [ ] **Step 1: 保存源图**

把选定 PNG 复制为 `InterviewAssistant/Resources/AppIconSource.png`，保留原始生成文件。

- [ ] **Step 2: 生成多尺寸 ICNS**

在临时 `.iconset` 中使用 `sips` 生成 16、32、128、256、512 和 1024 像素 PNG，再用 `iconutil -c icns` 生成 `InterviewAssistant/Resources/AppIcon.icns`。

- [ ] **Step 3: 配置 Info.plist**

增加：

```xml
<key>CFBundleIconFile</key>
<string>AppIcon</string>
```

- [ ] **Step 4: 配置构建脚本**

在签名前复制 `${project_dir}/Resources/AppIcon.icns` 到 `${contents_dir}/Resources/AppIcon.icns`。

- [ ] **Step 5: 运行全部测试**

Run: `swift run --package-path InterviewAssistant InterviewAssistantTests`

Expected: 全部测试通过。

- [ ] **Step 6: 提交代码**

```bash
git add InterviewAssistant/Resources InterviewAssistant/Scripts/build-app.sh InterviewAssistant/Tests/InterviewAssistantTests/DisplayNameTests.swift
git commit -m "feat: install interview assistant app icon"
```

### Task 3: 构建、安装和验证

**Files:**
- No source changes expected.

**Interfaces:**
- Consumes: 已签名的应用构建产物
- Produces: `/Users/ben/Applications/面试助手.app`

- [ ] **Step 1: 构建应用**

Run: `zsh InterviewAssistant/Scripts/build-app.sh`

Expected: 构建和签名验证通过。

- [ ] **Step 2: 安装并打开**

退出旧应用，用 `ditto` 替换安装包，再重新打开。

- [ ] **Step 3: 验证图标**

使用 `PlistBuddy` 检查安装包的 `CFBundleIconFile`，检查 `AppIcon.icns` 存在、代码签名有效且应用进程已运行。
