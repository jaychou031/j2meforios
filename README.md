# 掌上 J2ME · iPhone 13 / iOS 15.5

基于 nano_j2me 的原生 iOS 移植。当前为 **0.1 开发版，尚未通过 Apple 工具链编译及真机验收**。源码已实现基础路径；不能将此状态当作可安装、已验证的成品。

## 当前代码

- C99 核心，关闭 JIT，32 MiB Java 堆，默认 Nokia 6230 档案。
- UIKit 游戏列表、文件选择器导入 JAR、内置 Korvo 演示。
- 横竖屏自动布局、当前方向锁定、完整数字键盘、方向/FIRE、A/B/C/D、软键和 CLEAR。
- 多指按键引用计数、按下/松开事件、画面触控；旋转和切后台释放按键。
- 240×320、176×208、128×160、320×240；等比最大尺寸/物理像素整数倍缩放。
- 独立 VM 工作线程、帧缓冲快照、变动画面 FPS、设置持久化。
- AudioQueue PCM 输出、音调播放；保留核心的软件 MIDI、MP3、AMR-NB、WAV 等能力，实际音频效果待手机测试。
- 使用 JAR 内容 SHA-256 作为导入游戏的存档 ID，同内容重命名不影响存档。
- 正常退出经过上游 destroyApp；切后台暂停工作线程。系统强制杀进程不能保证调用游戏退出保存。
- 日志保留在“文件 → 我的 iPhone → 掌上 J2ME → latest-session.log”，列表设置可分享日志。

## 本地文件

```text
ios/                 iOS 界面、平台适配、音频、便携布局/按键逻辑
scripts/             源码验证、构建、打包、核心冒烟测试
tests/               布局/按键 C++ 测试、IPA 打包 Python 测试
.github/workflows/   GitHub Actions
upstream.lock.json   上游主项目及核心的固定提交
upstream/            手动下载的原工程（不上传到新仓库）
build/               所有本地构建和测试临时文件
dist/                产物
```

本项目所有主动生成的资料与产物留在 j2meforios 内。构建脚本将可配置临时目录放在 build/tmp。上游目录保持原样；CI 从固定提交下载主工程和核心子模块。

## 第一次 GitHub 构建

目标仓库：`jaychou031/j2meforios`。已确认远端 main 有初始化 README，不能直接在另一个独立 Git 历史上强制推送。

1. 在本目录打开你平时使用的 PowerShell，运行上传脚本。脚本在本项目的 build 子目录克隆现有仓库、复制移植文件并追加提交，保留远端历史，不使用 force push。

```powershell
Set-Location 'F:\软件\vibecoding\j2meforios'
powershell -ExecutionPolicy Bypass -File .\scripts\publish.ps1
```

`.gitignore` 已排除 upstream、下载目录、构建缓存、IPA 和 dist；不要用 `git add -f` 把整个上游复制进去。脚本使用你现有的 Git 登录和提交身份；如果缺少 user.name / user.email，请设置你自己的身份后重试。不会替你填写身份或修改全局 Git 配置。

2. 打开仓库 **Actions → Build iOS IPA** 查看自动构建；也可点 **Run workflow** 手动触发。
3. 全部检查成功后下载 **J2MEForIOS-unsigned-IPA** artifact，解压得到 `J2MEForIOS-unsigned.ipa`。**J2MEForIOS-build-logs** 仅包含诊断日志，不是安装包；构建失败时请提供其中的 `build-ios.log`。
4. 将 IPA 通过 TrollStore 安装。此构建不需要 Apple 开发者证书，没有申请 JIT 或私有权限。

流程固定 macos-15 / Xcode 16.4，部署目标 iOS 15.5。runner 若移除这个 Xcode 版本，需显式调整工作流，不能盲目换最新版本。构建输出检查 Mach-O 的 arm64、iOS 真机平台和最低系统，避免误打模拟器包。

如使用浏览器上传源码，可解压 `dist/j2meforios-source.zip` 后上传其中的文件和目录，务必包含隐藏的 `.github` 目录。不要把 ZIP 文件本身当作项目源码上传。

## 首轮手机验收

1. 启动内置演示：确认三条色带依次为红、绿、蓝，中文可见、黄色方块移动。
2. 按 FIRE 或 5，听是否发声；按方向、数字和软键，观察 Key 值变化。
3. 触摸画面：青色框应跟随触点；方向和数字键应能同时按住。
4. 旋转手机：游戏继续运行、画面不拉伸、按钮不被刘海/手势条遮挡；测试方向锁定。
5. 切后台再返回：声音和动画恢复、没有卡键。
6. 从菜单正常退出，再次进入演示：RMS boot 应增加；结束应用再启动再测试。
7. 导入自己的 JAR 测试实际关卡。失败时记录游戏文件名、所选分辨率、复现步骤，导出日志。

## 待后续验证与完善

- Xcode 编译、TrollStore 安装、实际屏幕布局、声音和性能：**待运行**。
- SF2 自定义音源、ESP 解码器覆盖的 AAC/AMR-WB/FLAC 等尚未移植；不能声称与原板级媒体功能完全等价。
- 中文首版使用核心字体，尚未接入原工程 FreeType 字体效果。
- 原生中文文本输入、更多按键布局、手柄、游戏元数据展示、旧设备存档导入尚未完成。
- 首版导入上限 64 MiB；升级为不同内容的 JAR 会产生新存档 ID，需要未来提供迁移入口。
- 网络、蓝牙、相机、传感器没有新增后端。
- 这是解释器版本，不含 ARM64 JIT。

上游核心许可证在其 `LICENSE` 中，随应用一起打包；内置演示源文件标明 MIT。第三方游戏不随应用分发。
