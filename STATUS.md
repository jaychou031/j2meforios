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

## 0.1.5 构建修复：保留音源依赖原始换行

用户的 Actions 停在 verify-audio.py，提示 third_party/TinySoundFont/tsf.h 哈希不符，尚未进入 iOS 编译。本地检查实际上传目录 build/publish-20261114-190609：Git core.autocrlf=true；tsf.h 原始文件含 2079 个 CRLF，提交对象变成 LF，SHA-256 从 70d55963... 变为 997092e4...；GeneralUser-LICENSE.txt 也被同样转换。SF2 本身和 TinySoundFont LICENSE 未损坏。不是依赖版本不一致，也不需要重新下载。

新增 .gitattributes，只为四个已锁定依赖设置 -text，保留原始字节；未修改全局 Git 配置、依赖内容或预期哈希。publish.ps1 纳入该文件，先校验本地 SHA-256，再按新属性重新暂存依赖，并比较每个暂存对象与原始文件的 Git 对象哈希；不一致就停止提交。源码包同步包含 .gitattributes。

新增 tests/test_git_audio.py，在项目 build/tmp 内创建隔离 Git 仓库，core.autocrlf=true 时先复现原错误，再应用属性并重新暂存，最后以 core.autocrlf=false 导出文件。四个暂存对象及导出文件均匹配原始 SHA-256。本地全部 6 项 Python 测试、PowerShell 语法及原始资源哈希检查通过。此次只修复提交/检验流程，App 版本仍为 0.1.5（build 6）；修复后的 Apple 云端构建仍待用户重新提交验证。

## 0.1.6（build 7）：后台恢复、输入诊断与省电

用户提供 latest-session(1).log（归档 build/logs/user-session-015-background-rally.log）：0.1.5/6 的 3D Rally 会话中，UI_TOUCH 平均 153.61 ms、最大 774.44 ms；INPUT 平均 10.34 ms、最大 47 ms；UI_MAIN 最长间隔 33.72 ms。主要等待发生在 UIKit 交付触摸前，不能将其归因于 VM 持续占用主线程。新增游戏屏幕边缘手势延后请求、导航容器转发，并仅在游戏显示期间禁用交互返回手势，离开时恢复；补充左右/底部边缘触摸统计。此推断仍待手机交叉验证。

原后台逻辑将 VM 恢复绑定在音频中断结束标志上；Apple 官方文档明确中断开始不保证有对应结束通知。现将前台/菜单/停止门控与音频可用状态分开，前台主动尝试激活音频；音频激活失败不将 VM 永久留在等待中。菜单暂停仍需用户继续，暂停期间游戏时钟冻结并扣除停留时间，恢复不让游戏时间跨越后台时长。提示音仅在原本正在播放时恢复，避免重播早已结束的声音。

日志末尾的 AudioQueue -66632 与销毁期间重新入队路径吻合。AudioOutput 在 Dispose 前先失效队列，回调检查队列身份后才读缓冲/入队；所有等待回调的队列控制操作均放在回调互斥锁之外。空缓冲不再反复入队静音数据；无待播样本时 VM 线程暂停队列，新 PCM 到达才继续。保留真实短尾长度与样本顺序；增加每条流 PCM_CLOSE 和有后续供数的 gaps/gap_silence_frames，避免用自然结束后的空回调断言杂音。

用户同时要求省电优化：暂停游戏时停用 CADisplayLink，关闭 FPS 显示时不重复更新标题；游戏列表设置新增 30 FPS 省电模式（下次启动生效），VM 帧上限和显示刷新同步限制为 30。系统低电量模式也采用 30；普通模式保留 60。没有实机功耗数据，不承诺节电百分比，30 FPS 的流畅度折中需用户选择。

用户日志退出后仍有 2 个采样流：为每个 VM 工作线程登记其采样流，在 nj_run 完成后释放游戏未关闭的资源。保留共享只读音色库缓存；跨线程隔离清理测试验证不会释放另一线程的活动流。

“笃笃”声尚无法确认是乐器或音频路径异常，用户也暂不能判断。已从用户 City Bloxx 与轩辕剑 MIDI 制作完整/去鼓组/仅鼓组的 12 秒本地对比 WAV，保存在 build/audio-diagnostics-016；直接由合成器输出，不经过 iPhone AudioQueue。正式 App 未静音鼓组、未改游戏资源；用户素材不上传。需用户对比或提供录音，并结合新版供数间隙日志继续定位。

本地验证：生命周期门控/暂停时钟测试；实际 AudioOutput 对可重入 Dispose 回调的替身测试（样本顺序、无静音空转、短尾、空闲重启、暂停/恢复）；真实核心 SF2 回归和跨线程资源清理；3D Rally 约 20 秒回放进入赛道、汽车行驶并返回菜单（build/rally-016/contact.png），7 个采样流，退出活动流 0。该回放没有 UIKit，不能证明手机按键已修复。Xcode 编译、真实中断/后台恢复、触摸延迟、听感和耗电仍待本次云端与手机验证。

## 0.1.7（build 8）：实测代码效率优化与音频缺口诊断

用户确认轩辕剑完整参考 WAV 在 iPhone 上无杂音，并提供 0.1.6（7）日志与 31.858 秒 M4A。原件复制保存在 build/audio-diagnostics-017。日志中 gaps=0、last_error=0、saturated_samples=0、合成错误/回退/退出残留流均为 0；不能单凭这些计数排除实际音频链路异常。

用 Windows 自带 Media Foundation 解码录音（没有下载依赖），与游戏 midi/0.mid 完整渲染做频谱及波形对齐：匹配偏移约 4.79 秒，每秒片段波形相关度约 0.97–0.99，未观察到明显累计时间漂移。对齐后的波形有短暂近静音缺口及边缘突变，许多相邻间隔约 70 ms。证据在 analysis.json、alignment.json、difference.png、spike-detail.png；这是录音中的现象，不足以单独区分合成、AudioQueue/系统转换及录制编码环节，尚不宣称根因已确定或杂音已修复。

代码效率改动均默认在 60 FPS 下生效：

- CoreEfficiency.cmake 生成 nj_lib_midlet.c 的外层帧间等待兼容副本。IdlePacer.h 检查真实 Java 线程状态；没有可执行任务时，宿主条件变量等待到最近线程/计时器或帧截止时间。可执行线程用已有 scheduler_frame 分片继续运行。空栈主线程与属于嵌套 C 调用的线程不被误判为可执行工作。没有更改 Thread.yield 的既有 1 ms 兼容补丁、游戏时钟倍率或帧率上限。
- FrameMailbox.hpp 用三块可复用像素内存发布不可变图像，CGDataProvider 保持引用直至 UIKit 释放，去掉 NSData 的第二次全帧拷贝，并复用颜色空间。UI 无新帧时暂停 CADisplayLink，新帧通过一次主线程通知唤醒；开启 FPS 数字显示时保留刷新。真实样本仍待 UIKit 验收。
- PcmBuffer.hpp 将逐帧取模/短 memcpy 改为最多两次连续块拷贝，保留样本顺序、背压、在途计数与满幅统计。
- SoundFontSynth.cpp 不处理没有活动声部的声道；低频检查尾音是否结束，跳过零调制的三角函数、从未开启的混响/合唱计算。已开启的效果尾音仍处理。轩辕剑 9 个 MIDI 前后输出 WAV 的 SHA-256 全部一致，未删除乐器、改变音量或降低采样率。

Windows/MSVC 同一演示、60 FPS 上限、300 帧、三次测量：旧版进程 CPU 中位数 4.859 秒，新版 0.078 秒；两者实际运行时间均约 5.05 秒，帧率接近 60。这个轻负载案例确认帧等待空转被移除，不是整机耗电或复杂游戏性能承诺。PCM 204800000 帧读写微基准约 1059 ms → 171 ms；9 段合成总耗时中位数之和约减少 4%，各曲目收益不同、其中主题曲近乎不变。最终数据见 benchmark.json；benchmark-initial/stale-library 文件是调试阶段资料，不用作结论。

AudioQueue 在 22050 Hz 下将 220 帧块改为 1024 帧块，减少回调、加锁与短块交接；保留 120 ms 软件队列容量，短音效仍按实际长度入队。新增 callbacks/short_buffers/starts/block_frames 统计。该输出调整是需真机对照的候选修复。Apple 文档说明缓冲复用回调并不代表声音已实际播放；原 played/empty/gaps 统计不能被当作硬件输出连续性的证明。

增加可选的一次性 PCM 诊断：设置中开启后，仅下一个游戏在内存保存最后打开的 PCM 流前 30 秒，退出后写 latest-session-pcm.wav；导出日志时附带该文件。音频回调不写盘，正常游戏默认不开启；文件位于游戏内音量处理之后、AudioQueue/App 音量之前。用于把实际流式生成的 PCM 与手机录音对比。

新增 PERF CPU/时长/等待计数与 DISPLAY 发布/消费/重复/拷贝字节计数。旧“省电模式”更名为明确的可选“帧率上限”，保留用户选择，取消系统低电量自动降至 30 FPS；代码效率优化始终生效。

本地通过：控件、输入、PCM、生命周期、实际 AudioOutput 替身、并发帧池、WAV 捕获、真实核心 idle pacer、SoundFont 回归、6 项 Python 检查、Canvas 9 查询、两条调度路径的 yield 时钟/恢复、演示按键与 RMS。iOS 分支下 City Bloxx 回放 1800 帧/30 秒保持 60 FPS，截图确认吊车移动、落块、叠层与 combo 提示；轩辕剑启动至标题菜单。初始缺存档异常由游戏处理，不代表所有存档/关卡兼容。Apple SDK 编译、实际音频输出与真机耗电仍待本次 CI/手机验证。

3D Rally 在 iOS 调度分支下用显式按住/松开脚本回放 1200 帧，进入赛道，截图显示 41/60/45 km/h 与转向；6 个 SF2 流、0 回退/合成错误、退出后活动流 0。证据：build/audio-diagnostics-017/rally-held/contact.png。单帧极短点击脚本在菜单可能被轮询式游戏漏读，不能作为 UIKit 触摸延迟的测量；本次没有额外延长用户按键或改动输入时序。

## 0.1.8（build 9）：游戏页面隔离侧滑返回

用户真机反馈 0.1.7 的杂音已消失或微小到听不出，3D Rally 按键不再卡顿，功耗已降到可接受范围。本版保持音频、VM、渲染与输入实现不变。

新问题来自越狱后的右边缘左滑返回插件：截图中游戏被横向移出，露出 JAR 列表，同时游戏声音继续。旧代码已禁用 UIKit 的 interactivePopGestureRecognizer，但游戏仍是列表导航栈上的子页面；额外的返回手势可以绕过这一开关。插件的具体实现未知，此处依据截图及现有页面结构做修复，不声称已检查插件源码。

App.mm 改为从列表呈现独立的 UIModalPresentationFullScreen 游戏页面，不再 push 到列表的 UINavigationController；modalInPresentation 阻止普通交互关闭，并拦截游戏运行中直接发送给游戏控制器的 dismiss 请求（关闭其菜单弹窗仍允许）。保留横竖屏、方向锁定、状态栏隐藏和屏幕边缘系统手势延后请求。没有添加抢占触摸的全屏识别器，也没有全局关闭其他页面的手势。进入游戏使用无动画呈现，避免短时启动失败与入场动画竞争。

正常出口仍是“菜单 → 结束并返回游戏列表”，先通知工作线程停止、释放按键并暂停显示，再等待 NJSession 完成 destroyApp/音频回收后关闭游戏。返回前等待尚未结束的菜单/页面转场，避免快速退出与弹窗自动关闭竞争。停止期间的前后台通知不会重新暂停正在清理的工作线程。

若外部代码绕过关闭保护，viewDidDisappear 在检测到真正被移除时请求停止；菜单遮挡、后台暂停及取消的交互返回不作为移除。列表持有活动游戏直至清理完成，在此期间禁止启动另一游戏、导入或管理数据；回调清理持有关系并恢复列表。日志新增 UI_EXIT unexpected_detach，便于区分正常退出与外部移除。兜底是停止隐藏会话，不承诺能禁止任意越狱代码直接修改 UIKit 内部视图。

本地验证：MSVC 生命周期/暂停时钟、实际 AudioOutput 替身、控件输入/布局回归通过。Apple UIKit 编译和插件手势不能在 Windows 上验证；需要 Actions 构建本版，再在带插件的 iPhone 上检查以下行为：

1. 竖屏及横屏游戏中分别从右边缘向左滑、从左边缘向右滑；游戏应保持全屏，按键与画面触摸继续响应。
2. 打开菜单后继续游戏、锁定/解除方向；切后台再回来；均不能意外退出。
3. 菜单结束游戏、游戏自行退出、JAR 启动失败均能回到可操作的列表，没有残留声音；随后能再打开游戏。
4. 列表原有左滑删除/清空数据、导入和设置继续可用。若插件仍能强行关闭页面，确认声音停止，并提供本版日志的 UI_EXIT 行和插件名称以进一步定位。
