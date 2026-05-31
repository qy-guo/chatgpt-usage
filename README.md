# ChatGPT Usage Bar

一个面向个人使用的 macOS 菜单栏应用，用来集中查看多个 ChatGPT 账号的官方网页用量信息。

应用为每个账号维护独立的 WebKit 登录会话，在后台读取 Codex Usage Analytics 页面中可见的 5 小时和 1 周用量卡片，并补充显示订阅到期信息。

## 功能

- 管理多个 ChatGPT 账号档案。
- 为每个账号保存独立的 WebKit 登录会话。
- 手动刷新或按 `1`、`3`、`5`、`15` 分钟间隔自动刷新。
- 在 5 小时或 1 周额度重置后触发一次补充刷新。
- 拖动排序、账号置顶和当前账号标记。
- 明亮、黑暗和跟随系统三种主题。
- 打包为 `.app` 后支持设置开机自启。

## 环境

- macOS 14 或更高版本
- Swift 6.1 或兼容工具链

## 开发运行

```bash
swift run ChatGPTUsageBar
```

通过 Swift Package 运行时需要保留终端进程。正式使用可以打包为 `.app`：

```bash
Scripts/package-app.sh
```

生成位置：

```text
.build/release/ChatGPTUsageBar.app
```

## 验证

```bash
swift run ChatGPTUsageCoreCheck
swift build
Scripts/package-app.sh
```

## 本地数据

账号档案和应用设置保存在：

```text
~/Library/Application Support/ChatGPTUsageBar/
```

登录态由 macOS WebKit 数据存储维护。应用不会保存账号密码，也不会读取或复用浏览器 Cookie。

## 项目结构

```text
Sources/
  ChatGPTUsageCore/       可独立检查的账号、用量、刷新和设置逻辑
  ChatGPTUsageBar/        macOS 菜单栏应用、SwiftUI 界面和 WebKit 读取流程
  ChatGPTUsageCoreCheck/  核心逻辑回归检查
Resources/                macOS 应用 Info.plist
Scripts/                  本地 .app 打包脚本
docs/                     架构说明
```

更多实现信息见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## 设计边界

个人 ChatGPT 订阅目前没有供此场景稳定使用的公开用量 API。本应用读取官方网页中已经对当前登录账号可见的信息，因此网页结构变化可能需要同步适配解析逻辑。
