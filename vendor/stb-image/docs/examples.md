# 完整示例集

> 从 README 提取。`src/examples/` 包含 **32 个示例**，覆盖全部 API 场景。

| 示例 | 覆盖内容 |
|------|---------|
| example_01~03 | I/O：加载/编码/格式检测 |
| example_04~06 | 变换：缩放/裁剪/旋转 |
| example_07~09 | 色彩：灰度/伽马/HSV |
| example_10~12 | 滤波：高斯/双边/NLM |
| example_13~14 | 形态学：腐蚀/膨胀/骨架化 |
| example_15~16 | 绘制：矩形/圆/线条 |
| example_17~18 | 分析：直方图/统计/质量评估 |
| example_19~20 | 合成：混合模式/拼接 |
| example_21~22 | WebP lossy 编码 + 流式解码 |
| example_23~24 | SIFT/ORB 特征检测与匹配 |
| example_25~29 | 图像修复/光流/grabCut/Retinex/去雾 |
| example_30~32 | FFT/频域滤波/质量评估/安全解码 |

> **安全 API**（v4.10.0）：`check_dims`、`safe_mul`、`safe_mul3`、`MAX_IMAGE_DIMENSION` 已集成到所有解码器入口，无需手动调用。用户也可直接调用 `check_dims(w, h, ch)` 在自定义代码中校验维度。

源码：[src/examples/](https://github.com/toadium/stb-image/tree/main/src/examples)
