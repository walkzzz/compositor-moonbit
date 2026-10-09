// v29.0.0 高级图像降噪与增强算法测试
// 覆盖 denoise/advanced_denoise_enhance.mbt 的 15 个公开函数

///|
fn create_solid_dn(w : Int, h : Int, v : Int) -> @types.Image {
  let data : Array[Byte] = []
  for _ in 0..<(w * h) {
    data.push(v.to_byte())
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(data),
  }
}

///|
fn create_gradient_dn(w : Int, h : Int) -> @types.Image {
  let data : Array[Byte] = []
  for y in 0..<h {
    for x in 0..<w {
      data.push(((x + y) * 255 / (w + h) % 256).to_byte())
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(data),
  }
}

///|
fn create_noise_dn(w : Int, h : Int) -> @types.Image {
  let data : Array[Byte] = []
  let mut s = 42
  for _ in 0..<(w * h) {
    s = (s * 1103515245 + 12345) & 0x7FFFFFFF
    data.push((s % 256).to_byte())
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(data),
  }
}

///|
test "create_default_denoise_config: 默认配置" {
  let c = create_default_denoise_config()
  assert_true(c.kernel_size > 0)
  assert_true(c.strength > 0.0)
}

///|
test "mean_filter_denoise: 纯色图像" {
  let img = create_solid_dn(16, 16, 128)
  let r = mean_filter_denoise(img, 3)
  assert_true(r.width == 16 && r.height == 16)
}

///|
test "mean_filter_denoise: 噪声图像" {
  let img = create_noise_dn(16, 16)
  let r = mean_filter_denoise(img, 5)
  assert_true(r.width == 16 && r.height == 16)
}

///|
test "median_filter_denoise: 纯色图像" {
  let img = create_solid_dn(16, 16, 100)
  let r = median_filter_denoise(img, 3)
  assert_true(r.width == 16 && r.height == 16)
}

///|
test "median_filter_denoise: 渐变图像" {
  let img = create_gradient_dn(16, 16)
  let r = median_filter_denoise(img, 3)
  assert_true(r.width == 16 && r.height == 16)
}

///|
test "gaussian_filter_denoise: 纯色图像" {
  let img = create_solid_dn(16, 16, 200)
  let r = gaussian_filter_denoise(img, 5, 1.5)
  assert_true(r.width == 16 && r.height == 16)
}

///|
test "gaussian_filter_denoise: 噪声图像" {
  let img = create_noise_dn(16, 16)
  let r = gaussian_filter_denoise(img, 3, 1.0)
  assert_true(r.width == 16 && r.height == 16)
}

///|
test "bilateral_filter_denoise: 纯色图像" {
  let img = create_solid_dn(16, 16, 128)
  let r = bilateral_filter_denoise(img, 5, 50.0, 5.0)
  assert_true(r.width == 16 && r.height == 16)
}

///|
test "bilateral_filter_denoise: 渐变图像" {
  let img = create_gradient_dn(16, 16)
  let r = bilateral_filter_denoise(img, 3, 30.0, 3.0)
  assert_true(r.width == 16 && r.height == 16)
}

///|
test "calculate_noise_level: 纯色图像噪声低" {
  let img = create_solid_dn(16, 16, 128)
  let n = calculate_noise_level(img)
  assert_true(n >= 0.0)
}

///|
test "calculate_noise_level: 随机噪声图像" {
  let img = create_noise_dn(16, 16)
  let n = calculate_noise_level(img)
  assert_true(n >= 0.0)
}

///|
test "histogram_equalization_enhance: 纯色图像" {
  let img = create_solid_dn(16, 16, 128)
  let r = histogram_equalization_enhance(img)
  assert_true(r.width == 16 && r.height == 16)
}

///|
test "histogram_equalization_enhance: 渐变图像" {
  let img = create_gradient_dn(16, 16)
  let r = histogram_equalization_enhance(img)
  assert_true(r.width == 16 && r.height == 16)
}

///|
test "gamma_correction_enhance: gamma=1.0" {
  let img = create_gradient_dn(16, 16)
  let r = gamma_correction_enhance(img, 1.0)
  assert_true(r.width == 16 && r.height == 16)
}

///|
test "gamma_correction_enhance: gamma=2.0" {
  let img = create_solid_dn(16, 16, 128)
  let r = gamma_correction_enhance(img, 2.0)
  assert_true(r.width == 16 && r.height == 16)
}

///|
test "unsharp_mask_enhance: 纯色图像" {
  let img = create_solid_dn(16, 16, 128)
  let r = unsharp_mask_enhance(img, 0.5, 3)
  assert_true(r.width == 16 && r.height == 16)
}

///|
test "unsharp_mask_enhance: 渐变图像" {
  let img = create_gradient_dn(16, 16)
  let r = unsharp_mask_enhance(img, 1.0, 5)
  assert_true(r.width == 16 && r.height == 16)
}

///|
test "calculate_brightness: 纯色图像" {
  let img = create_solid_dn(16, 16, 128)
  let b = calculate_brightness(img)
  assert_true(b >= 0.0 && b <= 255.0)
}

///|
test "calculate_brightness: 渐变图像" {
  let img = create_gradient_dn(16, 16)
  let b = calculate_brightness(img)
  assert_true(b >= 0.0 && b <= 255.0)
}

///|
test "calculate_contrast: 纯色图像" {
  let img = create_solid_dn(16, 16, 128)
  let c = calculate_contrast(img)
  assert_true(c >= 0.0)
}

///|
test "calculate_contrast: 噪声图像" {
  let img = create_noise_dn(16, 16)
  let c = calculate_contrast(img)
  assert_true(c >= 0.0)
}

///|
test "calculate_sharpness: 纯色图像" {
  let img = create_solid_dn(16, 16, 128)
  let s = calculate_sharpness(img)
  assert_true(s >= 0.0)
}

///|
test "calculate_sharpness: 渐变图像" {
  let img = create_gradient_dn(16, 16)
  let s = calculate_sharpness(img)
  assert_true(s >= 0.0)
}

///|
test "denoise_image: MeanFilter" {
  let img = create_noise_dn(16, 16)
  let config = DenoiseConfig::{
    algorithm: DenoiseAlgorithm::MeanFilter,
    strength: 0.5,
    kernel_size: 3,
    sigma_color: 30.0,
    sigma_space: 5.0,
    search_window: 7,
    patch_size: 3,
    iterations: 1,
  }
  let r = denoise_image(img, config)
  assert_true(r.image.width == 16 && r.image.height == 16)
  assert_true(r.noise_level_before >= 0.0)
  assert_true(r.noise_level_after >= 0.0)
}

///|
test "denoise_image: MedianFilter" {
  let img = create_noise_dn(16, 16)
  let config = DenoiseConfig::{
    algorithm: DenoiseAlgorithm::MedianFilter,
    strength: 0.5,
    kernel_size: 3,
    sigma_color: 30.0,
    sigma_space: 5.0,
    search_window: 7,
    patch_size: 3,
    iterations: 1,
  }
  let r = denoise_image(img, config)
  assert_true(r.image.width == 16 && r.image.height == 16)
}

///|
test "denoise_image: GaussianFilter" {
  let img = create_gradient_dn(16, 16)
  let config = DenoiseConfig::{
    algorithm: DenoiseAlgorithm::GaussianFilter,
    strength: 0.3,
    kernel_size: 5,
    sigma_color: 30.0,
    sigma_space: 1.5,
    search_window: 7,
    patch_size: 3,
    iterations: 1,
  }
  let r = denoise_image(img, config)
  assert_true(r.psnr >= 0.0)
}

///|
test "enhance_image_advanced: HistogramEqualization" {
  let img = create_gradient_dn(16, 16)
  let r = enhance_image_advanced(
    img,
    EnhancementAlgorithm::HistogramEqualization,
  )
  assert_true(r.image.width == 16 && r.image.height == 16)
  assert_true(r.brightness_before >= 0.0)
  assert_true(r.brightness_after >= 0.0)
}

///|
test "enhance_image_advanced: GammaCorrection" {
  let img = create_solid_dn(16, 16, 128)
  let r = enhance_image_advanced(img, EnhancementAlgorithm::GammaCorrection)
  assert_true(r.image.width == 16 && r.image.height == 16)
  assert_true(r.contrast_before >= 0.0)
  assert_true(r.contrast_after >= 0.0)
}

///|
test "enhance_image_advanced: UnsharpMask" {
  let img = create_gradient_dn(16, 16)
  let r = enhance_image_advanced(img, EnhancementAlgorithm::UnsharpMask)
  assert_true(r.image.width == 16 && r.image.height == 16)
  assert_true(r.sharpness_before >= 0.0)
  assert_true(r.sharpness_after >= 0.0)
}

///|
test "denoise_algorithm_to_string: 所有算法" {
  assert_true(
    denoise_algorithm_to_string(DenoiseAlgorithm::MeanFilter).length() > 0,
  )
  assert_true(
    denoise_algorithm_to_string(DenoiseAlgorithm::MedianFilter).length() > 0,
  )
  assert_true(
    denoise_algorithm_to_string(DenoiseAlgorithm::GaussianFilter).length() > 0,
  )
  assert_true(
    denoise_algorithm_to_string(DenoiseAlgorithm::BilateralFilter).length() > 0,
  )
  assert_true(denoise_algorithm_to_string(DenoiseAlgorithm::BM3D).length() > 0)
}

///|
test "denoise_report_to_string: 报告非空" {
  let img = create_noise_dn(16, 16)
  let config = create_default_denoise_config()
  let result = denoise_image(img, config)
  let report = denoise_report_to_string(result)
  assert_true(report.length() > 0)
}
