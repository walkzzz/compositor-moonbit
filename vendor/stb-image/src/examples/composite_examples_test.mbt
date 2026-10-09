// 示例 19-20：图像合成与噪声
// 演示混合模式、噪声添加

///|
test "example_19: blend two images with various blend modes" {
  // 创建两个 4x4 RGB 图像
  let base = make_rgb_image(4, 4, Array::make(16, (100, 100, 100)))
  let overlay = make_rgb_image(4, 4, Array::make(16, (200, 50, 150)))
  // 正品叠底
  let multiplied = @img.blend_multiply(base, overlay)
  assert_eq(multiplied.width, 4)
  // 滤色
  let screened = @img.blend_screen(base, overlay)
  assert_eq(screened.width, 4)
  // 叠加
  let overlaid = @img.blend_overlay(base, overlay)
  assert_eq(overlaid.width, 4)
  // 变暗
  let darkened = @img.blend_darken(base, overlay)
  assert_eq(darkened.width, 4)
  // 变亮
  let lightened = @img.blend_lighten(base, overlay)
  assert_eq(lightened.width, 4)
  // 差值
  let differed = @img.blend_difference(base, overlay)
  assert_eq(differed.width, 4)
  // 颜色减淡
  let dodged = @img.blend_color_dodge(base, overlay)
  assert_eq(dodged.width, 4)
  // 柔光
  let soft_lighted = @img.blend_soft_light(base, overlay)
  assert_eq(soft_lighted.width, 4)
  // 水平拼接
  let hstacked = @img.hstack(base, overlay)
  assert_eq(hstacked.width, 8)
  assert_eq(hstacked.height, 4)
  // 垂直拼接
  let vstacked = @img.vstack(base, overlay)
  assert_eq(vstacked.width, 4)
  assert_eq(vstacked.height, 8)
}

///|
test "example_20: add noise to image (Gaussian, Salt-Pepper)" {
  let img = make_rgb_image(8, 8, Array::make(64, (128, 128, 128)))
  // 高斯噪声（均值 0，标准差 20，种子 42）
  let gaussian_noisy = @img.add_noise_gaussian(img, 20.0, 42U)
  assert_eq(gaussian_noisy.width, 8)
  assert_eq(gaussian_noisy.height, 8)
  // 椒盐噪声（密度 0.1，种子 42）
  let sp_noisy = @img.add_noise_salt_pepper(img, 0.1, 42U)
  assert_eq(sp_noisy.width, 8)
  assert_eq(sp_noisy.height, 8)
  // 噪声图像应与原图不同（至少有一个像素改变）
  assert_true(images_differ(gaussian_noisy, img))
  assert_true(images_differ(sp_noisy, img))
  // 像素化（马赛克效果）
  let pixelated = @img.pixelate(img, 2)
  assert_eq(pixelated.width, 8)
  // 海报化（减少颜色级数）
  let posterized = @img.posterize(img, 4)
  assert_eq(posterized.width, 8)
}
