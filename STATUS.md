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

## 0.1.1（build 2）：虚拟按键响应修复

用户反馈手机端虚拟按键卡顿、经常不响应；尚未收到具体游戏名或本次修复的真机结果。该反馈说明用户已在运行旧版，不能继续把整个项目描述为尚未上机，也不能据此推断所有游戏或功能通过验收。

代码检查发现：按键视觉缝隙也被当作触摸空白区，任意 layoutSubviews 都清空触摸，输入入队不唤醒 VM 的等待；另外画面复制和输入使用同一把锁，每帧重绘整个键盘。

本地修改：独立完整单元格命中区域和 6 pt 持键容错；仅几何尺寸、缩放或逻辑分辨率实际改变时重置布局；输入通知条件变量并允许等待提前返回；仅合并相邻画面拖动事件，不丢弃按键按下/松开；帧快照单独加锁，UIKit 非阻塞取帧；游戏画面和键帽只标记需要刷新的区域。未改上游代码或自动连发语义。

验证：找到本机 Visual Studio 18 / MSVC 14.51 工具链，使用 C++17 /W4 /WX 编译并运行 tests/controls_test.cpp，通过。覆盖横竖屏比例、按键缝隙、1000 次边缘抖动、滑动换键、多指共享按键和取消。命令及编译产物位于 build/test-controls.cmd、build/controls-test.exe；Apple/UIKit 编译和设备触摸行为仍需 Actions 及手机验证。修复源码包为 dist/fix-004-input-response.zip。

## 0.1.2（build 3）：具体游戏诊断、列表管理与图标

用户补充：内置演示无问题，其他游戏快速换键时会暂时不响应且不变绿；City Bloxx 菜单主要只响应软键。已只读检查 jars/ 中的 4 个游戏；这些文件不打包、不上传。

City Bloxx 1.0.8 的 p 类继承 Nokia FullCanvas，通过接口 m 调用 getGameAction。原核心只有静态 Canvas 入口，接口分派的实例查找失败。本地 Windows 宿主用原核心成功复现同样的 AbstractMethodError。cmake/CoreCompatibility.cmake 生成单文件兼容副本，补充实例入口且保留静态入口；iOS 和 CI 主机核心均使用此补丁。上游固定源码未改。

对照证据位于 build/city-baseline、build/city-fixed、build/city-quick-fixed、build/city-play-fixed。修复后未再出现 getGameAction 的 AbstractMethodError，截图确认可以下移到 Quick game、进入吊车场景、返回出现 Continue quick game 的菜单。30 秒回放尚不能证明楼块显示、完整玩法或持久化存档正确，仍有初始化时的 RecordStoreNotFoundException / 被处理的 NullPointerException；不把退出码 0 当作完整兼容证明。

进一步输入修复：游戏帧由独立 UIImageView 合成；输入队列使用独立短锁，日志和 AVAudioPlayer 音量调用不再占用该锁；同键的快速按下/松开跨输入批次交付，不把一对短按在同一批中全部吞掉；保持相邻拖动合并和所有按键边沿。增加 UI_TOUCH、INPUT、UI_MAIN 延迟统计供手机复核。

游戏管理：列表左滑或 ⓘ 入口，删除游戏/清空数据均确认后执行；内置演示只能清空 RMS。删除仅作用于对应 JAR、标题与 Saves/<id>；清空只删除对应 RMS。原有共享 Files 仍可被游戏访问且不会被删除，以免影响其他游戏。

图标：采用用户下载的 HelloClyde/BBK9588-J2ME assets/icons/j2me-coffee.png（512x512 透明图），合成为白底，生成 iPhone AppIcon 资源及 1024x1024 图，接入 Xcode 资源编译；绿色背景 source 图未采用。

本地通过：MSVC C++ 控件与输入队列测试；9 项 Canvas 接口/虚方法/静态方法键码查询实际 VM 测试；原核心演示两次启动和 RMS 回读；3 项 Python 图标/打包测试。Foundation 文件操作测试已加入 macOS CI，当前 Windows 不能运行。新 UIKit、图标打包和 0.1.2 真机效果仍待用户上传后验证。

## 0.1.3（build 4）：City Bloxx 计时与音频输出

用户反馈上一轮已上机：按键略有改善但未完全解决；City Bloxx 菜单已能操作，Build city 后仍卡住；声音有失真。Git 连接恢复，后续继续用 scripts/publish.ps1 的 Git 命令提交，不使用网页自动化。

本地先用原 0.1.2 核心复现 Build city 城市网格不动、FIRE/5 无法通过教程、右软键可返回。只在 build/host 生成调试核心，按帧读取游戏字段：House.cg 在数秒内停在约 164～212 ms，教程要求 cg-bX >= 600 ms；按键标志已正确进入游戏。游戏的 8 次循环平均毫秒增量因 Thread.yield 空操作导致高速循环而归零。原核心执行量约 99 M 字节码/秒，此指标是解释器工作量，不是设备 CPU 占用率。

cmake/CoreCompatibility.cmake 为 nj_lib_thread.c 生成第二个兼容副本，将 Thread.yield 改为 nj_thread_sleep(vm, th, 1)，只让当前 Java 线程协作暂停一个时钟单位，不睡眠整个宿主、不改游戏时钟。保留 Canvas 菜单补丁，上游源文件不改。先带字段探针验证 cg 每秒正常推进，再关闭探针，用干净存档重新回放：build/city-013-clean 的 1800 帧/30 秒截图确认教程出现、5/FIRE 可翻页、吊车运动、落块形成三层楼、人口 4 和结算，日志包含保存/继续路径。没有据此声称全部关卡或 iPhone 已验证。

音频：改为首批真实 PCM 到达后启动 AudioQueue，取消原先三段 1024 帧启动静音；缓冲按约 10 ms 分块，总待播容量约 120 ms（含设备中的帧），短尾按实际长度提交。首次启动前应用用户音量，简单提示音加 5 ms 淡入淡出。新增 AUDIO 最近一条 PCM 流统计及 MIDI 后端标记；empty_frames 包含自然结束时的空回调，不能单凭该数值认定丢音。核心 MIDI 仍为简化波形音源，不保证原手机音色，尚不能判定用户听到的失真是否全部解决。

本地已通过：控件/输入队列测试、五种采样率单/双声道 PCM 顺序与在途计数测试、提示音包络测试、实际 AudioOutput C++ 代码对本地 AudioQueue 替身的生命周期/短尾/首批启动测试、9 项 Canvas 实际 VM 查询、96 次实际 VM yield 时钟与恢复测试、演示按键/RMS、3 项 Python 图标/打包测试。AudioQueue 替身不模拟 Apple 音频驱动。新版本的 Xcode/UIKit/实际 AudioQueue 编译运行、真机快速换键、听感和后台恢复仍待用户上传及手机验证。

## 0.1.4（build 5）：真机日志检查与音频后续工作

用户提供 latest-session.log，并说明 City Bloxx 停在城市地图、右软键仍可返回；音频连续但有破音、杂音，乐器音色差异较大。原日志只读归档到 build/logs/user-audio-session-20261114.log。日志末尾 APP_VERSION=0.1.2 BUILD=3，因此不包含 0.1.3 的 yield/PCM 修复。

本次日志：INPUT max=16 ms、UI_TOUCH max=24.51 ms、UI_MAIN max_tick_gap=17.33 ms，未显示明显主线程长停顿；这是该次短会话的统计，不能否定其他游戏的快速换键问题。City Bloxx 约 146.69 M 字节码/秒，与已复现的 yield 空转现象一致。城市保存出现数组越界和空指针；不自动清空用户存档，也不据此认定硬件损坏或持久化后端故障。

修复：nj_run.c 因链接了 headless 符号，就用 headless 状态布局解释 iOS 的 port.ud，导致 observed 音频/文件数字无意义及不安全读取。cmake/CoreCompatibility.cmake 生成第三个兼容副本，只对明确 name=headless 的端口调用这些观察器。真实 VM stats 保留，iOS 音频继续使用 AudioOutput 自己的统计。port_stats_test.c 使用相同后端的 headless/custom 两个身份运行演示，验证通用统计保留、专有观察器仅适用于正确端口；本地 MSVC 实际核心测试通过，并加入 macOS CI。

音频分析：从用户 JAR 中提取的 20 个 MIDI 仅保存于 build/audio-analysis，分别用原波形合成器渲染至结束或约 60 秒。本地结果未观察到满幅 PCM 样本或所检查的两处混响反馈乘法溢出；不能据此排除 iPhone 输出路径问题或所有形式的听感失真。结果在 render-results.json。当前合成器使用简化波形，缺少采样音色库；调节输出缓冲无法还原真实乐器。拟先测试 TinySoundFont 与 GeneralUser GS SoftSynth 1.44；下载说明在 downloads/midi-audio/README.md。依赖尚未下载/接入，本版不宣称音源升级完成。0.1.4 的 Apple 编译及真机结果待验证。

## 0.1.5（build 6）：离线采样音源

用户已提供 TinySoundFont-main.zip 与 GeneralUser_GS_1.44-SoftSynth.zip。已读取并原样保留原始许可证，SF2 仅规范化文件名；源码/音色库/许可证及压缩包 SHA-256 写入 audio-dependencies.lock.json。只使用 TinySoundFont v0.9 合成器，未引入 TinyMidiLoader，继续使用固定核心的 MIDI 解析、事件队列和时间换算。

cmake/SoundFont.cmake 为 nj_midi.c 生成兼容副本，增加不透明采样流状态和合成分支；旧波形分支保留为加载失败回退。修复原 no-note 初始化失败路径对解析数组的重复释放。外层 SoundFontSynth.cpp 为各 MIDI 通道维护独立声部、共享只读样本，串行保护 TSF 的非原子共享计数。音符/鼓组、实时音量、表情、声像、弯音与范围、延音踏板、调制、CC91/93 发送保留；后两项由外部简易效果器实现，并非某款手机效果器的精确仿真。输出仍为核心约定的 22050 Hz，使用立体声、-9 dB 合成余量和软限幅；尾长沿用原核心，最终 5 ms 淡出防止截断跳变。

iOS 在 VM 工作线程加载 App 内置 SF2，后续会话复用样本缓存；播放流/通道共享样本，但控制器和效果状态独立。增加 SOUNDFONT 加载记录及每会话采样流数、回退数、软限幅样本、合成错误和活动流计数。CMake 将 SF2 和两个来源许可证打包；构建脚本在生成 IPA 前逐个校验 App 内的资源哈希，避免缺音色库却显示构建成功。发布脚本和源码打包脚本已包含 third_party 与音源哈希清单。

本地 Windows 实际核心测试通过：无音色库回退、立体声、定位/重启一致、速度/节奏、实时音量、乐器/鼓组区别、声像、弯音、延音踏板、longMidiEvent 原有轨道字节输入、效果输出、并存流隔离、无音符文件清理和流释放。20 个用户 MIDI 渲染均有非零输出、0 个满幅样本、0 个软限幅样本、0 个合成错误，最大幅值 27759/32768；完整结果在 build/audio-analysis/soundfont-results.json。仅本地生成对比音频，不上传用户游戏或提取内容。

City Bloxx 重新使用干净存档进行 1800 帧回放，build/city-015/contact.png 确认城市教程、吊车、落块、Tower height 3 / Population 7 结算；运行中打开 9 个采样流，0 回退、0 合成错误，退出后活动流为 0。该 headless 测试不模拟手机音频背压，不能把其 PCM 帧计数当作真实播放时长。初始化旧有缺存档异常仍由游戏处理，不据此声称所有存档/关卡兼容。

0.1.5 的 Apple/Xcode 构建、AudioQueue 真机听感、快速换键、横竖屏和后台恢复仍待用户用脚本上传并安装验证；本地没有生成或验收 IPA。
