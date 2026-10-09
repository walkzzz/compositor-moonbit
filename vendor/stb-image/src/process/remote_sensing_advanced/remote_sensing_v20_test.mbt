// v20.0.0 遥感图像增强测试 - remote_sensing_advanced 模块
// 高级遥感：地物分类、目标检测、变化检测、报告生成

///|
fn make_band_data(n : Int) -> Array[Double] {
  let arr : Array[Double] = []
  for i in 0..<n {
    arr.push((i % 256).to_double())
  }
  arr
}

///|
test "create_default_remote_sensing_config: 返回有效配置" {
  let config = create_default_remote_sensing_config()
  assert_true(config.num_bands > 0)
  assert_true(config.spatial_resolution > 0.0)
  assert_true(config.detection_threshold > 0.0)
}

///|
test "calculate_ndvi: 基本计算" {
  let nir = make_band_data(16)
  let red = make_band_data(16)
  let ndvi = calculate_ndvi(nir, red, 16)
  assert_eq(ndvi.length(), 16)
}

///|
test "calculate_ndvi: 零分母" {
  let nir : Array[Double] = Array::make(4, 0.0)
  let red : Array[Double] = Array::make(4, 0.0)
  let ndvi = calculate_ndvi(nir, red, 4)
  let mut all_zero = true
  for v in ndvi {
    if v != 0.0 {
      all_zero = false
    }
  }
  assert_true(all_zero)
}

///|
test "calculate_ndwi: 基本计算" {
  let green = make_band_data(16)
  let nir = make_band_data(16)
  let ndwi = calculate_ndwi(green, nir, 16)
  assert_eq(ndwi.length(), 16)
}

///|
test "classify_land_cover: 基本分类" {
  let config = create_default_remote_sensing_config()
  let image = make_band_data(64)
  let result = classify_land_cover(image, 8, 8, config)
  assert_eq(result.classification_map.length(), 8)
  assert_true(result.num_classes > 0)
}

///|
test "detect_remote_sensing_objects: 基本检测" {
  let config = create_default_remote_sensing_config()
  let image = make_band_data(64)
  let result = detect_remote_sensing_objects(image, 8, 8, config)
  assert_true(result.length() >= 0)
}

///|
test "detect_changes: 基本变化检测" {
  let config = create_default_remote_sensing_config()
  let img1 = make_band_data(64)
  let img2 = make_band_data(64)
  let result = detect_changes(img1, img2, 8, 8, config)
  assert_true(result.total_change_area >= 0.0)
}

///|
test "remote_sensing_report_to_string: 报告生成" {
  let config = create_default_remote_sensing_config()
  let report = remote_sensing_report_to_string(
    RemoteSensingTaskType::LandCoverClassification,
    config,
    "分类完成",
  )
  assert_true(report.length() > 0)
}
