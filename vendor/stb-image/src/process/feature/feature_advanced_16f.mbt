// 特征检测高级 16-bit/float 变体
// harris / sift / orb / shi_tomasi / gabor

// ========== 辅助函数 ==========

///|
fn read_u16_le_feat(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn read_float_le_feat(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
fn clamp_int_feat(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
fn img16_to_img8_feat(img : @types.Image16) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let v16 = read_u16_le_feat(img.data, i * 2)
    data8[i] = (v16 / 257).to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data8),
  }
}

///|
fn imgf_to_img8_feat(img : @types.ImageF) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let vf = read_float_le_feat(img.data, i * 4)
    let v8 = clamp_int_feat((vf * 255.0F).to_int(), 0, 255)
    data8[i] = v8.to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data8),
  }
}

// ========== Harris 16-bit ==========

///|
/// 16-bit Harris 角点检测。
pub fn harris_corners_16(
  img : @types.Image16,
  k? : Float = 0.04F,
  threshold? : Float = 1000.0F,
  min_distance? : Int = 5,
) -> Array[CornerPoint] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "harris_corners_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "harris_corners_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "harris_corners_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if k <= 0.0F {
    raise @types.LoadError::DecodeFailed("harris_corners_16: k必须大于0")
  }
  if threshold <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "harris_corners_16: threshold必须大于0",
    )
  }
  if min_distance <= 0 {
    raise @types.LoadError::DecodeFailed(
      "harris_corners_16: min_distance必须大于0",
    )
  }

  let img8 = img16_to_img8_feat(img)
  harris_corners(img8, k~, threshold~, min_distance~)
}

// ========== Harris float ==========

///|
/// float Harris 角点检测。
pub fn harris_corners_f(
  img : @types.ImageF,
  k? : Float = 0.04F,
  threshold? : Float = 1000.0F,
  min_distance? : Int = 5,
) -> Array[CornerPoint] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "harris_corners_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "harris_corners_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "harris_corners_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if k <= 0.0F {
    raise @types.LoadError::DecodeFailed("harris_corners_f: k必须大于0")
  }
  if threshold <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "harris_corners_f: threshold必须大于0",
    )
  }
  if min_distance <= 0 {
    raise @types.LoadError::DecodeFailed(
      "harris_corners_f: min_distance必须大于0",
    )
  }

  let img8 = imgf_to_img8_feat(img)
  harris_corners(img8, k~, threshold~, min_distance~)
}

// ========== SIFT 16-bit ==========

///|
/// 16-bit SIFT 特征检测。
pub fn sift_detect_16(
  img : @types.Image16,
  max_features? : Int = 500,
  contrast_threshold? : Float = 0.04F,
) -> Array[SiftDescriptor] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "sift_detect_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "sift_detect_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "sift_detect_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if max_features <= 0 {
    raise @types.LoadError::DecodeFailed(
      "sift_detect_16: max_features必须大于0",
    )
  }
  if contrast_threshold <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "sift_detect_16: contrast_threshold必须大于0",
    )
  }

  let img8 = img16_to_img8_feat(img)
  sift_detect(img8, max_features~, contrast_threshold~)
}

// ========== SIFT float ==========

///|
/// float SIFT 特征检测。
pub fn sift_detect_f(
  img : @types.ImageF,
  max_features? : Int = 500,
  contrast_threshold? : Float = 0.04F,
) -> Array[SiftDescriptor] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "sift_detect_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "sift_detect_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "sift_detect_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if max_features <= 0 {
    raise @types.LoadError::DecodeFailed(
      "sift_detect_f: max_features必须大于0",
    )
  }
  if contrast_threshold <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "sift_detect_f: contrast_threshold必须大于0",
    )
  }

  let img8 = imgf_to_img8_feat(img)
  sift_detect(img8, max_features~, contrast_threshold~)
}

// ========== ORB 16-bit ==========

///|
/// 16-bit ORB 特征检测。
pub fn orb_detect_16(
  img : @types.Image16,
  max_features? : Int = 500,
  threshold? : Int = 20,
) -> Array[OrbDescriptor] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "orb_detect_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "orb_detect_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "orb_detect_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if max_features <= 0 {
    raise @types.LoadError::DecodeFailed(
      "orb_detect_16: max_features必须大于0",
    )
  }
  if threshold <= 0 {
    raise @types.LoadError::DecodeFailed(
      "orb_detect_16: threshold必须大于0",
    )
  }

  let img8 = img16_to_img8_feat(img)
  orb_detect(img8, max_features~, threshold~)
}

// ========== ORB float ==========

///|
/// float ORB 特征检测。
pub fn orb_detect_f(
  img : @types.ImageF,
  max_features? : Int = 500,
  threshold? : Int = 20,
) -> Array[OrbDescriptor] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "orb_detect_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "orb_detect_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "orb_detect_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if max_features <= 0 {
    raise @types.LoadError::DecodeFailed(
      "orb_detect_f: max_features必须大于0",
    )
  }
  if threshold <= 0 {
    raise @types.LoadError::DecodeFailed("orb_detect_f: threshold必须大于0")
  }

  let img8 = imgf_to_img8_feat(img)
  orb_detect(img8, max_features~, threshold~)
}

// ========== Shi-Tomasi 16-bit ==========

///|
/// 16-bit Shi-Tomasi 角点检测。
pub fn good_features_to_track_16(
  img : @types.Image16,
  max_corners : Int,
  quality_level : Float,
  min_distance? : Int = 5,
) -> Array[CornerPoint] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "good_features_to_track_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "good_features_to_track_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "good_features_to_track_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if max_corners <= 0 {
    raise @types.LoadError::DecodeFailed(
      "good_features_to_track_16: max_corners必须大于0",
    )
  }
  if quality_level <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "good_features_to_track_16: quality_level必须大于0",
    )
  }
  if min_distance <= 0 {
    raise @types.LoadError::DecodeFailed(
      "good_features_to_track_16: min_distance必须大于0",
    )
  }

  let img8 = img16_to_img8_feat(img)
  good_features_to_track(img8, max_corners, quality_level, min_distance~)
}

// ========== Shi-Tomasi float ==========

///|
/// float Shi-Tomasi 角点检测。
pub fn good_features_to_track_f(
  img : @types.ImageF,
  max_corners : Int,
  quality_level : Float,
  min_distance? : Int = 5,
) -> Array[CornerPoint] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "good_features_to_track_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "good_features_to_track_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "good_features_to_track_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if max_corners <= 0 {
    raise @types.LoadError::DecodeFailed(
      "good_features_to_track_f: max_corners必须大于0",
    )
  }
  if quality_level <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "good_features_to_track_f: quality_level必须大于0",
    )
  }
  if min_distance <= 0 {
    raise @types.LoadError::DecodeFailed(
      "good_features_to_track_f: min_distance必须大于0",
    )
  }

  let img8 = imgf_to_img8_feat(img)
  good_features_to_track(img8, max_corners, quality_level, min_distance~)
}
