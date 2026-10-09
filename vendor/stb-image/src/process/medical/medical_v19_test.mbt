// v19.0.0 医学图像增强测试 - medical 模块
// 医学图像分割、配准、窗宽窗位、病灶检测、质量评估、报告生成

///|
fn make_medical_image(w : Int, h : Int) -> MedicalImage {
  let data : Array[Double] = []
  for i in 0..<(w * h) {
    data.push((i % 256).to_double())
  }
  MedicalImage::{
    width: w,
    height: h,
    slices: 1,
    data,
    image_type: MedicalImageType::CT,
    pixel_spacing_x: 1.0,
    pixel_spacing_y: 1.0,
    slice_thickness: 1.0,
    window_center: 40.0,
    window_width: 80.0,
  }
}

///|
fn make_uniform_medical(w : Int, h : Int, value : Double) -> MedicalImage {
  MedicalImage::{
    width: w,
    height: h,
    slices: 1,
    data: Array::make(w * h, value),
    image_type: MedicalImageType::MRI,
    pixel_spacing_x: 1.0,
    pixel_spacing_y: 1.0,
    slice_thickness: 1.0,
    window_center: 40.0,
    window_width: 80.0,
  }
}

///|
fn make_gray_img(w : Int, h : Int, value : Byte) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(Array::make(w * h, value)),
  }
}

///|
test "create_default_medical_segmentation_config: 返回有效配置" {
  let config = create_default_medical_segmentation_config()
  assert_true(config.upper_threshold > config.lower_threshold)
  assert_true(config.smoothness > 0.0)
}

///|
test "create_default_window_level: 脑窗" {
  let config = create_default_window_level("brain")
  assert_eq(config.preset, "brain")
  assert_true(config.width > 0.0)
}

///|
test "create_default_window_level: 肺窗" {
  let config = create_default_window_level("lung")
  assert_eq(config.preset, "lung")
  assert_true(config.width > 0.0)
}

///|
test "create_default_window_level: 自定义" {
  let config = create_default_window_level("unknown")
  assert_eq(config.preset, "custom")
  assert_true(config.width > 0.0)
}

///|
test "apply_window_level_medical: 基本应用" {
  let image = make_medical_image(8, 8)
  let config = create_default_window_level("brain")
  let result = apply_window_level_medical(image, config)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 1)
  assert_eq(result.data.length(), 64)
}

///|
test "medical_threshold_segmentation: 基本阈值分割" {
  let image = make_medical_image(8, 8)
  let mask = medical_threshold_segmentation(image, 50.0, 200.0)
  assert_eq(mask.length(), 64)
  let mut true_count = 0
  for m in mask {
    if m {
      true_count += 1
    }
  }
  assert_true(true_count > 0 && true_count < 64)
}

///|
test "medical_threshold_segmentation: 全包含" {
  let image = make_medical_image(4, 4)
  let mask = medical_threshold_segmentation(image, -1000.0, 1000.0)
  let mut all_true = true
  for m in mask {
    if !m {
      all_true = false
    }
  }
  assert_true(all_true)
}

///|
test "region_growing_segmentation: 基本区域生长" {
  let image = make_uniform_medical(8, 8, 100.0)
  let mask = region_growing_segmentation(image, 4, 4, 0, 50.0)
  assert_eq(mask.length(), 64)
  let mut true_count = 0
  for m in mask {
    if m {
      true_count += 1
    }
  }
  assert_true(true_count > 0)
}

///|
test "region_growing_segmentation: 越界种子" {
  let image = make_medical_image(4, 4)
  let mask = region_growing_segmentation(image, 100, 100, 0, 50.0)
  let mut all_false = true
  for m in mask {
    if m {
      all_false = false
    }
  }
  assert_true(all_false)
}

///|
test "calculate_roi_stats: 基本统计" {
  let image = make_medical_image(8, 8)
  let mask = medical_threshold_segmentation(image, 50.0, 200.0)
  let (mean, std, count) = calculate_roi_stats(image, mask)
  assert_true(count > 0)
  assert_true(mean >= 0.0)
  assert_true(std >= 0.0)
}

///|
test "calculate_roi_stats: 空掩码" {
  let image = make_medical_image(4, 4)
  let mask : Array[Bool] = Array::make(16, false)
  let (mean, std, count) = calculate_roi_stats(image, mask)
  assert_eq(count, 0)
  assert_true(mean == 0.0)
  assert_true(std == 0.0)
}

///|
test "detect_lesions_simple: 基本病灶检测" {
  let image = make_medical_image(16, 16)
  let lesions = detect_lesions_simple(image, 0.0, 20.0)
  assert_true(lesions.length() >= 0)
}

///|
test "detect_lesions_simple: 无病灶" {
  let image = make_uniform_medical(16, 16, 50.0)
  let lesions = detect_lesions_simple(image, 0.0, 20.0)
  assert_eq(lesions.length(), 0)
}

///|
test "medical_image_registration: 相同图像" {
  let image = make_medical_image(8, 8)
  let result = medical_image_registration(image, image, 10)
  assert_true(result.iterations > 0)
  assert_eq(result.transformation.length(), 16)
  assert_true(result.similarity > 0.9)
}

///|
test "medical_image_registration: 不同图像" {
  let fixed = make_medical_image(8, 8)
  let moving = make_uniform_medical(8, 8, 128.0)
  let result = medical_image_registration(fixed, moving, 5)
  assert_true(result.iterations > 0)
  assert_eq(result.registration_type, "rigid")
}

///|
test "calculate_medical_image_quality: 基本质量评估" {
  let image = make_medical_image(8, 8)
  let quality = calculate_medical_image_quality(image)
  assert_true(quality.overall_quality >= 1.0 && quality.overall_quality <= 5.0)
  assert_true(quality.noise_level >= 0.0)
}

///|
test "calculate_medical_image_quality: 均匀图像" {
  let image = make_uniform_medical(8, 8, 100.0)
  let quality = calculate_medical_image_quality(image)
  assert_true(quality.snr >= 0.0)
}

///|
test "medical_image_report_to_string: 有病灶" {
  let image = make_medical_image(8, 8)
  let lesions : Array[Lesion] = [
    Lesion::{
      id: 0,
      lesion_type: "nodule",
      x: 4.0,
      y: 4.0,
      z: 0.0,
      diameter: 5.0,
      volume: 65.0,
      intensity: 200.0,
      margin: "well_defined",
      shape: "round",
      density: "solid",
      confidence: 0.8,
      birads_category: 3,
    },
  ]
  let quality = MedicalImageQuality::{
    snr: 15.0,
    cnr: 12.0,
    sharpness: 8.0,
    noise_level: 2.0,
    artifact_score: 1.0,
    overall_quality: 4.0,
  }
  let report = medical_image_report_to_string(image, lesions, quality)
  assert_true(report.contains("医学图像分析报告"))
  assert_true(report.contains("CT"))
  assert_true(report.contains("nodule"))
}

///|
test "medical_image_report_to_string: 无病灶" {
  let image = make_medical_image(4, 4)
  let lesions : Array[Lesion] = []
  let quality = MedicalImageQuality::{
    snr: 10.0,
    cnr: 8.0,
    sharpness: 5.0,
    noise_level: 3.0,
    artifact_score: 1.0,
    overall_quality: 3.0,
  }
  let report = medical_image_report_to_string(image, lesions, quality)
  assert_true(report.contains("医学图像分析报告"))
  assert_true(report.contains("未检测到明显病灶"))
}

///|
test "window_level_lung: 肺窗" {
  let wl = window_level_lung()
  assert_true(wl.window_width > 0.0)
}

///|
test "window_level_mediastinum: 纵隔窗" {
  let wl = window_level_mediastinum()
  assert_true(wl.window_width > 0.0)
}

///|
test "window_level_bone: 骨窗" {
  let wl = window_level_bone()
  assert_true(wl.window_width > 0.0)
}

///|
test "window_level_brain: 脑窗" {
  let wl = window_level_brain()
  assert_true(wl.window_width > 0.0)
}

///|
test "apply_window_level: 基本应用" {
  let img = make_gray_img(4, 4, b'\x80')
  let config = window_level_brain()
  let result = apply_window_level(img, config)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 1)
  assert_eq(result.data.length(), 16)
}

///|
test "medical_colormap: 基本伪彩色" {
  let img = make_gray_img(4, 4, b'\x80')
  let result = medical_colormap(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  assert_eq(result.data.length(), 48)
}

///|
test "medical_colormap: hot映射" {
  let img = make_gray_img(4, 4, b'\x40')
  let result = medical_colormap(img, colormap="hot")
  assert_eq(result.channels, 3)
}

///|
test "measure_distance: 基本距离" {
  let d = measure_distance(0, 0, 3, 4)
  assert_true((d - 5.0).abs() < 0.001)
}

///|
test "measure_distance: 零距离" {
  let d = measure_distance(5, 5, 5, 5)
  assert_true(d < 0.001)
}

///|
test "measure_area: 基本面积" {
  let mask = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Bytes::from_array(Array::make(16, b'\xFF')),
  }
  let area = measure_area(mask)
  assert_true(area > 0.0)
}
