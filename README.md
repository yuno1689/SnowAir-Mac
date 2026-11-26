# SnowAir Mac · P0 实现

macOS 原生截图与标注工具，对标 SnowAir Windows 版 P0 功能。
**目标系统：macOS 14.0+（Sonoma）** ｜ Swift 5.9 ｜ 无第三方依赖。

## 本期已实现（P0）

- 菜单栏常驻（无 Dock 图标）
- 全局热键 ⌥S 触发区域截图
- 全屏遮罩拖拽框选（Esc 取消）
- 7 种标注工具：矩形、椭圆、箭头、画笔、文字、序号、马赛克
- 颜色/线宽切换、Cmd+Z 撤销、清空
- 导出到剪贴板 + `~/Pictures/SnowAir/`（PNG）
- 设置中心（托盘行为、默认工具、剪贴板开关）
- 配置持久化 + 便携模式（App 同目录放空 `config.json`）

## 编译方式一：云 Mac（无需本地 Mac）

`SnowAir-Mac/.github/workflows/ci.yml` 已配置好 GitHub Actions 云 Mac 构建。
把本目录推到 GitHub 仓库（公开仓库 **免费不限量**），每次 push 自动在 Apple Silicon Mac 上跑：

1. Debug 编译（抓语法/API 错误）
2. 单元测试
3. Release 编译
4. 失败时自动上传完整日志（Actions 页面 → 本次运行 → Artifacts）

取编译错误：进 Actions 页点开失败的运行，日志直接可复制；点 Artifacts 下载完整日志。
把错误贴给我，我逐条修。**这一步能解决「代码一行没编译过」的问题，不需要你有 Mac。**

> 私有仓库注意：macOS runner 分钟数按 **10×** 扣（Free 档 2000 分钟 ≈ 200 真实分钟）。
> 建议用公开仓库，或只在关键节点手动触发（workflow_dispatch）。

> 云 Mac 的边界：能编译、能跑单元测试，但**不能做真机交互验证**
> （屏幕录制权限、热键触发、Retina 框选坐标、托盘行为）——这些仍需你在自己的 Mac 上做。

## 编译方式二：本地 Mac

```bash
cd SnowAir-Mac
swift build -c release
```

若要用 Xcode 图形化调试：
```bash
swift package generate-xcodeproj   # 若已移除该命令，直接用 Xcode 打开 Package.swift
```

> 注意：SPM 构建的可执行文件需要 `Info.plist`（已在 `Sources/SnowAirMac/Info.plist`）。
> 打包成 `.app` 时请将 plist 拷入 bundle 的 `Contents/Info.plist`，并做代码签名：
> `codesign --force --deep --sign - SnowAir.app`（ad-hoc，首次右键打开）。

## 首次运行必做

1. 系统设置 → 隐私与安全性 → 屏幕录制 → 勾选 SnowAir
2. 重启 App（macOS 不动态刷新已缓存的授权状态）

## 模块结构

```
Sources/
  SnowAirCore/         可单元测试的纯逻辑
    Models/Types.swift         三份冻结契约的 Swift 实现
    Annotation/ShapeRenderer   7 种图形绘制（含马赛克像素化）
    Annotation/ImageExporter   标注合成导出
    Capture/ScreenCapturer     ScreenCaptureKit 截图与裁剪
  SnowAirMac/          App 层
    App/                       入口、托盘、热键、权限、配置、导出
    UI/                        选区窗口、标注画布、工具栏、设置
Tests/SnowAirCoreTests/        契约不变量与渲染测试
```

## ⚠️ 需真机验证的项（本机 Windows 无法编译，未验证部分）

按优先级，编译后请重点验证：

1. **编译通过性**：`swift build` 全量编译（Carbon/CGFont/CoreText API 签名）。
2. **截图坐标**：Retina 屏下选区是否与实际像素一致（涉及 `ScreenCapturer.crop` 的 Y 翻转）。
3. **标注落点**：鼠标点击位置与图形绘制位置是否重合（`CanvasNSView.isFlipped` 与上下文坐标系）。
4. **马赛克方向**：马赛克块是否覆盖正确区域（左上原点坐标系）。
5. **热键生效**：⌥S 全局触发；与系统热键冲突时的行为。
6. **权限引导**：首次无屏幕录制权限时的系统设置跳转。

如发现问题，把编译错误或现象发我，直接改代码。

## 已知降级/未完成（P1 范围，本期不含）

- OCR、长截图、贴图、录屏（P1，规划文档第 4 节）
- 改键 UI（设置里显示默认值，暂不可改）
- GIF 编码（风险 R5，先出 MP4）
- 截图历史、AI、翻译、演示画布（P2）

## 许可

Apache-2.0，与上游一致。
