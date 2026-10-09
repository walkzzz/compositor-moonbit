# bench

性能基准测试工具 — 31 项基准覆盖编解码、几何变换、滤波、边缘检测、特征检测、频域、分割、色彩操作。

## 运行

```bash
# native release（推荐，性能数据最准确）
moon run cmd/bench --target native --release

# 其他目标
moon run cmd/bench --target wasm-gc
moon run cmd/bench --target js
```

## 基准项

| 类别 | 数量 | 基准 |
|------|------|------|
| **编解码** | 9 | PNG encode/decode, BMP, JPEG, GIF, PNM, QOI encode/decode, WebP lossy encode |
| **几何** | 6 | resize, crop, rotate_90, rotate 45°, flip_horizontal, warp_affine |
| **滤波** | 4 | gaussian_blur, box_blur, sharpen, bilateral_filter |
| **边缘/特征** | 4 | edge_detect_sobel, canny_edge, harris_corners, connected_components |
| **频域/分割** | 2 | fft_2d, slic |
| **色彩** | 6 | to_grayscale, adjust_brightness, adjust_gamma, clahe, histogram, premultiply_alpha |

所有基准使用 128×128 RGB/RGBA 测试图（resize 使用 256×256）。

## 输出

每项基准输出 JSON 数组，含平均/中位数/最小/最大/标准差/四分位数，例如：

```json
{"name":"png encode 128x128","mean":638.1,"median":636.9,"min":624.3,"max":673.9,"std_dev_pct":2.2}
```

## 完整报告

最新基准结果与分析见 [docs/performance_report.md](../../docs/performance_report.md)。

## 实现

- 入口：`main.mbt` → 调用 `@src.bench_run()`
- 基准实现：`src/bench.mbt`
- 框架：MoonBit 内置 `@bench.Bench`
