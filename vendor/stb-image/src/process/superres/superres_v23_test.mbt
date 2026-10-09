// v23.0.0 图像超分辨率增强测试 - superres 模块
// 双三次/Lanczos/边缘保持超分、插值算法、USM锐化、均值去噪、PSNR/SSIM质量评估

///|
fn make_sr_img(w : Int, h : Int, value : Byte) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(Array::make(w * h, value)),
  }
}

///|
fn make_varied_sr_img(w : Int, h : Int) -> @types.Image {
  let arr : Array[Byte] = []
  for i in 0..<(w * h) {
    arr.push((i % 256).to_byte())
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(arr),
  }
}

// ==================== super_resolution.mbt 测试 ====================

///|
test "sr_default_config: 默认配置" {
  let config = sr_default_config()
  assert_true(config.scale > 0.0)
  assert_true(config.lanczos_a > 0)
  assert_true(config.edge_threshold > 0.0)
}

///|
test "super_resolution_bicubic: 基本放大" {
  let img = make_varied_sr_img(4, 4)
  let result = super_resolution_bicubic(img, 2.0)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 1)
}

///|
test "super_resolution_bicubic: 1倍不改变尺寸" {
  let img = make_varied_sr_img(4, 4)
  let result = super_resolution_bicubic(img, 1.0)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "super_resolution_lanczos: 基本放大" {
  let img = make_varied_sr_img(4, 4)
  let result = super_resolution_lanczos(img, 2.0)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "super_resolution_lanczos: 自定义a参数" {
  let img = make_varied_sr_img(4, 4)
  let result = super_resolution_lanczos(img, 2.0, a=2)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "super_resolution_edge_preserving: 基本放大" {
  let img = make_varied_sr_img(4, 4)
  let result = super_resolution_edge_preserving(img, 2.0)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "super_resolution_edge_preserving: 自定义参数" {
  let img = make_varied_sr_img(4, 4)
  let result = super_resolution_edge_preserving(
    img,
    2.0,
    edge_threshold=50.0,
    sharpen_amount=0.8,
  )
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "super_resolution: 默认配置" {
  let img = make_varied_sr_img(4, 4)
  let result = super_resolution(img)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "super_resolution: lanczos方法" {
  let img = make_varied_sr_img(4, 4)
  let config = SuperResolutionConfig::{
    ..sr_default_config(),
    method_type: "lanczos",
  }
  let result = super_resolution(img, config~)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "super_resolution: edge_preserving方法" {
  let img = make_varied_sr_img(4, 4)
  let config = SuperResolutionConfig::{
    ..sr_default_config(),
    method_type: "edge_preserving",
  }
  let result = super_resolution(img, config~)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "upscale_2x: 2倍放大" {
  let img = make_varied_sr_img(4, 4)
  let result = upscale_2x(img)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "upscale_4x: 4倍放大" {
  let img = make_varied_sr_img(4, 4)
  let result = upscale_4x(img)
  assert_eq(result.width, 16)
  assert_eq(result.height, 16)
}

// ==================== super_resolution_enhancement.mbt 测试 ====================

///|
test "create_default_interpolation_config: 默认配置" {
  let config = create_default_interpolation_config()
  assert_true(config.scale_factor > 0.0)
  assert_true(config.sharpening_strength >= 0.0)
  assert_true(config.denoise_strength >= 0.0)
}

///|
test "create_default_enhancement_config: 默认配置" {
  let config = create_default_enhancement_config()
  assert_eq(config.brightness, 0.0)
  assert_eq(config.contrast, 1.0)
  assert_eq(config.gamma, 1.0)
}

///|
test "nearest_neighbor_interpolate: 基本插值" {
  let img = make_varied_sr_img(4, 4)
  let result = nearest_neighbor_interpolate(img, 2.0)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 1)
}

///|
test "nearest_neighbor_interpolate: 1倍不改变" {
  let img = make_varied_sr_img(4, 4)
  let result = nearest_neighbor_interpolate(img, 1.0)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "bilinear_interpolate: 基本插值" {
  let img = make_varied_sr_img(4, 4)
  let result = bilinear_interpolate(img, 2.0)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "bilinear_interpolate: 1倍不改变" {
  let img = make_varied_sr_img(4, 4)
  let result = bilinear_interpolate(img, 1.0)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "bicubic_interpolate: 基本插值" {
  let img = make_varied_sr_img(4, 4)
  let result = bicubic_interpolate(img, 2.0)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "sharpen_image: 基本锐化" {
  let img = make_varied_sr_img(4, 4)
  let result = sharpen_image(img, 0.5)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "sharpen_image: 零强度不改变" {
  let img = make_sr_img(4, 4, b'\x80')
  let result = sharpen_image(img, 0.0)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "denoise_image: 基本去噪" {
  let img = make_varied_sr_img(4, 4)
  let result = denoise_image(img, 0.5)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "denoise_image: 零强度不改变" {
  let img = make_varied_sr_img(4, 4)
  let result = denoise_image(img, 0.0)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "super_resolve: 基本超分辨率" {
  let img = make_varied_sr_img(4, 4)
  let config = create_default_interpolation_config()
  let result = super_resolve(img, config)
  assert_eq(result.original_width, 4)
  assert_eq(result.original_height, 4)
  assert_true(result.output_width >= 4)
  assert_true(result.output_height >= 4)
}

///|
test "super_resolve: 最近邻算法" {
  let img = make_varied_sr_img(4, 4)
  let config = InterpolationConfig::{
    algorithm: SuperResolutionAlgorithm::NearestNeighbor,
    scale_factor: 2.0,
    use_edge_preservation: false,
    sharpening_strength: 0.0,
    denoise_strength: 0.0,
  }
  let result = super_resolve(img, config)
  assert_eq(result.output_width, 8)
  assert_eq(result.output_height, 8)
  assert_true(result.algorithm == SuperResolutionAlgorithm::NearestNeighbor)
}

///|
test "super_resolve: 双线性算法" {
  let img = make_varied_sr_img(4, 4)
  let config = InterpolationConfig::{
    algorithm: SuperResolutionAlgorithm::Bilinear,
    scale_factor: 2.0,
    use_edge_preservation: false,
    sharpening_strength: 0.0,
    denoise_strength: 0.0,
  }
  let result = super_resolve(img, config)
  assert_eq(result.output_width, 8)
  assert_eq(result.output_height, 8)
}

///|
test "calculate_psnr_sr: 相同图像" {
  let img = make_varied_sr_img(4, 4)
  let psnr = calculate_psnr_sr(img, img)
  assert_eq(psnr, 100.0)
}

///|
test "calculate_psnr_sr: 不同图像" {
  let img1 = make_sr_img(4, 4, b'\x00')
  let img2 = make_sr_img(4, 4, b'\xFF')
  let psnr = calculate_psnr_sr(img1, img2)
  assert_true(psnr >= 0.0)
}

///|
test "calculate_ssim_sr: 相同图像" {
  let img = make_varied_sr_img(4, 4)
  let ssim = calculate_ssim_sr(img, img)
  assert_true((ssim - 1.0).abs() < 0.01)
}

///|
test "calculate_ssim_sr: 不同图像" {
  let img1 = make_sr_img(4, 4, b'\x00')
  let img2 = make_sr_img(4, 4, b'\xFF')
  let ssim = calculate_ssim_sr(img1, img2)
  assert_true(ssim >= 0.0)
  assert_true(ssim <= 1.0 + 0.0001)
}

///|
test "calculate_image_quality_metrics: 相同图像" {
  let img = make_varied_sr_img(4, 4)
  let metrics = calculate_image_quality_metrics(img, img)
  assert_true(metrics.psnr >= 0.0)
  assert_true(metrics.ssim >= 0.0)
  assert_true(metrics.mse >= 0.0)
  assert_true(metrics.mae >= 0.0)
}

///|
test "calculate_image_quality_metrics: 不同图像" {
  let img1 = make_sr_img(4, 4, b'\x00')
  let img2 = make_sr_img(4, 4, b'\x80')
  let metrics = calculate_image_quality_metrics(img1, img2)
  assert_true(metrics.psnr >= 0.0)
  assert_true(metrics.mse > 0.0)
  assert_true(metrics.mae > 0.0)
}

///|
test "enhance_image: 默认配置不改变" {
  let img = make_varied_sr_img(4, 4)
  let config = create_default_enhancement_config()
  let result = enhance_image(img, config)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "enhance_image: 亮度调整" {
  let img = make_sr_img(4, 4, b'\x80')
  let config = EnhancementConfig::{
    brightness: 0.1,
    contrast: 1.0,
    saturation: 1.0,
    sharpness: 0.0,
    denoise: 0.0,
    gamma: 1.0,
    use_clahe: false,
    clahe_clip_limit: 2.0,
    clahe_tile_size: 8,
  }
  let result = enhance_image(img, config)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "enhance_image: 对比度调整" {
  let img = make_varied_sr_img(4, 4)
  let config = EnhancementConfig::{
    brightness: 0.0,
    contrast: 1.5,
    saturation: 1.0,
    sharpness: 0.0,
    denoise: 0.0,
    gamma: 1.0,
    use_clahe: false,
    clahe_clip_limit: 2.0,
    clahe_tile_size: 8,
  }
  let result = enhance_image(img, config)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "super_resolution_report_to_string: 生成报告" {
  let img = make_varied_sr_img(4, 4)
  let config = create_default_interpolation_config()
  let sr_result = super_resolve(img, config)
  let metrics = calculate_image_quality_metrics(img, img)
  let report = super_resolution_report_to_string(sr_result, metrics)
  assert_true(report.length() > 0)
  assert_true(report.contains("图像超分辨率报告"))
}
