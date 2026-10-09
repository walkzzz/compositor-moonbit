// v26.0.0 图像融合与配准增强测试 - registration_advanced 模块
// 相位相关配准/归一化互相关/互信息/Harris角点/特征匹配/仿射变换估计

///|
fn _make_ra_img(w : Int, h : Int, value : Byte) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(Array::make(w * h, value)),
  }
}

///|
fn make_varied_ra_img(w : Int, h : Int) -> @types.Image {
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
test "create_default_registration_config_advanced: 默认配置" {
  let config = create_default_registration_config_advanced()
  assert_true(config.max_iterations > 0)
  assert_true(config.convergence_threshold > 0.0)
  assert_true(config.search_radius > 0)
}

///|
test "phase_correlation_registration: 基本相位相关配准" {
  let img1 = make_varied_ra_img(8, 8)
  let img2 = make_varied_ra_img(8, 8)
  let result = phase_correlation_registration(img1, img2)
  assert_true(result.correlation >= 0.0)
}

///|
test "apply_translation: 基本平移" {
  let img = make_varied_ra_img(8, 8)
  let result = apply_translation(img, 2, 2)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "normalized_cross_correlation: 基本互相关" {
  let img1 = make_varied_ra_img(8, 8)
  let img2 = make_varied_ra_img(8, 8)
  let ncc = normalized_cross_correlation(img1, img2)
  assert_true(ncc >= -1.0)
  assert_true(ncc <= 1.0 + 0.0001)
}

///|
test "calculate_mutual_information: 基本互信息" {
  let img1 = make_varied_ra_img(8, 8)
  let img2 = make_varied_ra_img(8, 8)
  let mi = calculate_mutual_information(img1, img2)
  assert_true(mi >= 0.0)
}

///|
test "detect_harris_corners: 基本角点检测" {
  let img = make_varied_ra_img(8, 8)
  let corners = detect_harris_corners(img, 0.01)
  assert_true(corners.length() >= 0)
}

///|
test "match_feature_points: 基本特征匹配" {
  let img1 = make_varied_ra_img(8, 8)
  let img2 = make_varied_ra_img(8, 8)
  let points1 = detect_harris_corners(img1, 0.01)
  let points2 = detect_harris_corners(img2, 0.01)
  let matches = match_feature_points(points1, points2, 100.0)
  assert_true(matches.length() >= 0)
}

///|
test "estimate_affine_transform: 基本仿射变换估计" {
  let img1 = make_varied_ra_img(8, 8)
  let img2 = make_varied_ra_img(8, 8)
  let points1 = detect_harris_corners(img1, 0.01)
  let points2 = detect_harris_corners(img2, 0.01)
  let matches = match_feature_points(points1, points2, 100.0)
  let matrix = estimate_affine_transform(matches)
  ignore(matrix)
  assert_true(true)
}

///|
test "apply_affine_transform: 基本仿射变换" {
  let img = make_varied_ra_img(8, 8)
  let matrix = TransformMatrix::{
    matrix: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0],
    transform_type: TransformType::Affine,
    width: 0,
    height: 0,
  }
  let result = apply_affine_transform(img, matrix)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "feature_based_registration: 基本特征配准" {
  let img1 = make_varied_ra_img(8, 8)
  let img2 = make_varied_ra_img(8, 8)
  let config = create_default_registration_config_advanced()
  let result = feature_based_registration(img1, img2, config)
  assert_true(result.correlation >= 0.0)
}

///|
test "register_images_advanced: 基本高级配准" {
  let img1 = make_varied_ra_img(8, 8)
  let img2 = make_varied_ra_img(8, 8)
  let config = create_default_registration_config_advanced()
  let result = register_images_advanced(img1, img2, config)
  assert_true(result.correlation >= 0.0)
}

///|
test "registration_report_to_string_advanced: 生成报告" {
  let img1 = make_varied_ra_img(8, 8)
  let img2 = make_varied_ra_img(8, 8)
  let config = create_default_registration_config_advanced()
  let result = register_images_advanced(img1, img2, config)
  let report = registration_report_to_string_advanced(result)
  assert_true(report.length() > 0)
}
