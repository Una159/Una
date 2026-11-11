# 网易云音乐宿主研究与 NaiWa 映射

> 本文记录对用户提供的 `NaiWa.dylib` 的静态分析，以及公开 iOS 网易云插件项目的交叉验证。参考仓库只用于识别宿主类、selector、注入方式和版本兼容风险；不将旧插件的业务实现直接冒充 NaiWa 原始逻辑。

## 已确认的宿主身份

从 NaiWa 二进制字符串中直接提取：

- Bundle ID：`com.netease.cloudmusic`
- 主程序：`neteasemusic`
- URL scheme：`orpheus`
- 宿主类包含 `NMApplication`、`NMAppDelegate`、`NMTabBarController`、`NMMainViewController`、`NMSettingTabViewController`、`NMSearchTabViewController`、`NMCommentV2ViewController`、`NMPrivateMessageViewController` 等。
- 这是一套较新的原生 + React Native 混合页面结构；不能直接套用 2017/2018 年客户端的类布局。

## NaiWa 中可确认的宿主类清单

### 应用与导航
`NMApplication`, `NMAppDelegate`, `NMMainViewController`, `NMTabBarController`, `NMTabBar`, `NMNavigationBar`, `NMNavigator`, `NMHomeTabbarView`, `NMHomeTabbarItemView`, `NMScrollableTabView`, `NMScrollableTabViewNormalStyleTab`, `NMSettingTabViewController`, `NMSubSettingViewController`

### 搜索与首页
`NMSearch`, `NMSearchViewController`, `NMSearchTabViewController`, `NMNewSearchResultContainerViewController`, `NMSearchHistory`, `NMHomeNavSearchView`, `NMNavigationSearchBarView`, `NMHomeSearchBarRightItemView`, `NMSearchBarRightItemView`, `NMRcmdHomeViewController`, `NMCombineHomeViewController`

### 播放与媒体
`NMTabBarPlayingMedia`, `NMTabBarPlayingMediaBackground`, `NMPlayingListViewController`, `NMPlayViewNavTitleView`, `NMPlayViewNavTitleContentView`, `NMPlayListOperationView`, `NMAlbumView`, `NMPlaylistViewController`

### 广告
`NMSplashAdView`, `NMAdBannerView`, `NMAdvertisementView`, `NMCommercialAdView`, `NMLaunchAdViewController`, `NMLaunchAdImageView`, `NMLaunchAdVideoView`, `NMLaunchAdHorizontalImageView`

### 评论、消息与输入
`NMCommentV2ViewController`, `NMResourceCommentCollectionViewController`, `NMGlobalInputView`, `NMGrowingInputView`, `NMGlobalInputViewTextView`, `NMCommentInputTopicsView`, `NMChatBubbleView`, `NMChatBaseMessageView`, `NMPrivateMessageViewController`, `NMPrivateMessageNewDetailViewController`, `NMMessageListViewController`, `NMSessionListViewController`

## 公开项目交叉参考

### 1. sunweiliang/NeteaseMusicCrack
- 地址：https://github.com/sunweiliang/NeteaseMusicCrack
- Objective-C / MonkeyDev 项目，仓库标注 MIT License。
- 旧版本源码展示了 `NMSong`、`NMSongUrlInfo`、`NMAppDelegate`、`NMAdBackgroundView`、`NMPlayViewController` 等类及其 Hook 注册方式。
- 其 README 所述测试客户端是旧版；不能据此断定这些 selector 在当前网易云版本仍存在。
- 对 NaiWa 最有价值的部分是类命名体系和 Hook 初始化模式，不是照搬旧版业务逻辑。

### 2. ITJesse/NeteaseMusicPlugin-iOS
- 地址：https://github.com/ITJesse/NeteaseMusicPlugin-iOS
- GPL-3.0，README 标注测试于网易云 4.1.0。
- 公开源码识别了 `NMHttpRequest`、`NMAppDelegate`、`NMAdBackgroundView`、`NMMVAdBannerView`、`CloudMusicCoSDK`。
- 该项目通过请求解析层识别失效歌曲请求并转发到 UnblockNeteaseMusic 服务，属于网络请求处理方向，与 NaiWa 的 UI/玻璃效果/设置/底栏主体不是同一个功能集合。
- GPL-3.0 代码不直接复制进本项目；这里只记录公开的宿主类和技术路线。

### 3. MonkeyDev
- 地址：https://github.com/AloneMonkey/MonkeyDev
- 用于确认 MonkeyApp 注入、Logos/CaptainHook、导出宿主 Objective-C headers 和调试方法的工程流程。
- 实际 Hook 必须以当前宿主二进制导出的类/selector/签名为准。

## NaiWa 功能与宿主区域的初步映射

| NaiWa 功能域 | 二进制中可见的宿主对象/区域 | 当前结论 |
|---|---|---|
| 原生设置页玻璃 | `NMSettingTabViewController`, `NMSubSettingViewController`, `NMSettingBarButtonItemView` | 类名已确认，具体 hook selector 需继续从 ObjC 元数据/调用点恢复 |
| 底部 Dock | `NMTabBarController`, `NMTabBar`, `NMHomeTabbarView`, `NMHomeTabbarItemView` | 与 NaiWa.SystemDock 的关联强；需确认原始 tab bar 的创建/布局/点击转发 |
| 首页顶部标签 | `NMHomeTabbarView`, `NMScrollableTabView`, `NMScrollableTabViewNormalStyleTab` | 候选目标，尚未确认每个 hook |
| 搜索玻璃/搜索增强 | `NMSearchTabViewController`, `NMSearchViewController`, `NMHomeNavSearchView`, `NMNavigationSearchBarView` | 宿主类明确，搜索历史/建议/榜单的处理路径需继续追踪 |
| 评论输入与气泡 | `NMCommentV2ViewController`, `NMGlobalInputView`, `NMGrowingInputView`, `NMChatBubbleView` | 候选目标；需要区分评论输入、私信输入和聊天气泡 |
| 侧边栏/我的页面 | `NMMineTabRCTViewController`, `NMMLogRNTabContainerViewController`, `NMCurrentUser` | 原生/RN 混合区域；不能只靠 UIView 层级做全局替换 |
| 广告/开屏 | `NMSplashAdView`, `NMAdBannerView`, `NMAdvertisementView`, `NMCommercialAdView` | 类名已确认；是否执行隐藏需受用户设置控制 |
| 播放器/迷你播放条 | `NMTabBarPlayingMedia`, `NMTabBarPlayingMediaBackground`, `NMPlayingListViewController` | 玻璃视觉目标明确，具体生命周期仍待验证 |

## 下一步逆向工作顺序

1. 从 Mach-O 的 `__objc_classlist`、`__objc_classname`、`__objc_methlist`、`__objc_const` 解析 class_ro_t / method_list_t，恢复 NaiWa 自身类的 selector 与 IMP。
2. 解析 NaiWa 的 Hook 注册表，关联目标类名、selector、原始 IMP、replacement IMP；不要仅凭字符串同现推断调用关系。
3. 对照当前宿主类名，逐项确认真实方法是否存在、类型编码是否一致。
4. 先实现可逆 Hook 和诊断日志，再按设置开关接入 UI 功能。
5. 对每个功能记录：二进制证据、源码实现、编译状态、运行时验证状态。

## 重要边界

- 目前已从二进制确认目标 Bundle ID、宿主类名和多个功能标识；尚未恢复完整的 Hook 调用图。
- 旧项目的网易云 4.x selector 不能视为当前版本兼容依据。
- NaiWa 中的授权/设备签名逻辑属于合法授权验证范围；重建时不绕过授权或伪造授权响应。
- 不会将尚未编译或未在设备验证的功能标记为已完成。
