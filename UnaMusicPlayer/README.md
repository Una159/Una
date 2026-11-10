# Una — 原生 iOS 本地音乐播放器

Una 是使用 SwiftUI + AVFoundation 构建的原生 iOS 音乐播放器工程，采用深色液态玻璃视觉方向。

## 当前实现
- 本地音频文件导入（系统文件选择器，多选）
- MP3 / M4A / WAV / AIFF 等系统支持的音频格式
- 本地音乐库持久化（Documents/UnaMusic）
- 搜索歌曲、艺术家与专辑
- 播放 / 暂停、上一首 / 下一首、进度拖动
- 随机播放、循环模式
- 后台音频播放配置、锁屏和耳机远程控制基础接入
- 液态玻璃材质、动态渐变封面占位视觉

## 打开工程
1. 使用 macOS 上的 Xcode 打开 `Una.xcodeproj`。
2. 在 Signing & Capabilities 中选择你的 Apple Developer Team，必要时修改 Bundle Identifier（默认 `com.una.music`）。
3. 连接 iPhone 或选择 iOS Simulator，运行。
4. 真机测试后台播放、文件导入、锁屏控制与不同音频格式。

## 环境
- GitHub Actions 使用 macOS runner 与 Xcode 编译 iOS Simulator 目标
- 建议 Xcode 15 或更新版本
- iOS Deployment Target：17.0
- Swift 5

## 当前版本边界
这是可继续开发的原生工程起点，不应在未完成真机 QA 前直接提交 App Store。当前封面为程序生成的视觉占位；歌词同步、真正的均衡器、歌单编辑、专辑元数据封面、无障碍细节、崩溃与音频格式兼容性测试仍需补齐。
本应用不提供未经授权的在线音乐源，也不绕过 DRM。受 DRM 保护的 Apple Music 资源通常无法作为普通本地文件复制播放。
