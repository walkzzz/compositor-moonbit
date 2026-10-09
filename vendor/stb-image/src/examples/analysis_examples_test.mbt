// 示例 17-18：图像分析
// 演示统计、直方图、阈值

///|
test "example_17: compute image statistics and histogram" {
  let img = make_gray_image(4, 1, [0, 64, 128, 255])
  // 计算统计信息
  let stats = @img.compute_stats(img)
  assert_eq(stats.min_val, 0)
  assert_eq(stats.max_val, 255)
  assert_true(stats.mean > 50.0F && stats.mean < 200.0F)
  assert_true(stats.stddev > 50.0F)
  // 平均值
  let mv = @img.mean_value(img)
  assert_true(mv > 50.0F && mv < 200.0F)
  // 直方图（256 个 bin）
  let hist = @img.histogram(img)
  assert_eq(hist.length(), 256)
  assert_eq(hist[0], 1) // 值 0 出现 1 次
  assert_eq(hist[64], 1) // 值 64 出现 1 次
  assert_eq(hist[128], 1) // 值 128 出现 1 次
  assert_eq(hist[255], 1) // 值 255 出现 1 次
  // 直方图比较
  let img2 = make_gray_image(4, 1, [10, 60, 120, 250])
  let hist2 = @img.histogram(img2)
  let corr = @img.compare_hist(hist, hist2, @img.HistCompareMethod::Correlation)
  // 直方图相关性为有限浮点数
  assert_true(corr == corr) // 非 NaN
  // 图像哈希（aHash/dHash/pHash）
  let rgb_img = @img.to_rgb(img)
  let hash_a = @img.ahash(rgb_img)
  let hash_d = @img.dhash(rgb_img)
  let hash_p = @img.phash(rgb_img)
  assert_true(hash_a.length() > 0)
  assert_true(hash_d.length() > 0)
  assert_true(hash_p.length() > 0)
  // Hamming 距离
  let dist = @img.hamming_distance(hash_a, hash_a)
  assert_eq(dist, 0)
}

///|
test "example_18: thresholding (Otsu, binary, adaptive)" {
  // 构造双峰直方图图像
  let img = make_gray_image(8, 8, [
    20, 25, 30, 200, 210, 220, 30, 25, 25, 30, 35, 210, 220, 230, 35, 30, 30, 35,
    40, 220, 230, 240, 40, 35, 25, 30, 35, 210, 220, 230, 35, 30, 20, 25, 30, 200,
    210, 220, 30, 25, 25, 30, 35, 210, 220, 230, 35, 30, 30, 35, 40, 220, 230, 240,
    40, 35, 25, 30, 35, 210, 220, 230, 35, 30,
  ])
  // Otsu 自动阈值
  let otsu_result = @img.threshold_otsu(img)
  assert_eq(otsu_result.width, 8)
  // 手动阈值
  let binary = @img.threshold(img, 128)
  assert_eq(binary.width, 8)
  // 自适应阈值（均值）
  let adaptive_mean = @img.adaptive_threshold_mean(@img.to_rgb(img), 3, 5)
  assert_eq(adaptive_mean.width, 8)
  // 自适应阈值（高斯）
  let adaptive_gauss = @img.adaptive_threshold_gaussian(@img.to_rgb(img), 3, 5)
  assert_eq(adaptive_gauss.width, 8)
  // 验证 Otsu 结果是二值图像
  assert_true(is_binary_image(otsu_result))
}
