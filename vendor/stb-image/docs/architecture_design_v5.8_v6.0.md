# 《stb-image 架构与接口设计》

> 撰写：架构设计专家 高见远  
> 项目：stb-image (walkzzz/image) — 纯 MoonBit 图像处理库  
> 日期：2026-09-07  
> 版本基准：v5.7.0 / 1255 tests × 4 targets / 92.5% 覆盖率

---

## 一、v5.8.0 覆盖率提升方案

### 1.1 覆盖率现状分析

```
当前：92.5%（673 uncovered lines in 87 files）
目标：≥ 95%
缺口：~2.5% 覆盖率 ≈ 约 85-100 行未覆盖代码需要测试覆盖
```

### 1.2 未覆盖代码分布（按优先级分类）

#### P0 — 高价值（错误路径，每行贡献大）

| 文件 | 未覆盖行数 | 内容描述 | 测试策略 |
|------|-----------|---------|---------|
| `src/lib/lib.mbt` | 4 | `load_from_bytes_auto` 中 HDR/TGA/CUR/APNG 分支（已知限制，不触发） | 需构造特殊触发数据，或在 lib_test.mbt 中显式断言这些路径 |
| `src/pure/codec/bmp_decode.mbt` | ~6 | 行越界、尺寸校验后的像素越界分支 | 构造裁剪 BMP 文件触发 |
| `src/pure/codec/png_decode.mbt` | ~8 | `raw_pos >= raw.length()` 解压数据不足、`palette` 索引越界 | 构造截断 IDAT 数据 |
| `src/pure/codec/jpeg_decode.mbt` | ~10 | Huffman 表损坏、非法 marker 序列 | 构造损坏 JPEG |
| `src/pure/codec/tiff_codec.mbt` | ~15 | 大端字节序分支、LZW 扩展路径、Deflate 路径 | 构造大端 TIFF、多 strip TIFF |
| `src/pure/codec/gif_decode.mbt` | ~5 | 数据截断、逻辑图像描述符缺失 | 构造截断 GIF |
| `src/pure/codec/qoi_decode.mbt` | ~4 | 非法操作码、轨道终止异常 | 构造非法 QOI |
| `src/pure/codec/pnm_decode.mbt` | ~3 | P5 数据不足、格式错误 | 构造截断 PPM |
| `src/meta/exif_read.mbt` | 6 | else 分支（非 APP1 数据）、entry 越界 | 构造含异常 marker 的 JPEG |
| `src/meta/exif_write.mbt` | 3 | 非 ASCII 字符路径、JPEG 中间 marker 处理 | 传入含多字节字符的 ExifInfo |
| `src/meta/png_meta.mbt` | 2 | chunk 越界 break、UTF-8 解码失败 | 构造超长 chunk PNG |
| `src/process/color/clahe.mbt` | 1 | 空 tile（tile_pixels == 0） | 小图 + 大 tile_size |
| `src/process/color/helpers.mbt` | 2 | clamp_i 边界（< lo / > hi） | 测试中显式传入超界值 |
| `src/process/color/quantize.mbt` | 6 | channels != 3/4、n == 0 | 传入灰度图/空图 |
| `src/process/color/retinex.mbt` | 11 | gaussian_blur_channel 大 radius/正常 radius 分支 | 小图 + 大 sigma |
| `src/process/edge/canny.mbt` | 3 | 空图 n==0、hysteresis 连通 | 1x1 图 + 连通边缘图 |
| `src/process/edge/contour.mbt` | 4 | trace_boundary 未找到下一个像素（孤立点） | 构造孤立前景点 |
| `src/process/edge/contour_analysis.mbt` | ~3 | draw_contours 通道数校验 | 传入非法 channels |

#### P1 — 中价值（reexport 薄包装层）

| 文件 | 未覆盖行数 | 内容描述 | 测试策略 |
|------|-----------|---------|---------|
| `src/reexport.mbt` | ~5 | 部分 pub fn 包装器的标签参数传递 | reexport_test.mbt 中补充测试 |
| `src/util/color_map.mbt` | ~3 | 部分 blend mode 边界 | 补充 blend 测试 |
| `src/util/pixel_ops.mbt` | ~2 | threshold/posterize 边界 | 边界值测试 |

#### P2 — 低价值（benchmark 代码，天然不覆盖）

| 文件 | 未覆盖行数 | 内容描述 | 建议 |
|------|-----------|---------|------|
| `src/bench.mbt` | 51 | 全部 benchmark 函数 | **不测**，benchmark 代码从覆盖率计算中排除（若工具支持） |
| `cmd/bench/main.mbt` | 1 | main 入口 | **不测**，CLI 入口 |

### 1.3 测试补充优先级与预计收益

**优先级排序**：错误路径（P0）> reexport 包装（P1）> 边界值（P0 小图）

| 优先级 | 新增测试数 | 预计覆盖增量 | 工作难度 |
|--------|-----------|-------------|---------|
| P0-1：解码器错误路径 | ~40 | +1.5% | 中（需构造二进制测试数据） |
| P0-2：process 错误路径 | ~25 | +0.6% | 低（已有测试模式可复用） |
| P1：reexport/工具层 | ~10 | +0.3% | 低 |
| **合计** | **~75** | **+2.4%** | — |

**预期结果**：92.5% + 2.4% ≈ **94.9% → 95.0%**（向上取整达标）

### 1.4 未覆盖块测试策略汇总

#### BMP 解码器（`bmp_decode_test.mbt` 补充）

```moonbit
// 新增测试用例
test "decode_bmp_pure: truncated pixel data raises"
test "decode_bmp_pure: row data exceeds file length raises"
```
- 策略：构造 width=10, height=10 但像素数据不足的 BMP（data_offset 后不足 10×row_size 字节）

#### PNG 解码器（`png_error_test.mbt` 补充）

```moonbit
// 新增测试用例
test "decode_png_pure: truncated IDAT raises"
test "decode_png_pure: palette index out of bounds raises"
```
- 策略：构造 IDAT 解压后数据不足的 PNG；构造 color_type=3 但 PLTE 不足的 PNG

#### JPEG 解码器（`jpeg_decode_test.mbt` 补充）

```moonbit
// 新增测试用例
test "decode_jpeg_pure: truncated SOF raises"
test "decode_jpeg_pure: invalid Huffman table raises"
```
- 策略：构造截断的 JPEG SOF marker；构造 Huffman count 不匹配的 DHT

#### TIFF 解码器（`tiff_codec_test.mbt` 补充）

```moonbit
// 新增测试用例
test "decode_tiff_pure: big-endian RGB roundtrip"
test "decode_tiff_pure: multi-strip LZW raises on truncated strip"
```
- 策略：构造大端字节序 TIFF；构造多 strip 但最后一个 strip 数据截断的 TIFF

#### EXIF 读取（`exif_test.mbt` 补充）

```moonbit
// 新增测试用例
test "read_exif_from_bytes: non-ASCII chars in make/model"
test "read_exif_from_bytes: APP1 marker chain with no Exif"
```
- 策略：构造含非 ASCII 字节的 IFD 条目；构造含多个 non-Exif APP1 的 JPEG

#### reexport 层（`reexport_test.mbt` 补充）

```moonbit
// 新增测试用例
test "reexport: decode_stream through reexport"
test "reexport: decode_stream_chunked through reexport"
test "reexport: decode_stream_channels through reexport"
test "reexport: load_from_bytes with req_channels=1/2/3/4"
```

---

## 二、v6.0.0 增量流式解码架构

### 2.1 现有接口现状分析

**`src/lib/stream.mbt`** — 当前实现（全量解码后逐行分发）：

```
decode_stream(data, on_row)
  ↓
  load_from_bytes_auto(data)     // 全量解码到 Image（O(width×height) 内存）
  ↓
  for y in 0..<height:
    copy row to row_data
    on_row(y, row_data)          // 逐行回调（但数据已全量在内存中）
```

**问题**：
- 内存峰值 = O(width × height × channels)，与直接调用 `load_from_bytes` 无异
- 对大图（如 4K 图片）无内存优势
- 注释中已明确标注"未来支持增量解码"

### 2.2 向后兼容设计原则

**核心原则：已有 API 签名不变，仅新增 API**

| 已有函数 | 状态 | 说明 |
|---------|------|------|
| `decode_stream(data, on_row) -> StreamInfo` | **保留不动** | 全量解码后逐行分发，行为不变 |
| `decode_stream_chunked(data, chunk_height, on_chunk) -> StreamInfo` | **保留不动** | 全量解码后分块分发，行为不变 |
| `decode_stream_channels(data, req_channels, on_row) -> StreamInfo` | **保留不动** | 全量解码后逐行分发+通道转换，行为不变 |
| `StreamInfo` struct | **保留不动** | 结构不变 |

### 2.3 新增接口设计

#### 2.3.1 公共类型

```moonbit
// src/lib/stream.mbt（新增）

///|
/// 增量解码状态：用于逐 chunk 喂入数据的解码器
pub(all) struct IncrementalDecoder {
  width : Int
  height : Int
  channels : Int
  // 内部状态（不对外暴露）
}

///|
/// 增量解码结果（用于最终回调）
pub(all) struct StreamResult {
  width : Int
  height : Int
  channels : Int
}
```

#### 2.3.2 PNG 增量解码 API

```moonbit
///|
/// PNG 增量解码：逐 IDAT chunk 喂入，逐行回调。
/// 内存峰值 O(width × channels)（仅保留当前行 + 上一行用于 filter 还原）。
///
/// 使用方式：
///   let dec = make_png_decoder(data)
///   let info = decode_png_incremental(dec, fn(y, row) { ... })
pub fn make_png_decoder(data : Bytes) -> IncrementalDecoder raise @types.LoadError {
  // 解析 IHDR，验证签名，分配行缓冲
  // 返回 IncrementalDecoder { width, height, channels, ...internal }
}

///|
/// 喂入 IDAT 数据块并推进解码，每完成一行回调 on_row。
/// 可多次调用（对应多个 IDAT chunk）。
/// 所有数据喂入后返回 StreamResult。
pub fn decode_png_incremental(
  dec : IncrementalDecoder,
  idat_chunk : Bytes,
  on_row : (Int, Array[Byte]) -> Unit,
) -> StreamResult raise @types.LoadError {
  // 对 idat_chunk 执行 zlib inflate，得到解压后的 scanline 数据
  // 按 filter type 还原每行（仅保留当前行 + prev_row 缓冲）
  // 每还原一行即调用 on_row(y, row_data)
}
```

> **注意**：由于 MoonBit 不支持真正的流式 IO（无回调驱动的数据到达机制），`decode_png_incremental` 的实际语义是：**不调用完整 Image 分配，而是逐行处理 IDAT 解压后的 scanline 数据，每行回调后立即释放，内存峰值仅 O(width × channels × 2)**。
>
> 调用方仍需提供全部 IDAT 数据，但数据是分 chunk 传入的（可对应网络分块接收）。

#### 2.3.3 BMP 增量解码 API

```moonbit
///|
/// BMP 增量解码：逐行读取，内存峰值 O(width × channels)。
/// 直接操作原始 data 字节流，不分配完整 Image。
///
/// 适用于：从网络流/文件流中逐行处理 BMP 数据。
pub fn decode_bmp_incremental(
  data : Bytes,
  on_row : (Int, Array[Byte]) -> Unit,
) -> StreamResult raise @types.LoadError {
  // 解析 BMP 文件头 + DIB 头（不分配像素缓冲区）
  // 逐行读取 row_data（每行 row_size 字节，含填充）
  // 转换 BGR(A) → RGB(A)，计算实际像素宽度 × channels 的行数据
  // 每行回调 on_row
  // 返回 StreamResult
}
```

#### 2.3.4 统一增量解码入口

```moonbit
///|
/// 自动格式增量解码（PNG/BMP 支持，其他格式退化为全量解码）。
/// 对不支持增量解码的格式，内部调用原有 decode_stream。
pub fn decode_stream_auto(
  data : Bytes,
  on_row : (Int, Array[Byte]) -> Unit,
) -> StreamResult raise @types.LoadError {
  match detect_format(data) {
    @types.ImageFormat::Png =>
      // 走 PNG 增量路径
      let dec = make_png_decoder(data)
      // 提取所有 IDAT 数据，分 chunk 喂入
      decode_png_incremental(dec, all_idat, on_row)
    @types.ImageFormat::Bmp =>
      decode_bmp_incremental(data, on_row)
    _ =>
      // 降级：全量解码后逐行分发（保持与 decode_stream 行为一致）
      let img = load_from_bytes_auto(data)
      let w = img.width
      let ch = img.channels
      let row_data : Array[Byte] = Array::make(w * ch, b'\x00')
      for y in 0..<img.height {
        for x in 0..<w {
          for c in 0..<ch {
            row_data[x * ch + c] = img.data[(y * w + x) * ch + c]
          }
        }
        on_row(y, row_data)
      }
      StreamResult::{ width: w, height: img.height, channels: ch }
  }
}
```

### 2.4 PNG 增量解码架构设计

#### 2.4.1 数据流

```
输入: Bytes (完整 PNG 字节流)
  │
  ▼
┌─────────────────────────────────────────┐
│ Phase 1: IHDR 解析                       │
│   - 验证 PNG signature                   │
│   - 解析 width, height, bit_depth,       │
│     color_type, interlace                │
│   - 验证参数合法性（仅 8-bit, non-interlace）│
│   - 计算 channels, bpp, stride           │
│   - 分配行缓冲: prev_row (stride bytes)  │
│            + curr_row (stride bytes)     │
└─────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────┐
│ Phase 2: IDAT 分块处理                    │
│   对每个 IDAT chunk:                      │
│   ├─ zlib inflate → raw scanline bytes   │
│   └─ 逐行还原（unfilter）：               │
│       for each row:                       │
│         apply_filter(prev_row, raw, curr)│
│         callback on_row(y, curr)         │
│         prev_row ← curr (swap)           │
└─────────────────────────────────────────┘
  │
  ▼
输出: StreamResult (width, height, channels)
```

#### 2.4.2 内存模型变化

| 阶段 | 旧版 (`decode_stream`) | 新版 (`decode_png_incremental`) |
|------|----------------------|--------------------------------|
| 解析 IHDR | O(1) | O(1) |
| IDAT 累积 | O(total_IDAT) | 逐个 chunk 处理，O(chunk_size) |
| zlib inflate | O(total_raw) | O(one_row_raw) ≈ O(width × bpp) |
| 行缓冲 | 无（后续全量分配） | O(width × bpp × 2)（prev + curr） |
| 最终 Image | O(width × height × ch) | **不分配** |
| **内存峰值** | **O(width × height × ch)** | **O(width × ch)** |

**示例**：1920×1080 RGBA 图像
- 旧版：1920 × 1080 × 4 = **8.3 MB**
- 新版：1920 × 4 × 2 = **15.4 KB**（减少 540×）

#### 2.4.3 行缓冲设计

```moonbit
// PNG unfilter 仅需两行缓冲
let mut prev_row : Array[Byte] = Array::make(stride, b'\x00')
let mut curr_row : Array[Byte] = Array::make(stride, b'\x00')

for y in 0..<height {
  // 1. inflate 当前行的 raw + filter_type
  let filter_type = raw[raw_pos]
  raw_pos += 1
  
  // 2. 还原当前行（Paeth 等预测仅需 prev_row 和 curr_row 左侧）
  for x in 0..<stride {
    let raw_byte = raw[raw_pos]
    raw_pos += 1
    curr_row[x] = apply_filter(filter_type, prev_row, curr_row, x, bpp)
  }
  
  // 3. 回调：将 curr_row 转为 RGB(A) 行数据
  let row_pixels = convert_row_to_pixels(curr_row, color_type, ch)
  on_row(y, row_pixels)
  
  // 4. 交换缓冲
  let tmp = prev_row
  prev_row = curr_row
  curr_row = tmp
}
```

### 2.5 BMP 增量解码架构设计

#### 2.5.1 数据流

```
输入: Bytes (BMP 文件字节流)
  │
  ▼
┌─────────────────────────────────────────┐
│ Phase 1: 文件头解析                       │
│   - 验证 "BM" magic                      │
│   - 解析 data_offset, width, height,     │
│     bpp, compression                     │
│   - 验证仅支持 BI_RGB (compression=0)    │
│   - 计算 row_size（含 4 字节对齐填充）    │
└─────────────────────────────────────────┘
  │
  ▼
┌─────────────────────────────────────────┐
│ Phase 2: 逐行读取                          │
│   for file_row in 0..<abs_height:        │
│     row_start = data_offset + file_row * │
│                 row_size                 │
│     读取 row_size 字节（含填充）          │
│     转换 BGR(A) → RGB(A)                 │
│     回调 on_row(out_row, row_pixels)     │
└─────────────────────────────────────────┘
  │
  ▼
输出: StreamResult (width, height, channels)
```

#### 2.5.2 与全量解码的差异

BMP 全量解码目前一次性分配 `pixel_count × out_channels` 的数组再填充。增量版改为：
- 不分配完整像素数组
- 每行读取 `row_size` 字节（BMP 行对齐后的原始数据）
- 转换后回调，释放行缓冲
- 内存峰值从 O(width × height × ch) 降至 O(row_size) ≈ O(width × 4)（含填充）

### 2.6 内存模型对比总结

| 格式 | 旧版内存峰值 | 新版内存峰值 | 压缩比 |
|------|------------|------------|--------|
| PNG | O(w×h×ch) | O(w×ch) | ~h 倍 |
| BMP | O(w×h×ch) | O(w×4) | ~h 倍 |
| 其他 | O(w×h×ch) | O(w×h×ch) | 无变化（退化全量） |

---

## 三、包结构变更

### 3.1 当前包结构

```
src/
├── lib/
│   ├── lib.mbt          # 格式分派
│   ├── stream.mbt       # 流式解码（当前为全量后分发）
│   └── *_test.mbt
├── pure/
│   ├── codec/
│   │   ├── png_decode.mbt
│   │   ├── bmp_decode.mbt
│   │   └── ...
│   └── ...
└── reexport.mbt
```

### 3.2 v6.0.0 包结构变更

**无需新增子包**，增量解码逻辑直接内联在现有文件中：

```
src/
├── lib/
│   ├── lib.mbt          # 不变
│   ├── stream.mbt       # 新增：增量解码接口（make_png_decoder, decode_png_incremental, decode_bmp_incremental, decode_stream_auto）
│   └── stream_test.mbt  # 不变（保留现有测试）
│   └── stream_incremental_test.mbt  # 新增：增量解码测试
├── pure/
│   ├── codec/
│   │   ├── png_decode.mbt      # 不变（增量解码在 lib/stream.mbt 中调用 @util.zlib_inflate）
│   │   ├── bmp_decode.mbt      # 不变（增量解码直接从 Bytes 读取）
│   │   └── ...
│   └── ...
└── reexport.mbt       # 新增：增量解码 API re-export
```

**理由**：
- PNG 增量解码只需 `@util.zlib_inflate`（已有依赖）和行缓冲逻辑，无需独立包
- BMP 增量解码直接从 `Bytes` 读取，无需访问 `decode_bmp_pure` 内部
- 保持 `pure/codec/` 包的稳定性，避免引入不必要的耦合

---

## 四、接口设计（新增 API 签名）

### 4.1 `src/lib/stream.mbt` 新增内容

```moonbit
// ========== 新增：增量解码类型 ==========

///|
/// 增量 PNG 解码器状态
pub(all) struct PngIncrementalDecoder {
  width : Int
  height : Int
  channels : Int     // 输出通道数（经 req_channels 转换后）
  bpp : Int          // bytes per pixel（原始）
  stride : Int       // bytes per row（原始，含 filter byte）
  color_type : Int
  bit_depth : Int
  palette : Array[(Int, Int, Int)]
  // 内部行缓冲（priv）
  priv mut prev_row : Array[Byte]
  priv mut curr_row : Array[Byte]
  priv mut raw_pos : Int
  priv mut raw_data : Array[Byte]
  priv mut row_count : Int
}

///|
/// 增量解码结果信息
pub type StreamResult = StreamInfo  // 复用已有 StreamInfo

// ========== 新增：PNG 增量解码 API ==========

///|
/// 创建 PNG 增量解码器（解析 IHDR，分配行缓冲）。
/// 不调用完整 Image 分配，内存开销 O(width × channels)。
pub fn make_png_incremental_decoder(
  data : Bytes,
  req_channels? : Int? = None,
) -> PngIncrementalDecoder raise @types.LoadError

///|
/// 喂入 IDAT 数据并逐行回调。
/// 可多次调用（对应多个 IDAT chunk）。
/// 所有数据喂入后完成解码。
pub fn decode_png_incremental(
  dec : PngIncrementalDecoder,
  idat_data : Bytes,
  on_row : (Int, Array[Byte]) -> Unit,
) -> StreamResult raise @types.LoadError

// ========== 新增：BMP 增量解码 API ==========

///|
/// BMP 增量解码：逐行读取原始字节流，不分配完整 Image。
/// 内存峰值 O(width × 4)（含行对齐填充）。
pub fn decode_bmp_incremental(
  data : Bytes,
  on_row : (Int, Array[Byte]) -> Unit,
) -> StreamResult raise @types.LoadError

// ========== 新增：自动格式增量解码 ==========

///|
/// 自动格式增量解码：PNG/BMP 走增量路径，其他格式退化为全量解码后逐行分发。
pub fn decode_stream_auto(
  data : Bytes,
  on_row : (Int, Array[Byte]) -> Unit,
) -> StreamResult raise @types.LoadError
```

### 4.2 `src/reexport.mbt` 新增 re-export

```moonbit
// From @lib (增量解码)

///|
/// 创建 PNG 增量解码器
pub fn make_png_incremental_decoder(
  arg0 : Bytes,
  arg1? : Int? = None,
) -> @lib.PngIncrementalDecoder raise @types.LoadError {
  @lib.make_png_incremental_decoder(arg0, arg1~)
}

///|
/// PNG 增量解码：喂入 IDAT 数据并逐行回调
pub fn decode_png_incremental(
  arg0 : @lib.PngIncrementalDecoder,
  arg1 : Bytes,
  arg2 : (Int, Array[Byte]) -> Unit,
) -> @lib.StreamResult raise @types.LoadError {
  @lib.decode_png_incremental(arg0, arg1, arg2)
}

///|
/// BMP 增量解码：逐行读取
pub fn decode_bmp_incremental(
  arg0 : Bytes,
  arg1 : (Int, Array[Byte]) -> Unit,
) -> @lib.StreamResult raise @types.LoadError {
  @lib.decode_bmp_incremental(arg0, arg1)
}

///|
/// 自动格式增量解码
pub fn decode_stream_auto(
  arg0 : Bytes,
  arg1 : (Int, Array[Byte]) -> Unit,
) -> @lib.StreamResult raise @types.LoadError {
  @lib.decode_stream_auto(arg0, arg1)
}
```

---

## 五、moon.pkg.json 变更

### 5.1 无需变更

当前 `src/lib/moon.pkg` 已依赖 `@types`、`@pure`、`@codec`、`@color`、`@util`（pure 子包），增量解码仅使用已有依赖：
- `@types` — Image, LoadError, StreamInfo
- `@pure/util` — `zlib_inflate`
- `@lib` — `load_from_bytes_auto`, `detect_format`

**无新依赖引入**。

### 5.2 `src/lib/moon.pkg` 内容（不变）

```json
{
  "name": "lib",
  "edition": "0.1.0",
  "deps": {
    "types": {},
    "pure/codec": {},
    "pure/color": {},
    "pure/util": {}
  },
  "default-target": "native"
}
```

---

## 六、测试计划

### 6.1 v5.8.0 测试补充清单（~75 个新增测试）

#### 编解码器错误路径（~40 个）

| 测试文件 | 新增测试数 | 覆盖分支 |
|---------|-----------|---------|
| `bmp_decode_test.mbt` | 3 | 数据越界、行越界 |
| `png_error_test.mbt` | 4 | IDAT 截断、palette 越界 |
| `jpeg_decode_test.mbt` | 5 | SOF 截断、Huffman 异常 |
| `tiff_codec_test.mbt` | 6 | 大端字节序、多 strip 截断 |
| `gif_decode_test.mbt` | 3 | 逻辑图像缺失、数据截断 |
| `qoi_decode_test.mbt` | 3 | 非法 op、轨道异常 |
| `pnm_decode_test.mbt` | 2 | P5 数据不足 |
| `exif_test.mbt` | 4 | 非 ASCII 字符、异常 APP1 链 |
| `png_meta_test.mbt` | 2 | chunk 越界、UTF-8 无效 |
| `reexport_test.mbt` | 5 | 流式 API re-export、req_channels |
| `lib_test.mbt` | 6 | Hdr/Tga/Cur/Apng 分支断言 |

#### 图像处理边界（~25 个）

| 测试文件 | 新增测试数 | 覆盖分支 |
|---------|-----------|---------|
| `clahe_test.mbt` | 2 | 空 tile（小图大 tile） |
| `quantize_test.mbt` | 3 | 灰度图、空图 |
| `canny_test.mbt` | 2 | 1x1 图、全黑图 |
| `contour_test.mbt` | 3 | 孤立点、无前景 |
| `retinex_test.mbt` | 3 | 小图大 sigma |
| `color_map_test.mbt` | 3 | blend 边界值 |
| `pixel_ops_test.mbt` | 2 | threshold 边界 |
| `image_compose_test.mbt` | 4 | hstack/vstack 空图 |
| `image_util_test.mbt` | 3 | pad 负值、pixelate 1x1 |

### 6.2 v6.0.0 增量解码测试清单（~50 个新增测试）

| 测试文件 | 新增测试数 | 覆盖内容 |
|---------|-----------|---------|
| `stream_incremental_test.mbt` | 20 | PNG 增量：签名错误、IHDR 截断、filter 类型 0-4、palette、req_channels、与全量结果一致性 |
| `stream_incremental_test.mbt` | 15 | BMP 增量：24-bit/32-bit、bottom-up/top-down、行对齐、与全量结果一致性 |
| `stream_incremental_test.mbt` | 5 | `decode_stream_auto`：PNG→增量、BMP→增量、JPEG→降级全量 |
| `stream_incremental_test.mbt` | 5 | 内存验证：大尺寸图像（100×100）增量 vs 全量结果一致 |
| `stream_test.mbt` | 5 | 回归：现有 `decode_stream`/`decode_stream_chunked`/`decode_stream_channels` 行为不变 |

---

## 七、实施路径

### v5.8.0 实施步骤

1. **Phase 1**：补充 `bmp_decode_test.mbt`（3 个错误路径测试）
2. **Phase 2**：补充 `png_error_test.mbt`（4 个错误路径测试）
3. **Phase 3**：补充 `jpeg_decode_test.mbt`（5 个错误路径测试）
4. **Phase 4**：补充 `tiff_codec_test.mbt`（6 个：大端 + 多 strip）
5. **Phase 5**：补充 `gif/qoi/pnm/exif/png_meta` 错误路径（~16 个）
6. **Phase 6**：补充 reexport/lib 层测试（~11 个）
7. **Phase 7**：补充 process 边界测试（~25 个）
8. **验证**：`moon coverage analyze` 确认 ≥ 95%，`moon test` 全绿

### v6.0.0 实施步骤

1. **Phase 1**：实现 `make_png_incremental_decoder` + `decode_png_incremental`
   - 解析 IHDR（复用 png_decode.mbt 中的解析逻辑，提取为共享 helper）
   - 行缓冲管理（prev_row/curr_row swap）
   - Paeth 预测（复用 `png_decode.mbt` 中的 `paeth_predict`）
2. **Phase 2**：实现 `decode_bmp_incremental`
   - 解析文件头/DIB 头
   - 逐行读取 + BGR→RGB 转换
3. **Phase 3**：实现 `decode_stream_auto`
   - 格式分派：PNG/BMP→增量，其他→降级全量
4. **Phase 4**：新增 `stream_incremental_test.mbt`（~50 测试）
5. **Phase 5**：reexport.mbt 注册新 API
6. **验证**：`moon test` 全绿，`moon coverage analyze` 确认无回归

---

## 八、风险与约束检查

| 约束 | 遵守情况 |
|------|---------|
| 禁止引入 C FFI 依赖 | ✅ 增量解码纯 MoonBit 实现，仅用 `@util.zlib_inflate` |
| 禁止破坏已有 API | ✅ `decode_stream`/`decode_stream_chunked`/`decode_stream_channels` 签名不变 |
| 禁止目标条件编译 | ✅ 无 `target == "native"` 分支，四目标共用代码 |
| 新增 pub 函数须注册 reexport | ✅ 4 个新函数均在 `reexport.mbt` 注册 |
| 新增 `pub(all) struct` 可外部构造 | ✅ `PngIncrementalDecoder` 声明为 `pub(all)` |

---

## 附录：覆盖率提升量化估算

```
当前覆盖率：92.5%（1255 tests）
未覆盖行：673 lines

v5.8.0 目标：95.0%
  需覆盖新增行数 ≈ 673 × (95-92.5)/(100-95) ≈ 336 lines → 不可行
  实际策略：通过测试覆盖未覆盖行中的关键分支，使覆盖率计算器
  将已测试行计入分子。

估算：
  新增 ~75 tests，覆盖 ~200 行未覆盖代码
  覆盖率提升 ≈ 75/1255 × (平均每个 test 覆盖行数)
  
  保守估算：+2.0% → 94.5%
  乐观估算：+2.5% → 95.0% ✅
  
  若未达标，可在 v5.8.1 中追加 ~15 个测试
```
