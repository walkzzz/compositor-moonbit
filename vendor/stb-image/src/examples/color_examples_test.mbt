// 示例 7-9：色彩调整
// 演示亮度/对比度/灰度转换/色彩空间转换

///|
test "example_07: adjust brightness and contrast" {
  let img = make_rgb_image(2, 2, [
    (100, 100, 100),
    (150, 150, 150),
    (200, 200, 200),
    (50, 50, 50),
  ])
  // 增加亮度 +50
  let brighter = @img.adjust_brightness(img, 50)
  assert_eq(brighter.data[0].to_int(), 150) // 100+50
  assert_eq(brighter.data[3].to_int(), 200) // 150+50
  // 减少亮度 -50
  let darker = @img.adjust_brightness(img, -50)
  assert_eq(darker.data[0].to_int(), 50) // 100-50
  // 亮度钳制到 [0, 255]
  let clamped = @img.adjust_brightness(img, 200)
  assert_eq(clamped.data[0].to_int(), 255) // 100+200 -> 255
  // 对比度因子 2.0
  let high_contrast = @img.adjust_contrast(img, 2.0)
  assert_true(high_contrast.data[0].to_int() < img.data[0].to_int()) // 100 偏暗
  // Gamma 校正
  let gamma_corrected = @img.adjust_gamma(img, 2.0)
  assert_eq(gamma_corrected.width, img.width)
  // 反色
  let inverted = @img.invert(img)
  assert_eq(inverted.data[0].to_int(), 155) // 255-100
}

///|
test "example_08: convert to grayscale and back to RGB" {
  let img = make_rgb_image(2, 1, [(255, 0, 0), (0, 255, 0)])
  // 转灰度
  let gray = @img.to_grayscale(img)
  assert_eq(gray.channels, 1)
  assert_eq(gray.width, 2)
  assert_eq(gray.height, 1)
  // 红色像素的灰度值应约为 0.299*255 ≈ 76
  assert_true(gray.data[0].to_int() > 70 && gray.data[0].to_int() < 80)
  // 绿色像素的灰度值应约为 0.587*255 ≈ 150
  assert_true(gray.data[1].to_int() > 145 && gray.data[1].to_int() < 155)
  // 灰度转回 RGB（注意：to_rgb 仅去除 alpha，不提升灰度到 RGB）
  // 使用 to_rgba 先扩展到 4 通道，再 to_rgb 去除 alpha得到 3 通道
  let rgb_again = @img.to_rgb(@img.to_rgba(gray))
  assert_eq(rgb_again.channels, 3)
  // 转 RGBA
  let rgba = @img.to_rgba(img)
  assert_eq(rgba.channels, 4)
  // 直方图均衡化
  let equalized = @img.histogram_equalize(gray)
  assert_eq(equalized.width, gray.width)
  // 直方图归一化
  let normalized = @img.histogram_normalize(gray)
  assert_eq(normalized.width, gray.width)
}

///|
test "example_09: color space conversions RGB <-> HSL/HSV/Lab" {
  // RGB -> HSL -> RGB 往返
  let (h, s, l) = @img.rgb_to_hsl(128, 64, 192)
  let (r2, g2, b2) = @img.hsl_to_rgb(h, s, l)
  assert_true((r2 - 128).abs() <= 1)
  assert_true((g2 - 64).abs() <= 1)
  assert_true((b2 - 192).abs() <= 1)
  // RGB -> HSV -> RGB 往返
  let (hv, sv, vv) = @img.rgb_to_hsv(100, 200, 50)
  let (r3, g3, b3) = @img.hsv_to_rgb(hv, sv, vv)
  assert_true((r3 - 100).abs() <= 1)
  assert_true((g3 - 200).abs() <= 1)
  assert_true((b3 - 50).abs() <= 1)
  // RGB -> Lab -> RGB 往返
  let (lx, la, lb) = @img.rgb_to_lab(200, 100, 50)
  let (r4, g4, _) = @img.lab_to_rgb(lx, la, lb)
  assert_true((r4 - 200).abs() <= 2)
  assert_true((g4 - 100).abs() <= 2)
  // RGB -> YCbCr -> RGB 往返
  let (yc, cb, cr) = @img.rgb_to_ycbcr(128, 128, 128)
  let (r5, _, _) = @img.ycbcr_to_rgb(yc, cb, cr)
  assert_true((r5 - 128).abs() <= 1)
  // RGB -> CMYK -> RGB 往返
  let (c, m, y, k) = @img.rgb_to_cmyk(0, 128, 255)
  let (r6, _, b6) = @img.cmyk_to_rgb(c, m, y, k)
  assert_eq(r6, 0)
  assert_eq(b6, 255)
}
