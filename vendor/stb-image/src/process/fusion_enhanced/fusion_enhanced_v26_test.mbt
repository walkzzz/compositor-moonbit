// v26.0.0 图像融合与配准增强测试 - fusion_enhanced 模块
// 加权平均/最大值/最小值/均值融合、高斯模糊/下采样/上采样、拉普拉斯金字塔融合、相位相关配准

///|
fn make_fe_img(w : Int, h : Int, value : Byte) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(Array::make(w * h, value)),
  }
}

///|
fn make_varied_fe_img(w : Int, h : Int) -> @types.Image {
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

///|
test "create_default_fusion_config: 默认配置" {
  let config = create_default_fusion_config()
  assert_true(config.pyramid_levels > 0)
}

///|
test "create_default_registration_config: 默认配置" {
  let config = create_default_registration_config()
  assert_true(config.max_iterations > 0)
  assert_true(config.tolerance > 0.0)
}

///|
test "fuse_weighted_average: 基本加权平均" {
  let img1 = make_varied_fe_img(4, 4)
  let img2 = make_fe_img(4, 4, b'\x80')
  let result = fuse_weighted_average([img1, img2], [0.5, 0.5])
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "fuse_maximum: 基本最大值融合" {
  let img1 = make_varied_fe_img(4, 4)
  let img2 = make_fe_img(4, 4, b'\x80')
  let result = fuse_maximum([img1, img2])
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "fuse_minimum: 基本最小值融合" {
  let img1 = make_varied_fe_img(4, 4)
  let img2 = make_fe_img(4, 4, b'\x80')
  let result = fuse_minimum([img1, img2])
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "fuse_simple_mean: 基本均值融合" {
  let img1 = make_varied_fe_img(4, 4)
  let img2 = make_fe_img(4, 4, b'\x80')
  let result = fuse_simple_mean([img1, img2])
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "gaussian_blur_fe: 基本高斯模糊" {
  let img = make_varied_fe_img(8, 8)
  let result = gaussian_blur_fe(img, 3)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "downsample_fe: 基本下采样" {
  let img = make_varied_fe_img(8, 8)
  let result = downsample_fe(img)
  assert_true(result.width <= 8)
  assert_true(result.height <= 8)
}

///|
test "upsample_fe: 基本上采样" {
  let img = make_varied_fe_img(4, 4)
  let result = upsample_fe(img)
  assert_true(result.width >= 4)
  assert_true(result.height >= 4)
}

///|
test "fuse_laplacian_pyramid: 基本拉普拉斯金字塔融合" {
  let img1 = make_varied_fe_img(8, 8)
  let img2 = make_fe_img(8, 8, b'\x80')
  let result = fuse_laplacian_pyramid([img1, img2], 3)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "fuse_images: 基本融合" {
  let img1 = make_varied_fe_img(4, 4)
  let img2 = make_fe_img(4, 4, b'\x80')
  let config = create_default_fusion_config()
  let result = fuse_images([img1, img2], config)
  assert_eq(result.image.width, 4)
  assert_eq(result.image.height, 4)
}

///|
test "register_phase_correlation: 基本相位相关配准" {
  let img1 = make_varied_fe_img(8, 8)
  let img2 = make_varied_fe_img(8, 8)
  let result = register_phase_correlation(img1, img2)
  assert_true(result.similarity >= 0.0)
}

///|
test "register_images: 基本配准" {
  let img1 = make_varied_fe_img(8, 8)
  let img2 = make_varied_fe_img(8, 8)
  let config = create_default_registration_config()
  let result = register_images(img1, img2, config)
  assert_true(result.similarity >= 0.0)
}

///|
test "apply_translation: 基本平移" {
  let img = make_varied_fe_img(8, 8)
  let result = apply_translation(img, 2, 2)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "calculate_fusion_quality: 基本质量评估" {
  let img = make_varied_fe_img(8, 8)
  let quality = calculate_fusion_quality(img)
  assert_true(quality >= 0.0)
}

///|
test "fusion_report_to_string: 生成报告" {
  let img1 = make_varied_fe_img(4, 4)
  let img2 = make_fe_img(4, 4, b'\x80')
  let config = create_default_fusion_config()
  let result = fuse_images([img1, img2], config)
  let report = fusion_report_to_string(result, 0.0)
  assert_true(report.length() > 0)
}
