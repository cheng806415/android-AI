# AGENTS.md

## 强制发布与更新检查规则

以下规则为强制约束。任何一项未完成、校验失败或结果不明确时，必须停止发布，不得更新线上 `update-config.json`，不得向用户宣称发布成功。

### 1. APK 发布必须使用真实构建产物

1. 发布前必须先执行完整的 Release 构建，禁止复用旧 APK、未完成构建产物或仅凭文件存在判断构建成功。
2. 构建失败时禁止上传 APK、禁止更新 `update-config.json`、禁止修改线上 APK 指向。
3. 必须记录并核对以下信息：
   - 包名
   - versionName
   - versionCode
   - 文件大小
   - SHA-256
4. 包名、versionName 和 versionCode 必须来自 APK 实际元数据，不得只读取 `pubspec.yaml` 或 Gradle 配置后推断。
5. 本次代码改动需要重新发布时，必须确认版本号和 versionCode 符合版本规则；禁止使用相同 versionCode 覆盖不同代码内容，除非明确执行回滚且保留回滚记录。
6. 必须执行 Dart 格式化、`flutter analyze` 和 Release 构建。分析存在 error 或构建非 0 退出时，发布流程立即终止。

### 2. CMake、Gradle 和 NDK 构建故障处理

1. 遇到 `Access is denied`、`Permission denied`、CMake File API、`.cxx`、Ninja 或 NDK 锁定错误时，不得直接重复发布或跳过构建。
2. 必须先停止本项目残留的 `java`、`gradle`、`cmake`、`ninja`、`dart` 和 `flutter` 构建进程，再清理以下构建缓存：
   - `build/`
   - `.dart_tool/`（仅在依赖状态异常时清理）
   - `android/.cxx/`
   - `android/app/.cxx/`
   - `android/app/build/`
3. 清理后必须重新执行 `flutter pub get`，再重新构建 Release APK。
4. 如果仍然失败，必须保留完整构建日志，记录具体失败路径、进程占用和权限原因；未解决前禁止上传 APK。
5. 不得通过修改权限、关闭安全软件、删除用户无关文件或强制结束系统进程来规避问题。只能处理本项目相关目录和本项目构建进程。
6. 手工运行 CMake 成功不等于 Flutter/Gradle 构建成功，最终判定只能以完整 `flutter build apk --release` 的退出码和 APK 文件为准。

### 3. update-config.json 数据契约

1. `update-config.json` 必须是合法 UTF-8 JSON，线上和本地结构必须一致。
2. `latestVersion.apkSize` 允许服务器返回数字或字符串，但 App 模型必须兼容两种类型；修改配置或模型后必须使用真实 JSON 进行解析测试。
3. `latestVersion.apkSha256` 必须是 64 位小写十六进制字符串；禁止填写 MD5、临时值、旧 APK 哈希或人工猜测值。
4. `latestVersion.apkUrl` 必须指向实际线上 APK，不能指向 HTML 页面、重定向页面、临时目录、`/tmp` 或未被 Nginx 映射的目录。
5. 修改配置前必须先确认线上实际 Nginx 根目录和 APK 映射路径。当前正式目录为：
   - VPS 文件：`/var/www/update/apk/app-release.apk`
   - 公网地址：`http://103.236.70.249:8766/update/apk/app-release.apk`
   - 配置文件：`/var/www/update/update-config.json`
6. 更新配置前必须对 `apkUrl` 发起真实 HTTP 请求，并同时核对：
   - HTTP 状态为 `200`
   - Content-Type 为 `application/vnd.android.package-archive` 或 `application/octet-stream`
   - Content-Length 等于本地 APK 文件大小
   - 真实下载文件的 SHA-256 等于本地 APK SHA-256
7. 上述任何一项失败时，禁止写入新的 `apkUrl`、`apkSize` 或 `apkSha256`。
8. 写入后必须再次通过 HTTP 读取线上 `update-config.json`，核对 versionName、versionCode、apkUrl、apkSize、apkSha256 和 `pendingApk`。
9. 配置更新命令即使返回成功，也必须独立读取线上内容验证；不能仅根据 SCP 或 SSH 命令退出码判断成功。远程脚本中的引号转义失败时，必须视为校验失败并重新验证。

### 4. App 更新检查实现规则

1. 更新服务不得把所有异常压缩成单一的“检查失败”；必须保留每个候选地址的 URL、HTTP 状态码、Content-Type、响应大小、耗时、解析结果和失败原因。
2. 更新检查必须校验响应是否为合法 JSON object，并检查 `latestVersion`、`versionName`、`versionCode`、`apkUrl`、`apkSize` 和 `apkSha256` 的类型与内容。
3. 更新服务必须支持主地址和备用地址，并明确记录最终成功地址；不能只显示“点击重试”。
4. 设置页面必须提供详细诊断入口，用户可以查看实际访问网址和完整失败原因，但不得显示私钥、Cookie、密码或 Authorization 内容。
5. 修改更新服务、更新模型或线上 JSON 后，必须至少使用当前线上 `update-config.json` 做一次真实解析验证。
6. 更新检查修复版 APK 发布前，必须验证 1.4.0 或当前线上版本能够解析数字型 `apkSize`，并验证正常 JSON、HTTP 错误、HTML 响应和超时等失败场景。

## APK 发布流程

以后发布 APK 必须严格按以下顺序执行：

1. 检查版本号、版本规则、当前线上版本和 APK 实际发布目录。
2. 执行格式化、静态分析和完整 Release 构建；失败立即停止。
3. 校验 APK 实际包名、版本名、versionCode、文件大小和 SHA-256。
4. 使用 SSH 配置中的 `myvps` 连接 VPS，将 APK 上传到 VPS 的正式下载目录。
5. 在 VPS 上确认 APK 文件存在，并通过 HTTP 请求验证下载响应的 Content-Type、文件大小和 SHA-256。
6. 更新 VPS 上实际提供给 App 读取的 `update-config.json`，写入 `apkUrl`、`apkSize` 和 `apkSha256`。
7. 重新通过 HTTP 读取并校验线上 `update-config.json`。
8. 更新 VPS 上的网站下载页、版本信息和更新日志。
9. 如修改了 Nginx 或 PHP 配置，检查配置并 reload 相关服务。
10. 进行线上验证：更新配置、APK 下载地址、网站首页、提示词库接口和管理后台。

APK 正式下载地址必须使用 VPS 提供的稳定地址。写入 `apkUrl` 前必须发起真实 HTTP 请求，确认响应不是 HTML，Content-Type 为 `application/vnd.android.package-archive` 或 `application/octet-stream`，并核对下载文件的大小和 SHA-256；验证不通过时禁止更新 `apkUrl`。

禁止使用网页手动上传。禁止将密码、Cookie 或私钥内容写入文件或提交到版本库。上传和远程操作仅使用本机已有的 SSH 私钥，并遵循下方 `myvps` 配置。

## VPS SSH 连接规则

连接项目 VPS 时使用以下 SSH 配置：

```ssh
Host myvps
    HostName 103.236.70.249
    Port 20767
    User root
    IdentityFile ~/.ssh/id_rsa
```

仅使用本机已有的 SSH 私钥进行认证，不在项目文件、规则文件或命令中写入私钥内容。

## 跨平台构建与发布规则

1. GitHub Actions 是 Windows 和 macOS 构建的唯一正式构建入口，后续不得使用本机直接构建桌面安装包作为正式发布产物。
2. GitHub Actions 的触发、查看、等待、日志读取和构建产物下载必须使用 GitHub CLI；代理仅用于 GitHub 访问，PowerShell 访问 VPS 时必须清空 `HTTP_PROXY`、`HTTPS_PROXY` 和 `ALL_PROXY`。
3. Windows 必须提供以下目标：
   - x86-64（AMD64）
   - ARM64（Windows on ARM）
4. macOS 必须提供以下目标：
   - ARM64（Apple Silicon）
   - x86-64（Intel）
5. Android 保持本地 Flutter Release 构建，使用本规则前述的 APK 校验、SSH 上传、HTTP 完整性验证和线上配置独立验证流程；不得把 Android 正式更新改为 GitHub 下载。
6. Linux 当前不在开发计划内，不创建 Linux 构建任务，不在官网提供 Linux 下载链接；官网必须明确标注暂不开发。
7. Windows 和 macOS 正式下载入口统一指向 GitHub Releases，构建产物必须在 GitHub Actions 完成后再创建或更新对应 Release，不能把 Actions 临时产物作为长期下载地址。
8. 桌面版本发布前必须核对目标系统、CPU 架构、构建状态、产物名称、文件大小和 SHA-256；构建失败或架构不明确时禁止发布。
9. 官网平台下载区域必须根据访问系统突出对应入口：Android 指向服务器 APK，Windows 和 macOS 指向 GitHub Releases，Linux 显示暂不开发。
10. GitHub 访问代理配置为：
    ```powershell
    $env:HTTP_PROXY="http://127.0.0.1:7897"
    $env:HTTPS_PROXY="http://127.0.0.1:7897"
    ```
    访问 VPS 的 PowerShell 命令必须先执行：
    ```powershell
    $env:HTTP_PROXY=$null
    $env:HTTPS_PROXY=$null
    $env:ALL_PROXY=$null
    ```
