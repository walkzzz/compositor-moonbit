# 功能一览

> 从 README 提取。286 个公开函数 + 1 常量按分类概览，完整签名见 [api_reference.md](api_reference.md)。

| 分类 | 关键函数 | 说明 |
|------|---------|------|
| **编解码** | `load_from_bytes`, `write_png_to_bytes`, `decode_any`, `decode_stream`, `encode_webp_lossy` | 15 种格式：PNG/JPEG/BMP/GIF/QOI/TGA/PSD/HDR/PNM/TIFF/ICO/CUR/ICNS/APNG/WebP |
| **流式解码** | `decode_stream`, `decode_stream_chunked`, `decode_stream_channels` | 逐行 / 分块 / 指定通道回调（当前为全量解码后逐行分发） |
| **安全** | `check_dims`, `safe_mul`, `safe_mul3`, `MAX_IMAGE_DIMENSION` | 维度溢出守卫 + 溢出安全乘法 + 维度上限常量（v4.10.0） |
| **几何变换** | `resize`, `crop`, `rotate`, `warp_affine`, `warp_perspective` | 缩放/裁剪/旋转/仿射/透视，7 种滤波器 × 4 种边缘模式 |
| **色彩** | `to_grayscale`, `adjust_gamma`, `rgb_to_hsv`, `clahe` | 色彩转换/调整/空间变换/CLAHE |
| **滤波** | `gaussian_blur`, `bilateral_filter`, `nlm_denoise`, `inpaint` | 高斯/双边/NLM 去噪/图像修复 |
| **边缘** | `canny_edge`, `hough_lines`, `hough_circles`, `find_contours` | Canny/霍夫直线圆/轮廓提取 |
| **特征** | `harris_corners`, `orb_detect`, `sift_detect`, `template_match` | Harris/ORB/SIFT/模板匹配 |
| **特征匹配** | `sift_match`, `ransac_homography` | L2 距离 + Lowe 比率测试 / RANSAC + DLT 单应性估计 |
| **光流** | `lucas_kanade` | Lucas-Kanade 稀疏光流 |
| **分割** | `watershed`, `slic`, `kmeans_segment`, `grab_cut`, `connected_components` | 分水岭/SLIC/K-means/grabCut/连通域 |
| **形态学** | `erode`, `dilate`, `morph_open`, `skeletonize` | 腐蚀/膨胀/开闭运算/骨架化 |
| **频域** | `fft_2d`, `dct_2d`, `haar_transform_2d`, `freq_filter` | FFT/DCT/Haar 小波/频率滤波 |
| **质量** | `mse`, `psnr`, `ssim`, `compute_stats` | MSE/PSNR/SSIM/统计 |
