# mooncakes.io image 库对比

对比 mooncakes.io 上已有的 image 相关 MoonBit 包与本库 `walkzzz/image` 的功能差异。

> 数据来源：`moon update` 本地注册表索引 + 各仓库 README（2026-08-06 快照）

## 概览

| 库 | 版本 | 实现方式 | 目标 | 依赖 | 许可证 |
|---|---|---|---|---|---|
| **walkzzz/image** | 0.4.11 | 纯 MoonBit | native/wasm-gc/js/wasm | 无 | MIT |
| mizchi/image | 0.4.3 | 纯 MoonBit | js/native/wasm-gc | mizchi/zlib | Apache-2.0 |
| bikallem/image | 0.1.0 | 纯 MoonBit (Go 移植) | ? | bikallem/compress, moonbitlang/x, bikallem/blit | Apache-2.0 |
| gmlewis/image | 0.16.19 | 纯 MoonBit (Go 移植) | ? | gmlewis/flate, hash, io, zlib | Apache-2.0 |
| Nanaloveyuki/image | 0.1.1 | 纯 MoonBit | native | moonbit-community/flate | Apache-2.0 |
| shunge/image | 0.1.4 | 纯 MoonBit | ? | 无 | MIT |

## 格式支持矩阵

### 解码（Decode）

| 格式 | image | mizchi | bikallem | gmlewis | Nanaloveyuki | shunge |
|---|---|---|---|---|---|---|
| PNG 8-bit | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| PNG 16-bit | ✅ | ❌ | ✅ | ? | ❌ | ❌ |
| PNG interlace (Adam7) | ✅ | ? | ✅ | ? | ❌ | ✅ |
| BMP | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ (1/4/8/24/32-bit) |
| GIF (单帧) | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ |
| GIF (动画) | ✅ | ❌ | ✅ | ✅ | ❌ | ✅ |
| JPEG baseline | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| JPEG progressive | ❌ | ❌ | ✅ (decode) | ? | ❌ | ❌ |
| TGA | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ (RLE) |
| PSD | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| HDR (HDR/EXR) | ✅ (float) | ❌ | ❌ | ❌ | ❌ | ❌ |
| PNM (PPM/PGM) | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| QOI | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| WebP | ✅ (lossless VP8L only) | ❌ | ❌ | ❌ | ❌ | ❌ |
| ICO | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| CUR | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| ICNS | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| TIFF | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| APNG | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| AVIF | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

### 编码（Encode）

| 格式 | image | mizchi | bikallem | gmlewis | Nanaloveyuki | shunge |
|---|---|---|---|---|---|---|
| PNG | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| BMP | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| JPEG | ✅ (quality) | ✅ (quality) | ✅ (quality) | ✅ | ❌ | ❌ |
| TGA | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| GIF | ✅ (动画) | ✅ (单帧) | ✅ (动画) | ✅ | ❌ | ❌ |
| WebP | ✅ (lossless VP8L only) | ✅ (lossy VP8) | ❌ | ❌ | ❌ | ❌ |
| ICO | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ |
| ICNS | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ |
| AVIF | ❌ | ✅ (js) | ❌ | ❌ | ❌ | ❌ |
| QOI | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |

## 像素深度支持

| 特性 | image | mizchi | bikallem | gmlewis | Nanaloveyuki | shunge |
|---|---|---|---|---|---|---|
| 8-bit | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 16-bit | ✅ | ❌ | ✅ | ? | ❌ | ❌ |
| float (HDR) | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| 灰度 | ✅ (req_channels) | ✅ (RGBA 归一化) | ✅ | ? | ✅ | ✅ |
| 调色板 | ✅ (req_channels) | ✅ (RGBA 归一化) | ✅ | ? | ✅ | ✅ |

## 功能特性

| 特性 | image | mizchi | bikallem | gmlewis | Nanaloveyuki | shunge |
|---|---|---|---|---|---|---|
| 格式自动检测 | ✅ | ✅ (stream) | ✅ (sniff) | ? | ❌ | ✅ |
| info (不解码) | ✅ | ❌ | ✅ (config) | ? | ❌ | ❌ |
| is_16_bit / is_hdr | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| failure_reason | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| flip on load/write | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ (transform) |
| req_channels | ✅ | ❌ (RGBA 归一化) | ❌ | ❌ | ❌ | ❌ |
| HDR config (gamma/scale) | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| resize | ✅ (7 滤波器) | ✅ (3 方法) | ❌ | ❌ | ✅ (lanczos3) | ✅ (transform) |
| crop/rotate | ✅ | ❌ | ❌ | ❌ | ✅ (square) | ✅ (transform) |
| draw/compositing | ✅ | ❌ | ✅ (Floyd-Steinberg) | ❌ | ❌ | ❌ |
| 流式解码 | ✅ (逐行/分块) | ✅ (PNG/BMP) | ❌ | ❌ | ❌ | ❌ |
| 色彩模型转换 | ✅ | ❌ | ✅ (Go 模型) | ✅ | ❌ | ✅ (YCbCr→RGB) |
| 多目标 (wasm/js) | ✅ | ✅ | ? | ? | ❌ (native) | ? |

## 测试与质量

| 库 | 测试数 | 特殊验证 |
|---|---|---|
| image | 1203×4 | 纯 MoonBit, 多目标, fuzzing审计 |
| mizchi/image | ? | ? |
| bikallem/image | ? | Go 对等测试 (parity) |
| gmlewis/image | ? | ? |
| Nanaloveyuki/image | ? | CRC 校验, 解压限制 |
| shunge/image | 162 | fuzz 测试, 真实照片 |

## 定位差异

### image（本库）
- **纯 MoonBit 实现**：无 C FFI 依赖，四目标 (native/wasm-gc/js/wasm) 均使用纯 MoonBit
- **格式覆盖广**：PSD/HDR/PNM/QOI 等独特格式，16-bit/float 深度
- **多目标支持**：native/wasm-gc/js/wasm 全目标通过 1203 测试
- **完整图像处理**：resize/crop/rotate/draw/滤波/色彩/分割/频域/ORB/SIFT/SIFT匹配/RANSAC/grabCut/流式解码/光流/模板匹配/WebP lossy编码等 286 公开函数
- **安全加固**：MAX_IMAGE_DIMENSION(65535) + check_dims 维度守卫 + safe_mul/safe_mul3 溢出保护 + 全解码器入口校验 + PNG/TIFF 整数溢出修复 + 44 项 fuzzing 测试 + 19 项安全测试 + 5 项溢出测试
- **编码器扩展**：QOI/ICO/ICNS/GIF/PNM/WebP lossy 编码

### 纯 MoonBit 库的共同优势
- 多目标支持（js/native/wasm-gc）
- 无 C 依赖，部署简单
- 可移植性强

### 各库独特定位
- **mizchi/image**：格式丰富 + resize + 流式解码，全目标支持
- **bikallem/image**：Go image 全功能移植，色彩模型 + draw + 动画
- **gmlewis/image**：Go image 简单表示，长期维护（32 版本）
- **Nanaloveyuki/image**：Orbit 专用，icon 生成 (ICO/ICNS) + lanczos3
- **shunge/image**：零依赖，QOI 支持，162 测试 + fuzz

## 互补关系

image 与纯 MoonBit 库存在互补而非竞争关系：

| 需求 | 推荐库 |
|---|---|
| PSD/HDR/PNM 解码 | image |
| 16-bit/float 像素 | image |
| wasm/js 目标 | mizchi/image |
| Go 风格 API | bikallem/image, gmlewis/image |
| Icon 生成 (ICO/ICNS) | Nanaloveyuki/image |
| QOI 格式 | shunge/image |
| resize/crop/rotate | image, mizchi/image, Nanaloveyuki/image, shunge/image |
| draw/compositing | image, bikallem/image |
| 零依赖 | shunge/image |
| WebP/AVIF 编码 | image (WebP lossy), mizchi/image (WebP lossless) |
| WebP lossless 解码 | image, mizchi/image |
| 流式解码 | image, mizchi/image |
| 内存安全验证 | image (纯 MoonBit, 无 C 依赖) |