# image

MoonBit 纯图像处理库 — 15 种格式编解码 + 50+ 计算机视觉算法。零 C FFI 依赖，native/wasm-gc/js/wasm 四目标共用同一代码库。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://img.shields.io/badge/tests-1203%20%C3%97%204%20targets-brightgreen)]()
[![Coverage](https://img.shields.io/badge/coverage-90.4%25-brightgreen)]()
[![API](https://img.shields.io/badge/API-283%20fn%20%2B%2047%20types-blueviolet)]()

## Quick Start

```moonbit nocheck
// Decode from memory
let img : Image = load_from_bytes(png_bytes)
println("width=\{img.width}, height=\{img.height}, channels=\{img.channels}")

// Auto-detect format and decode
let any : Image = decode_any(data, req_channels=Some(3))

// Encode to PNG bytes
let out : Bytes = write_png_to_bytes(img)

// Resize (7 filters × 4 edge modes)
let resized : Image = resize(img, 128, 128)

// Load animated GIF
let anim : GifAnimation = load_gif_from_bytes(gif_bytes)

// Query image info without decoding pixels
let info : ImageInfo? = info_from_bytes(data)

// Streaming decode (line-by-line callback; currently decodes fully then dispatches row by row)
decode_stream(data, fn(row, y) {
  // process row y : Array[Array[Int]]
})
```

## Format Support

| Format | Decode | Encode | Notes |
|:------:|:------:|:------:|-------|
| PNG | ✅ | ✅ | 8/16-bit, Adam7 interlace |
| JPEG | ✅ | ✅ | baseline, adjustable quality |
| BMP | ✅ | ✅ | 1/4/8/16/24/32-bit |
| GIF | ✅ | ✅ | animated GIF decode/encode |
| QOI | ✅ | ✅ | Quite OK Image |
| TGA | ✅ | ✅ | with RLE |
| PSD | ✅ | — | Photoshop document (exclusive) |
| HDR | ✅ | ✅ | IEEE 754 float (exclusive) |
| PNM | ✅ | ✅ | PPM / PGM |
| TIFF | ✅ | ✅ | uncompressed/LZW/PackBits |
| ICO | ✅ | ✅ | single/multi-size |
| CUR | ✅ | ✅ | Windows cursor |
| ICNS | ✅ | ✅ | macOS icon |
| APNG | ✅ | ✅ | animated PNG |
| WebP | ✅ (lossless) | ✅ (lossy VP8) | lossless (VP8L) decode + lossy (VP8) encode; note: lossy encode output cannot be decoded by this library |

> `detect_format` recognizes PNG/JPEG/BMP/GIF/QOI/PNM/PSD/HDR/WebP via magic bytes. TIFF/ICO/CUR/ICNS/APNG/TGA require manual `decode_tiff`/`decode_ico`/`decode_cur`/`decode_icns`/`decode_apng` calls.

## Core Types

`Image` (8-bit) · `Image16` (16-bit) · `ImageF` (HDR float) · `ImageInfo` · `GifAnimation` · `SuperpixelResult` · `LoadError` (`FileIO` / `UnsupportedFormat` / `DecodeFailed` / `EncodeFailed`)

## API Overview

283 public functions across 8 categories. Full reference: [docs/api_reference.md](https://github.com/toadium/stb-image/blob/main/docs/api_reference.md).

| Category | Highlights |
|----------|-----------|
| **Codec** | `load_from_bytes`, `decode_any`, `write_png_to_bytes`, `decode_stream`, `encode_webp_lossy` |
| **Geometry** | `resize`, `crop`, `rotate`, `warp_affine`, `warp_perspective` |
| **Color** | `to_grayscale`, `adjust_gamma`, `rgb_to_hsv`, `clahe` |
| **Filter** | `gaussian_blur`, `bilateral_filter`, `nlm_denoise`, `inpaint` |
| **Edge** | `canny_edge`, `hough_lines`, `find_contours` |
| **Feature** | `harris_corners`, `orb_detect`, `sift_detect`, `sift_match`, `ransac_homography` |
| **Segment** | `watershed`, `slic`, `grab_cut`, `connected_components` |
| **Frequency** | `fft_2d`, `dct_2d`, `haar_transform_2d`, `freq_filter` |

## Error Handling

```moonbit nocheck
try {
  let img = load_from_bytes(data)
} catch {
  LoadError::FileIO(msg) => println("file io: \{msg}")
  LoadError::DecodeFailed(msg) => println("decode failed: \{msg}")
  LoadError::UnsupportedFormat(msg) => println("unsupported: \{msg}")
  LoadError::EncodeFailed(msg) => println("encode failed: \{msg}")
}
```

## Multi-Target

native / wasm-gc / js / wasm — same pure MoonBit codebase, no conditional compilation. 1177 tests pass per target, 90.4% coverage.

## Documentation

- [API Reference (283 fn + 47 types)](https://github.com/toadium/stb-image/blob/main/docs/api_reference.md)
- [Architecture & Design](https://github.com/toadium/stb-image/blob/main/docs/architecture.md)
- [Performance Report](https://github.com/toadium/stb-image/blob/main/docs/performance_report.md)
- [Roadmap](https://github.com/toadium/stb-image/blob/main/docs/roadmap.md)
- [Changelog](https://github.com/toadium/stb-image/blob/main/docs/changelog.md)
- [Examples (32)](https://github.com/toadium/stb-image/tree/main/src/examples)

---

License: MIT · [GitHub](https://github.com/toadium/stb-image) · Package version `0.4.10` (functional version v4.8.0)
