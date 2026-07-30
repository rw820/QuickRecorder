# 面试助手

这是一个独立的 Mac 本机面试工具。点击一次开始，会同时：

- 导入 PDF、Word、TXT 或图片简历并自动生成初评；
- 录制候选人的系统声音和面试官麦克风；
- 在本机实时转换成文字；
- 根据候选人的稳定回答生成追问建议；
- 停止后生成总评、优势、劣势和风险。

## 构建和运行

不需要安装完整 Xcode，使用 Command Line Tools 即可：

```bash
swift run --package-path InterviewAssistant InterviewAssistantTests
zsh InterviewAssistant/Scripts/build-app.sh
open InterviewAssistant/.build/app/面试助手.app
```

## 首次使用

首次点击“开始面试”时，请按系统提示授权：

- 屏幕与系统音频录制；
- 麦克风；
- 语音识别。

如果刚打开屏幕录制权限，请重新启动一次面试助手。

## 录音保存位置

每次面试会创建一个独立目录：

```text
~/Library/Application Support/InterviewAssistant/Sessions/
```

目录内包含：

- `system.caf`：会议软件、浏览器等系统声音；
- `microphone.caf`：本机麦克风声音；
- `transcript.jsonl` / `transcript.md`：实时逐字稿；
- `suggestions.jsonl`：面试过程中的追问建议；
- `evaluation-report.md`：总评、优势、劣势和风险。

简历读取、图片 OCR、录音和语音识别都在本机完成。只有提取后的简历文字和稳定
逐字稿会交给已登录的 Codex 生成建议和评价；原始简历和音频不会上传。Codex
不可用时仍会正常保存简历文字、录音和逐字稿。
