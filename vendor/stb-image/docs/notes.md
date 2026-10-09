# 使用说明与提示

> 从 README 提取的详细提示、约束与版本说明。

## 版本与安装

> [!NOTE]
> 包版本 `0.4.11`（mooncakes，要求 0.x.y 格式）对应功能迭代版本 `v5.3.0`。安装：`moon add walkzzz/image`。

## 格式检测

> [!NOTE]
> `detect_format` 仅通过 magic bytes 识别 PNG/JPEG/BMP/GIF/QOI/PNM/PSD/HDR/WebP。TIFF/ICO/CUR/ICNS/APNG/TGA 需手动调用 `decode_tiff`/`decode_ico`/`decode_cur`/`decode_icns`/`decode_apng` 等函数。

## 多目标测试

> [!NOTE]
> 四目标（native / wasm-gc / js / wasm）均使用同一套纯 MoonBit 代码，各 1203 测试全部通过，覆盖率 90.4%。

> [!TIP]
> 四目标共用 `src/pure/` 下的同一套代码，无任何条件编译或目标分支。

## 版本更新摘要

> [!TIP]
> **v4.10 最新更新** — 维度溢出安全守卫（`check_dims` + `MAX_IMAGE_DIMENSION`） · 全解码器入口校验 · `safe_mul`/`safe_mul3` 溢出保护 · 19 项安全测试 + 5 项大尺寸溢出测试 · 15 项高级算法基准测试 · 魔法数字清理

> [!TIP]
> **v4.9 诚实性修复** — 删除流式解码"零内存峰值"虚假声明 · 修正 WebP 格式表（解码仅 lossless） · 添加 `encode_webp_lossy` 不可解码警告 · 修正 reexport.mbt 虚假注释

## 安全约束

> [!WARNING]
> v4.10.0 引入维度安全守卫，所有解码器在分配内存前调用 `check_dims(width, height, channels)` 校验：
> - 宽/高必须为正数且不超过 `MAX_IMAGE_DIMENSION`（65535）
> - `width × height × channels` 不超过 `Int` 最大值（防整数溢出）
> - 校验失败时 `raise LoadError::DecodeFailed`
>
> `safe_mul` / `safe_mul3` 提供溢出安全乘法，返回 `Int?`（溢出时返回 `None`）。

## 核心约束

> [!WARNING]
> 以下约束不可违反，否则 PR 将被拒绝：

- **禁止引入 C FFI 依赖** — 所有代码必须纯 MoonBit 实现，确保四目标可用
- **禁止破坏已有 API** — 新增功能只添加不修改已有签名，保持向后兼容
- **禁止目标条件编译** — 不使用 `target == "native"` 等条件分支，四目标共用代码
- **新增 `pub` 函数须在 `reexport.mbt` 注册** — 保持顶层 API 完整性
- **新增解码器须调用 `check_dims` 校验** — 防止恶意图像导致 OOM 或整数溢出
