# TH15 iOS Build 5 验证记录

验证日期：2026-10-11。设备安装包：`TH15-iOS14-Native-b5.ipa`。

本次交付为 SDL3、UIKit、GLES3 原生应用，游戏使用工作区的日文 1.00b 资源与行为重建核心，原生设置页面为中文。沿用 TH10 的 Mac 工具链，并参考 TH06 实际布局代码实现竖屏顶部积分板和下方全屏战斗区域。

## 安装包检查

| 项目 | 结果 |
| --- | --- |
| Bundle ID / Build | `org.th15.native` / `5` |
| 设备架构 / 平台 | ARM64 / iphoneos |
| 最低系统 | Info.plist 与 Mach-O 均为 iOS 14.0 |
| 诊断自动操作 | 最终设备包关闭 |
| 签名 | ad-hoc 签名及严格校验通过；供 TrollStore 或自行重新签名 |
| 资源 | 36 个资源文件与清单逐项校验；18 首音乐、13 个字体、原版图标 |
| 压缩包 | ZIP CRC 检查通过；无 WebView/Wasm/Windows 运行时 |
| 传输校验 | Windows 下载副本与 Mac 原件清单一致 |
| 文件大小 | 177,004,183 字节 |

IPA SHA256：

```text
d672e9a1bd3f2c9efd36cc5d8b0529fb1eef288f443bf8fb2f5d65a84af921f6
```

程序 SHA256：

```text
1ea2caf4660d449af35b3df61ad8bceaaea9a5fbdd813b2a2410f95625ac9fe6
```

## 原生逻辑检查

`ios/tools/native_checks.sh` 的六组检查均通过，日志为 Mac `native-b4-checks.log`。Build 5 的后续修改仅涉及原生键盘焦点和设置关闭的时机；下列逻辑沿用已通过检查的代码：

- 触摸、手势与固定 60 Hz 逻辑时步。
- 摇杆死区、径向限制、出圈输入、低速与射击、菜单方向、抬起归中及恢复画面拖动。
- 后台、设置、音频中断等重叠暂停，以及通知顺序和停止状态。
- TH06 顶栏比例、小屏幕和刘海安全区、战斗区全宽全高、画面上下边界的触摸映射。
- 使用真实 PlayerMotion 检查普通拖拽每帧移动 4 个游戏单位、低速为 2 个单位；不限速拖拽立即到达 100 个单位的目标，并保持战斗边界限制。
- 作弊码识别、四角色 Extra/练习与全部音乐解锁；不改写现有高分；序列化后重新读取保存文件仍保持解锁。

## 游戏加载回归

基线模拟器运行同一游戏核心，第一位角色的第 1–7 关，以及其余三位角色的第 1 关，每项均运行至至少 300 个关卡逻辑帧。日志记录：

```text
REGRESSION PASS: seven stages and four characters each reached 300 frames
```

这是各关开局加载和四角色回归，不代表完整通关。原始日志保存在 `.local/reports/sim-baseline-regression.log`。

## UIKit 实际界面验证

环境：Intel Mac、Xcode 14、iPad mini 5 模拟器、iPadOS 16.0。下表列出实际完成并保存的成功结果：

| 测试 | 版本 / 结果 | 实际验证内容 |
| --- | --- | --- |
| `testControlsSettingsAndRotation` | Build 3、Build 4 / Success | 摇杆拖出边界并保持；修改死区至 0.40、修改灵敏度；设置生效；横屏 1024×768、竖屏 768×1024 切换；退出并重新打开后死区保存 |
| `testMenus` | Build 3 / Success | Replay、Player Data、Music Room、Manual 进入及 X 返回；Options 音量左右修改；Key Config 使用 S 分配并保存；开始游戏、模式、难度、角色选择与返回 |
| `testDeveloperDragAndUnlock` | Build 5 / Success | 拖拽限速和开发者开关生效、重启保存；DEV 面板无敌、一键最大化、清弹操作成功；分数 999,999,999、火力 400、残机/灵击各 8；无敌重启关闭；关闭开发者后隐藏 DEV；完整输入错码并显示错误，输入 `ymgjdsh` 显示成功；全部音乐与 Extra 标志生效；再次启动应用后仍解锁，进入 Extra 的难度与角色选择 |

摇杆运行日志记录出圈后仍捕获触摸：`Joystick captured outside: engaged=1`。触屏 Z/X/S 功能固定；原版 Key Config 修改手柄绑定，手柄连接与断开支持已实现。

竖屏稳定截图已人工核对：高分、分数、残机/碎片、灵击/碎片、Power、得点和擦弹均在顶部；完整战斗区域铺满下方，摇杆及 Z/X/S 悬浮。菜单使用原画面比例。

详细结果与截图位于 `.local/reports/ui-reports/`。Mac 保留 `ui-complete.xcresult`，可在 Xcode 中查看全部操作与截图。

Build 4 的作弊码界面检查曾失败，截图显示键盘焦点被 SDL 窗口抢走后只输入了首字符。Build 5 在原生设置显示期间隔离该窗口的键盘通知，并在设置完全关闭后恢复监听和游戏。修复后的测试先断言输入框完整收到 `wrong` 和 `ymgjdsh`，再确认错误提示、成功提示、记录保存和重启后 Extra 可用。Build 5 结果与截图位于 `.local/reports/ui-b5-reports/`；Mac 保留 `ui-b5-unlock.xcresult`。

新增功能通过后另行启动 Build 5 的触控/旋转及菜单基线回归，Mac 在测试期间再次重启，SSH 断开、模拟器关闭，未获得完整结果。该轮不计为通过，也不计为游戏功能失败；最后一次完整触控/旋转与菜单结果分别是上表的 Build 4 和 Build 3。中断日志保存在 Mac `ui-b5-baseline.log`。

## 验证范围

尚未连接 iOS 14 真机，未完成真机性能、实体 MFi/蓝牙手柄、长时间游玩和完整通关验收。关卡界面测试使用诊断保护保持角色存活，无敌检查覆盖开关状态与重启清除，不属于独立的碰撞伤害验收。最低版本设置及模拟器成功不能替代这些验证，也不能作为“所有设备完美运行”的保证。安装和操作方法见 `TH15-安装说明.txt`。
