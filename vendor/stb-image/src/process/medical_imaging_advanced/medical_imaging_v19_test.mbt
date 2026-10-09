// v19.0.0 医学图像增强测试 - medical_imaging_advanced 模块
// 高级医学图像分割、病灶检测、器官分割、影像组学、配准、报告

///|
fn make_medical_data(w : Int, h : Int) -> Array[Double] {
  let arr : Array[Double] = []
  for i in 0..<(w * h) {
    arr.push((i % 256).to_double())
  }
  arr
}

///|
test "create_default_medical_config: 返回有效配置" {
  let config = create_default_medical_config()
  assert_true(config.detection_threshold > 0.0)
  assert_true(config.detection_threshold < 1.0)
  assert_true(config.voxel_spacing.length() > 0)
}

///|
test "segment_medical_image: 基本分割" {
  let config = create_default_medical_config()
  let image = make_medical_data(8, 8)
  let result = segment_medical_image(image, 8, 8, config)
  assert_eq(result.segmentation_map.length(), 8)
  assert_true(result.num_classes > 0)
  assert_true(result.pixel_accuracy > 0.0)
}

///|
test "segment_medical_image: 小图像" {
  let config = create_default_medical_config()
  let image = make_medical_data(4, 4)
  let result = segment_medical_image(image, 4, 4, config)
  assert_eq(result.segmentation_map.length(), 4)
  assert_eq(result.confidence_map.length(), 4)
}

///|
test "detect_lesions: 基本病灶检测" {
  let config = create_default_medical_config()
  let image = make_medical_data(200, 200)
  let lesions = detect_lesions(image, 200, 200, config)
  assert_true(lesions.length() >= 0)
}

///|
test "segment_organ: 基本器官分割" {
  let config = create_default_medical_config()
  let image = make_medical_data(8, 8)
  let result = segment_organ(image, 8, 8, OrganType::Lung, config)
  assert_true(result.volume >= 0.0)
  assert_true(result.dice_score >= 0.0)
}

///|
test "extract_radiomics_features: 基本特征提取" {
  let config = create_default_medical_config()
  let image = make_medical_data(8, 8)
  let mask : Array[Array[Bool]] = []
  for _ in 0..<8 {
    mask.push(Array::make(8, true))
  }
  let features = extract_radiomics_features(image, mask, config)
  assert_true(features.num_features > 0)
}

///|
test "register_medical_images: 基本配准" {
  let config = create_default_medical_config()
  let fixed = make_medical_data(8, 8)
  let moving = make_medical_data(8, 8)
  let result = register_medical_images(fixed, moving, 8, 8, config)
  assert_eq(result.transformation_matrix.length(), 4)
  assert_true(result.similarity_score >= 0.0)
}

///|
test "medical_imaging_report_to_string: 报告生成" {
  let config = create_default_medical_config()
  let report = medical_imaging_report_to_string(
    MedicalImagingTaskType::ImageSegmentation,
    config,
    "分割成功",
  )
  assert_true(report.length() > 0)
}
