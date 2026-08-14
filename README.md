# AI 图片生成器

AI 图片生成器是一个 Flutter 应用，支持 Android、Windows 和 macOS。

## 平台支持

| 平台 | 架构 | 分发方式 | 状态 |
| --- | --- | --- | --- |
| Android | ARM/ARM64 | 官网服务器 APK | 当前支持 |
| Windows | x86-64（AMD64） | GitHub Releases | 当前支持 |
| Windows | ARM64（Windows on ARM） | GitHub Releases | 适配中 |
| macOS | ARM64（Apple Silicon） | GitHub Releases | 当前支持 |
| macOS | x86-64（Intel） | GitHub Releases | 当前支持 |
| Linux | 暂无 | 不提供下载 | 暂不开发 |

Android 保持本地 Flutter Release 构建，并通过官网服务器提供更新。Windows 和 macOS 使用 GitHub Actions 构建，正式下载入口统一使用 GitHub Releases。

## 开发环境

```powershell
flutter pub get
dart format lib
flutter analyze --no-fatal-infos
```

Android 本地 Release 构建：

```powershell
flutter build apk --release
```

Windows 和 macOS 正式构建必须通过 GitHub Actions，并使用 GitHub CLI 触发和查看：

```powershell
$env:HTTP_PROXY="http://127.0.0.1:7897"
$env:HTTPS_PROXY="http://127.0.0.1:7897"
gh workflow run build-desktop.yml --ref master
gh run list --workflow build-desktop.yml
gh run watch <run-id>
```

访问 VPS 时必须清空代理：

```powershell
$env:HTTP_PROXY=$null
$env:HTTPS_PROXY=$null
$env:ALL_PROXY=$null
```

## 目录说明

- `lib/`：Flutter 应用代码
- `android/`：Android 平台工程
- `windows/`：Windows 平台工程
- `macos/`：macOS 平台工程
- `.github/workflows/build-desktop.yml`：Windows/macOS GitHub Actions 构建
- `image-ai/`：官网、API 和更新服务
- `AGENTS.md`：构建、发布、代理和平台分发规则
