# 状态记录

2026-11-14：收到并核对完整主仓库与核心子模块。主提交 cc13cce53cd1e4baa10600baf5a65b3568b44971，核心提交 c6c618ed3103df94dae8471abec3b1bd9eff7a47。

已编写 iOS 0.1 基础实现与 GitHub Actions 工作流；上游源文件未修改。

已在本地执行：
- 固定提交、核心接口文件、LICENSE 和演示 JAR 完整性检查：通过。
- Python 打包测试：2 项通过，涵盖 IPA 路径/权限、拒绝错误架构/模拟器、最低系统和旋转声明。
- 5 个 Python 脚本的语法检查：通过。

尚未执行：
- C++ 布局/多指按键测试（已加入 CI，本地没有 C++ 编译器）。
- Apple Clang / Xcode 真机应用编译（本地为 Windows）。
- 核心演示两次启动及 RMS 回归（已加入 CI）。
- TrollStore 安装与 iPhone 13 真机测试。

2026-11-14 16:02（北京时间）：已通过网页上传基础配置、iOS 实现、scripts、tests 和 Actions 工作流，保留初始化提交历史。工作流提交 4076aa76be85d45d564e3f4359dbacba03b465d5。

首次构建：Build iOS IPA #1，run ID 43573879354。最后观察到的状态为 In progress；尚未确认结果，也没有下载或验证真实 IPA。

用户明确要求后续所有网页操作由用户完成。后续只在本地准备修改、测试和上传包，等待用户提供构建结果/错误日志，不再自动操作网页。

下一步：用户查看 Actions 的首次结果。失败时提供失败步骤的完整日志或 build-ios.log；成功时下载产物，并进行 README 中的 TrollStore 安装和首轮手机验收。

本机 Git 远程连接曾被重置。scripts/publish.ps1 是可选的手动上传辅助：使用用户正常 PowerShell 的网络与已有 Git 登录，在本项目 build 子目录克隆后追加提交，不强制推送。

## 首次构建日志修复

用户提供的日志确认 Xcode 16.4 已开始编译 iOS arm64 核心，失败于 nj_port_headless.c:256 的 MAP_ANONYMOUS 未定义。日志中的 typedef 重复定义为警告，不是此次失败原因。

本地修复：根 CMakeLists.txt 为 nj2me 目标增加 _DARWIN_C_SOURCE=1；Actions 中独立 macOS 核心构建增加相同定义，避免后续冒烟测试遇到同一问题。JIT 仍关闭，上游源码未修改。

修复包：dist/fix-001-darwin-build.zip，仅包含 CMakeLists.txt 和 .github/workflows/ios.yml。需要用户上传后重新运行 Actions 验证；Windows 本地没有 Apple SDK，尚不能确认修复后的 iOS 编译结果。

## 第二次日志与 IPA 缺失修复

用户提供的第二次日志仍为 BUILD FAILED：NJSession.mm 引入 nj_libc.h 时，tolower/toupper 的语言链接声明与 Apple 系统头文件冲突。上游 nj_config.h 在设置 NJ_USE_LIBC 默认值前包含 nj_libc.h，导致首次包含时错误进入裸机声明分支。外层 CMake 为 nj2me 及使用方 PUBLIC 定义 NJ_USE_LIBC=1；独立 macOS 核心测试也明确使用同一定义。上游文件未修改。

此前工作流的日志管道未明确启用 pipefail，iOS 编译失败后仍执行了核心测试。现在显式使用 bash 和 set -euo pipefail，并检查 IPA 非空；安装包与日志分别上传，缺少 IPA 时不会以日志冒充成功产物。

用户粘贴的两次主机演示日志确认 DEMO_RMS_BOOT 从 1 变为 2、按键 53 的按下和释放、destroyApp 清理均执行成功。这证明该次 macOS 核心测试通过，不证明 iOS 编译或手机运行成功。

修复包：dist/fix-002-ios-libc-and-ci.zip。仍需用户上传后通过 Apple 云端编译，再进行 TrollStore 安装与真机验收。

## 第三次构建：CoreGraphics 链接修复

用户提供的日志确认 NJSession.mm、AudioOutput.mm、App.mm 已通过编译，核心静态库已生成。失败推进到最终 arm64 链接：7 个 CG 前缀符号未解析，包括 CGImageCreate、CGColorSpaceCreateDeviceRGB 和 CGContextSetInterpolationQuality。原因是外层 CMake 未显式链接 CoreGraphics；已补上该框架。statusBarOrientation 的弃用提示是警告，不是本次失败原因。

本次仍未生成 IPA。已归档日志至 build/logs/third-ios-build.txt，修复包为 dist/fix-003-coregraphics-link.zip，完整源码包同步更新。用户可直接再次运行 scripts/publish.ps1 上传最新文件；修复后的最终链接和 IPA 打包仍待 GitHub Actions 验证，本地 Windows 无 Apple SDK，不能代替云端验证。
