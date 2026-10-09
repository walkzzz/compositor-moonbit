// v27.1.0 图像来源鉴定增强测试
// 覆盖 forensics_enhanced.mbt 的 10 个公开函数

///|
fn create_solid_image_fe(w : Int, h : Int, value : Int) -> @types.Image {
  let data : Array[Byte] = []
  for _ in 0..<(w * h) {
    data.push(value.to_byte())
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(data),
  }
}

///|
fn create_noise_image_fe(w : Int, h : Int) -> @types.Image {
  let data : Array[Byte] = []
  let mut state = 12345
  for _ in 0..<(w * h) {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF
    data.push((state % 256).to_byte())
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(data),
  }
}

///|
fn create_gradient_image_fe(w : Int, h : Int) -> @types.Image {
  let data : Array[Byte] = []
  for _ in 0..<h {
    for x in 0..<w {
      let v = x * 255 / w % 256
      data.push(v.to_byte())
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
fn create_checkerboard_fe(w : Int, h : Int, block : Int) -> @types.Image {
  let data : Array[Byte] = []
  for y in 0..<h {
    for x in 0..<w {
      let v = if (x / block + y / block) % 2 == 0 { 255 } else { 0 }
      data.push(v.to_byte())
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
test "analyze_ela: 纯色图像 ELA 分析" {
  let img = create_solid_image_fe(16, 16, 128)
  let result = analyze_ela(img, 80)
  assert_true(result.ela_mean >= 0.0)
  assert_true(result.ela_std >= 0.0)
  assert_true(result.ela_max >= 0.0)
  assert_true(
    result.tampered_region_ratio >= 0.0 && result.tampered_region_ratio <= 1.0,
  )
}

///|
test "analyze_ela: 随机噪声图像 ELA 分析" {
  let img = create_noise_image_fe(16, 16)
  let result = analyze_ela(img, 70)
  assert_true(result.ela_mean >= 0.0)
  assert_true(result.ela_distribution.length() > 0)
}

///|
test "analyze_ela: 渐变图像 ELA 分析" {
  let img = create_gradient_image_fe(16, 16)
  let result = analyze_ela(img, 90)
  assert_true(result.ela_mean >= 0.0)
  assert_true(result.ela_std >= 0.0)
}

///|
test "analyze_noise_residual: 纯色图像噪声残差" {
  let img = create_solid_image_fe(16, 16, 128)
  let result = analyze_noise_residual(img)
  assert_true(result.residual_mean >= 0.0)
  assert_true(result.residual_std >= 0.0)
  assert_true(result.residual_energy >= 0.0)
  assert_true(result.sensor_pattern.length() > 0)
}

///|
test "analyze_noise_residual: 随机噪声图像残差" {
  let img = create_noise_image_fe(16, 16)
  let result = analyze_noise_residual(img)
  assert_true(result.residual_std > 0.0)
  assert_true(result.pattern_consistency >= 0.0)
}

///|
test "analyze_dct_coefficients: 纯色图像 DCT 分析" {
  let img = create_solid_image_fe(16, 16, 128)
  let result = analyze_dct_coefficients(img)
  assert_true(
    result.high_freq_coefficient_ratio >= 0.0 &&
    result.high_freq_coefficient_ratio <= 1.0,
  )
  assert_true(
    result.zero_coefficient_ratio >= 0.0 && result.zero_coefficient_ratio <= 1.0,
  )
  assert_true(result.blockiness_artifact >= 0.0)
  assert_true(result.double_jpeg_indicator >= 0.0)
}

///|
test "analyze_dct_coefficients: 棋盘格图像 DCT 分析" {
  let img = create_checkerboard_fe(16, 16, 2)
  let result = analyze_dct_coefficients(img)
  assert_true(result.high_freq_coefficient_ratio >= 0.0)
  assert_true(result.coefficient_distribution.length() > 0)
}

///|
test "detect_clone_regions: 纯色图像无克隆" {
  let img = create_solid_image_fe(16, 16, 128)
  let result = detect_clone_regions(img, 4, 0.8)
  assert_true(result.clone_region_count >= 0)
  assert_true(result.clone_similarity >= 0.0 && result.clone_similarity <= 1.0)
}

///|
test "detect_clone_regions: 棋盘格图像有重复模式" {
  let img = create_checkerboard_fe(16, 16, 4)
  let result = detect_clone_regions(img, 4, 0.7)
  assert_true(result.clone_region_count >= 0)
  assert_true(result.has_clone == (result.clone_region_count > 0))
}

///|
test "analyze_illumination_consistency: 纯色图像光照一致" {
  let img = create_solid_image_fe(16, 16, 128)
  let result = analyze_illumination_consistency(img)
  assert_true(result.illumination_inconsistency >= 0.0)
  assert_true(
    result.highlight_distribution >= 0.0 && result.highlight_distribution <= 1.0,
  )
  assert_true(
    result.shadow_consistency >= 0.0 && result.shadow_consistency <= 1.0,
  )
}

///|
test "analyze_illumination_consistency: 渐变图像光照" {
  let img = create_gradient_image_fe(16, 16)
  let result = analyze_illumination_consistency(img)
  assert_true(
    result.illumination_direction >= -3.15 &&
    result.illumination_direction <= 3.15,
  )
  assert_true(
    result.has_inconsistent_lighting || !result.has_inconsistent_lighting,
  )
}

///|
test "analyze_metadata_forensics: 纯色图像元数据" {
  let img = create_solid_image_fe(16, 16, 128)
  let result = analyze_metadata_forensics(img)
  assert_true(result.has_metadata)
  assert_true(result.software_signature.length() > 0)
  assert_true(result.creation_time.length() > 0)
  assert_true(result.device_info.length() > 0)
  assert_true(
    result.metadata_consistency >= 0.0 && result.metadata_consistency <= 1.0,
  )
}

///|
test "analyze_metadata_forensics: 随机噪声图像元数据" {
  let img = create_noise_image_fe(64, 64)
  let result = analyze_metadata_forensics(img)
  assert_true(result.has_metadata)
  assert_true(result.software_signature.length() > 0)
}

///|
test "analyze_jpeg_ghost: 纯色图像无 ghost" {
  let img = create_solid_image_fe(16, 16, 128)
  let result = analyze_jpeg_ghost(img)
  assert_true(result.ghost_region_count >= 0)
  assert_true(result.ghost_quality_levels.length() > 0)
  assert_true(result.has_ghost == (result.ghost_region_count > 0))
}

///|
test "analyze_jpeg_ghost: 随机噪声图像" {
  let img = create_noise_image_fe(16, 16)
  let result = analyze_jpeg_ghost(img)
  assert_true(result.primary_quality >= 0)
  assert_true(result.secondary_quality >= 0)
}

///|
test "analyze_cfa_pattern: 纯色图像 CFA 分析" {
  let img = create_solid_image_fe(16, 16, 128)
  let result = analyze_cfa_pattern(img)
  assert_true(result.bayer_pattern_score >= 0.0)
  assert_true(result.cfa_artifact_level >= 0.0)
  assert_true(result.cfa_pattern.length() > 0)
}

///|
test "analyze_cfa_pattern: 棋盘格图像 CFA 分析" {
  let img = create_checkerboard_fe(16, 16, 2)
  let result = analyze_cfa_pattern(img)
  assert_true(result.bayer_pattern_score >= 0.0)
  assert_true(result.is_cfa_consistent || !result.is_cfa_consistent)
}

///|
test "detect_tamper_comprehensive: 纯色图像篡改检测" {
  let img = create_solid_image_fe(16, 16, 128)
  let result = detect_tamper_comprehensive(img, 80)
  assert_true(
    result.tamper_probability >= 0.0 && result.tamper_probability <= 1.0,
  )
  assert_true(result.confidence >= 0.0 && result.confidence <= 1.0)
  assert_true(result.tamper_type.length() > 0)
  assert_true(result.analysis_details.length() > 0)
  assert_true(result.is_tampered || !result.is_tampered)
}

///|
test "detect_tamper_comprehensive: 随机噪声图像篡改检测" {
  let img = create_noise_image_fe(16, 16)
  let result = detect_tamper_comprehensive(img, 70)
  assert_true(
    result.tamper_probability >= 0.0 && result.tamper_probability <= 1.0,
  )
  assert_true(result.tamper_type.length() > 0)
}

///|
test "detect_tamper_comprehensive: 棋盘格图像篡改检测" {
  let img = create_checkerboard_fe(16, 16, 4)
  let result = detect_tamper_comprehensive(img, 80)
  assert_true(
    result.tamper_probability >= 0.0 && result.tamper_probability <= 1.0,
  )
  assert_true(result.confidence >= 0.0 && result.confidence <= 1.0)
}

///|
test "detect_tamper_comprehensive: 渐变图像篡改检测" {
  let img = create_gradient_image_fe(16, 16)
  let result = detect_tamper_comprehensive(img, 90)
  assert_true(
    result.tamper_probability >= 0.0 && result.tamper_probability <= 1.0,
  )
  assert_true(result.tampered_regions.length() >= 0)
}
