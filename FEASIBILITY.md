# iPhone 13 / iOS 15.5 移植初步评估

评估日期：2026-11-14。

## 结论与验证边界

可行，建议保留 nano_j2me C 核心，新增 iOS 平台适配和原生界面。先做不依赖 JIT 的版本，再以真机测试决定是否优化。没有 Mac 不妨碍使用 GitHub Actions 的 macOS runner 编译，但需要 iPhone 13 真机验证。

本次检查了公开仓库 README、核心移植文档、TrollStore 官方说明、GitHub runner 镜像清单和 Apple 工具链说明。尝试克隆源码时 GitHub 连接失败；没有完成完整源码审计、iOS 编译、安装或性能测试。此结论是文档与架构层面的初步评估，不是已验证的移植结果。

## 技术路线

- 锁定 ESP32 主工程及其实际引用的 nano_j2me 子模块版本，先保存兼容性基线。
- 使用 C 核心 + Objective-C/Objective-C++ 与 UIKit 外壳，新增 nj_port iOS 实现。
- 游戏 VM 独占工作线程；界面通过事件队列发送按键和控制命令；显示使用安全交接的帧缓冲。
- 首版关闭 JIT。上游记录 ARM64 后端尚未完成；TrollStore 也不意味着所有动态代码权限均可使用。
- 保留游戏原逻辑分辨率，显示层等比缩放；触控通过同一变换逆映射到游戏坐标。
- 原板级 LCD、FreeRTOS、SDMMC、NVS 和硬件音频后端分别替换为 iOS 显示、线程、沙盒文件、设置存储和音频实现。

## 功能与操作

建议保留：JAR 游戏列表，方向与 FIRE，完整数字键盘及 * / #，左右软键、CLEAR、A/B/C/D，多键同时按压、游戏指针事件，分辨率选项，最大尺寸/整数倍缩放，音量、FPS、设置持久化，RMS 与 FileConnection。

横屏采用左侧方向/动作区、中央游戏画面、右侧数字键盘；竖屏采用上方画面、下方操作区。保留完整键盘模式，另提供可选精简模式。布局遵守屏幕安全区域，提供方向锁定。旋转只重排界面，不重启 MIDlet、不强制改变游戏逻辑分辨率；旋转、切后台、触摸取消时释放按键。

串口上传改为“文件”导入 JAR；串口诊断改为应用内日志与导出。存档使用稳定游戏标识隔离，避免容器路径或文件名变化导致存档失联。原有存档迁移需要单独验证。

音频是主要工作项：PCM/WAV、音调先打通；MIDI 优先验证核心软件合成，SF2 再接便携合成实现；MP3/AAC/AMR 等逐种验证。不能直接沿用 ESP 专用二进制解码库，也不能假定系统后端自动覆盖所有旧游戏格式。中文字体尽量保持原来的字宽、基线与换行行为。

原板级适配未实现网络、蓝牙、相机和传感器，这些应视为后续扩展，不列为首版必需功能。

## 云端构建与安装

建议使用固定 macOS runner 和 Xcode 版本，构建 iphoneos arm64，最低系统设置 iOS 15.5。当前公开 macOS 15 镜像列有 Xcode 16.4；Apple 说明其部署目标覆盖 iOS 15。实施时再核实 runner 可用性。

构建关闭开发者证书签名，将真机 .app 放进 Payload 目录后压缩为 IPA，再上传 Actions artifact。必要时另做保留最小 entitlements 的 ad-hoc/fakesign 处理。这里“未签名”指不需要 Apple 开发者分发证书；安装时仍由 TrollStore 处理签名。

TrollStore 官方支持范围包含 iOS 15.5。是否已经安装 TrollStore 需在实施阶段确认。不要添加官方明确禁止的 iOS 15 / A12+ 动态代码 entitlement。首版解释器模式无需把 JIT 授权作为安装前提。

## 分阶段验收

1. CI 构建 arm64 IPA，手机安装并启动；运行演示 JAR。
2. 横竖屏、完整键盘、多点触控、缩放、中文、RMS、重启恢复通过。
3. 音频格式、MIDI、退出/后台/中断恢复逐项通过。
4. 用用户指定游戏验证菜单、实际关卡、存读档、持续游玩和较重的 3D 场景。

预期平台移植风险可控；不能在实测前承诺所有 JAR 兼容、特定 FPS 或音色完全一致。云端编译通过不能替代 iOS 15.5 真机测试。

## 工作目录约定

所有主动创建的本地源码、下载、笔记、临时资料、缓存、日志与产物均放在本项目目录 F:\软件\vibecoding\j2meforios 下。构建工具可配置的 TEMP/TMP 与缓存也应重定向至项目子目录。系统及工具不可避免的读取和系统自行产生的日志不承诺完全消除。GitHub Actions 使用云端 workspace，下载产物回存本目录。

## 参考资料

- https://github.com/lucinhu/esp32s31-korvo-nano-j2me
- https://github.com/lucinhu/nano_j2me
- https://github.com/lucinhu/nano_j2me/blob/main/docs/PORTING.md
- https://github.com/opa334/TrollStore
- https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md
- https://developer.apple.com/xcode/system-requirements
- https://support.apple.com/en-us/111872
