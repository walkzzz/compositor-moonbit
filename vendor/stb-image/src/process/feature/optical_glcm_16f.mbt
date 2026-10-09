// 光流 + GLCM 16-bit/float 变体

// ========== 辅助函数 ==========

///|
fn read_u16_le_of(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn read_float_le_of(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
fn clamp_int_of(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
fn img16_to_img8_of(img : @types.Image16) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let v16 = read_u16_le_of(img.data, i * 2)
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
fn imgf_to_img8_of(img : @types.ImageF) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let vf = read_float_le_of(img.data, i * 4)
    let v8 = clamp_int_of((vf * 255.0F).to_int(), 0, 255)
    data8[i] = v8.to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data8),
  }
}

// ========== Lucas-Kanade 16-bit ==========

///|
/// 16-bit Lucas-Kanade 光流。
pub fn lucas_kanade_16(
  prev : @types.Image16,
  next : @types.Image16,
  points : Array[(Int, Int)],
  window_size? : Int = 15,
  max_iter? : Int = 20,
) -> Array[FlowResult] raise @types.LoadError {
  // 输入验证
  if prev.width <= 0 || prev.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_16: 前一帧图像尺寸必须大于0",
    )
  }
  if prev.channels < 1 || prev.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_16: 前一帧通道数必须在1-4之间",
    )
  }
  let prev_expected_size = prev.width * prev.height * prev.channels * 2
  if prev.data.length() != prev_expected_size {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_16: 前一帧数据大小不匹配，期望 " +
      prev_expected_size.to_string() +
      "，实际 " +
      prev.data.length().to_string(),
    )
  }
  if next.width <= 0 || next.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_16: 后一帧图像尺寸必须大于0",
    )
  }
  if next.channels < 1 || next.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_16: 后一帧通道数必须在1-4之间",
    )
  }
  let next_expected_size = next.width * next.height * next.channels * 2
  if next.data.length() != next_expected_size {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_16: 后一帧数据大小不匹配，期望 " +
      next_expected_size.to_string() +
      "，实际 " +
      next.data.length().to_string(),
    )
  }
  if prev.width != next.width || prev.height != next.height {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_16: 两帧图像尺寸必须一致",
    )
  }
  if points.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_16: 点列表不能为空",
    )
  }
  if window_size <= 0 || window_size % 2 == 0 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_16: window_size必须为正奇数",
    )
  }
  if max_iter <= 0 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_16: max_iter必须大于0",
    )
  }

  let prev8 = img16_to_img8_of(prev)
  let next8 = img16_to_img8_of(next)
  lucas_kanade(prev8, next8, points, window_size~, max_iter~)
}

// ========== Lucas-Kanade float ==========

///|
/// float Lucas-Kanade 光流。
pub fn lucas_kanade_f(
  prev : @types.ImageF,
  next : @types.ImageF,
  points : Array[(Int, Int)],
  window_size? : Int = 15,
  max_iter? : Int = 20,
) -> Array[FlowResult] raise @types.LoadError {
  // 输入验证
  if prev.width <= 0 || prev.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_f: 前一帧图像尺寸必须大于0",
    )
  }
  if prev.channels < 1 || prev.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_f: 前一帧通道数必须在1-4之间",
    )
  }
  let prev_expected_size = prev.width * prev.height * prev.channels * 4
  if prev.data.length() != prev_expected_size {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_f: 前一帧数据大小不匹配，期望 " +
      prev_expected_size.to_string() +
      "，实际 " +
      prev.data.length().to_string(),
    )
  }
  if next.width <= 0 || next.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_f: 后一帧图像尺寸必须大于0",
    )
  }
  if next.channels < 1 || next.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_f: 后一帧通道数必须在1-4之间",
    )
  }
  let next_expected_size = next.width * next.height * next.channels * 4
  if next.data.length() != next_expected_size {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_f: 后一帧数据大小不匹配，期望 " +
      next_expected_size.to_string() +
      "，实际 " +
      next.data.length().to_string(),
    )
  }
  if prev.width != next.width || prev.height != next.height {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_f: 两帧图像尺寸必须一致",
    )
  }
  if points.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_f: 点列表不能为空",
    )
  }
  if window_size <= 0 || window_size % 2 == 0 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_f: window_size必须为正奇数",
    )
  }
  if max_iter <= 0 {
    raise @types.LoadError::DecodeFailed(
      "lucas_kanade_f: max_iter必须大于0",
    )
  }

  let prev8 = imgf_to_img8_of(prev)
  let next8 = imgf_to_img8_of(next)
  lucas_kanade(prev8, next8, points, window_size~, max_iter~)
}

// ========== Horn-Schunck 16-bit ==========

///|
/// 16-bit Horn-Schunck 密集光流。
pub fn horn_schunck_16(
  prev : @types.Image16,
  next : @types.Image16,
  alpha? : Float = 1.0F,
  iterations? : Int = 100,
) -> (Array[Float], Array[Float]) raise @types.LoadError {
  // 输入验证
  if prev.width <= 0 || prev.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck_16: 前一帧图像尺寸必须大于0",
    )
  }
  if prev.channels < 1 || prev.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck_16: 前一帧通道数必须在1-4之间",
    )
  }
  let prev_expected_size = prev.width * prev.height * prev.channels * 2
  if prev.data.length() != prev_expected_size {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck_16: 前一帧数据大小不匹配，期望 " +
      prev_expected_size.to_string() +
      "，实际 " +
      prev.data.length().to_string(),
    )
  }
  if next.width <= 0 || next.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck_16: 后一帧图像尺寸必须大于0",
    )
  }
  if next.channels < 1 || next.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck_16: 后一帧通道数必须在1-4之间",
    )
  }
  let next_expected_size = next.width * next.height * next.channels * 2
  if next.data.length() != next_expected_size {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck_16: 后一帧数据大小不匹配，期望 " +
      next_expected_size.to_string() +
      "，实际 " +
      next.data.length().to_string(),
    )
  }
  if prev.width != next.width || prev.height != next.height {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck_16: 两帧图像尺寸必须一致",
    )
  }
  if alpha <= 0.0F {
    raise @types.LoadError::DecodeFailed("horn_schunck_16: alpha必须大于0")
  }
  if iterations <= 0 {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck_16: iterations必须大于0",
    )
  }

  let prev8 = img16_to_img8_of(prev)
  let next8 = img16_to_img8_of(next)
  horn_schunck(prev8, next8, alpha~, iterations~)
}

// ========== Horn-Schunck float ==========

///|
/// float Horn-Schunck 密集光流。
pub fn horn_schunck_f(
  prev : @types.ImageF,
  next : @types.ImageF,
  alpha? : Float = 1.0F,
  iterations? : Int = 100,
) -> (Array[Float], Array[Float]) raise @types.LoadError {
  // 输入验证
  if prev.width <= 0 || prev.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck_f: 前一帧图像尺寸必须大于0",
    )
  }
  if prev.channels < 1 || prev.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck_f: 前一帧通道数必须在1-4之间",
    )
  }
  let prev_expected_size = prev.width * prev.height * prev.channels * 4
  if prev.data.length() != prev_expected_size {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck_f: 前一帧数据大小不匹配，期望 " +
      prev_expected_size.to_string() +
      "，实际 " +
      prev.data.length().to_string(),
    )
  }
  if next.width <= 0 || next.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck_f: 后一帧图像尺寸必须大于0",
    )
  }
  if next.channels < 1 || next.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck_f: 后一帧通道数必须在1-4之间",
    )
  }
  let next_expected_size = next.width * next.height * next.channels * 4
  if next.data.length() != next_expected_size {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck_f: 后一帧数据大小不匹配，期望 " +
      next_expected_size.to_string() +
      "，实际 " +
      next.data.length().to_string(),
    )
  }
  if prev.width != next.width || prev.height != next.height {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck_f: 两帧图像尺寸必须一致",
    )
  }
  if alpha <= 0.0F {
    raise @types.LoadError::DecodeFailed("horn_schunck_f: alpha必须大于0")
  }
  if iterations <= 0 {
    raise @types.LoadError::DecodeFailed(
      "horn_schunck_f: iterations必须大于0",
    )
  }

  let prev8 = imgf_to_img8_of(prev)
  let next8 = imgf_to_img8_of(next)
  horn_schunck(prev8, next8, alpha~, iterations~)
}

// ========== GLCM 16-bit ==========

///|
/// 16-bit 灰度共生矩阵。
pub fn compute_glcm_16(
  img : @types.Image16,
  dx : Int,
  dy : Int,
  levels? : Int = 256,
) -> Array[Array[Int]] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "compute_glcm_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "compute_glcm_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "compute_glcm_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if levels <= 0 {
    raise @types.LoadError::DecodeFailed("compute_glcm_16: levels必须大于0")
  }

  let img8 = img16_to_img8_of(img)
  compute_glcm(img8, dx, dy, levels~)
}

// ========== GLCM float ==========

///|
/// float 灰度共生矩阵。
pub fn compute_glcm_f(
  img : @types.ImageF,
  dx : Int,
  dy : Int,
  levels? : Int = 256,
) -> Array[Array[Int]] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "compute_glcm_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "compute_glcm_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "compute_glcm_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if levels <= 0 {
    raise @types.LoadError::DecodeFailed("compute_glcm_f: levels必须大于0")
  }

  let img8 = imgf_to_img8_of(img)
  compute_glcm(img8, dx, dy, levels~)
}

// ========== GLCM Features Multi Direction 16-bit ==========

///|
/// 16-bit 多方向 GLCM 特征。
pub fn glcm_features_multi_direction_16(
  img : @types.Image16,
  levels? : Int = 256,
) -> Array[GlcmFeatures] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "glcm_features_multi_direction_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "glcm_features_multi_direction_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "glcm_features_multi_direction_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if levels <= 0 {
    raise @types.LoadError::DecodeFailed(
      "glcm_features_multi_direction_16: levels必须大于0",
    )
  }

  let img8 = img16_to_img8_of(img)
  glcm_features_multi_direction(img8, levels~)
}

// ========== GLCM Features Multi Direction float ==========

///|
/// float 多方向 GLCM 特征。
pub fn glcm_features_multi_direction_f(
  img : @types.ImageF,
  levels? : Int = 256,
) -> Array[GlcmFeatures] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "glcm_features_multi_direction_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "glcm_features_multi_direction_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "glcm_features_multi_direction_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if levels <= 0 {
    raise @types.LoadError::DecodeFailed(
      "glcm_features_multi_direction_f: levels必须大于0",
    )
  }

  let img8 = imgf_to_img8_of(img)
  glcm_features_multi_direction(img8, levels~)
}
