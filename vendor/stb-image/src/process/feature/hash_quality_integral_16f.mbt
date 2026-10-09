// 图像哈希 + 图像质量 + 积分图像 16-bit/float 变体

// ========== 辅助函数 ==========

///|
fn read_u16_le_iq(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn read_float_le_iq(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
fn clamp_int_iq(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
fn img16_to_img8_iq(img : @types.Image16) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let v16 = read_u16_le_iq(img.data, i * 2)
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
fn imgf_to_img8_iq(img : @types.ImageF) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let vf = read_float_le_iq(img.data, i * 4)
    let v8 = clamp_int_iq((vf * 255.0F).to_int(), 0, 255)
    data8[i] = v8.to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data8),
  }
}

// ========== 图像哈希 16-bit ==========

///|
/// 16-bit 平均哈希。
pub fn ahash_16(img : @types.Image16) -> Array[Int] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("ahash_16: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "ahash_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "ahash_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let img8 = img16_to_img8_iq(img)
  ahash(img8)
}

///|
/// 16-bit 差异哈希。
pub fn dhash_16(img : @types.Image16) -> Array[Int] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("dhash_16: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "dhash_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "dhash_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let img8 = img16_to_img8_iq(img)
  dhash(img8)
}

///|
/// 16-bit 感知哈希。
pub fn phash_16(img : @types.Image16) -> Array[Int] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("phash_16: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "phash_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "phash_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let img8 = img16_to_img8_iq(img)
  phash(img8)
}

// ========== 图像哈希 float ==========

///|
/// float 平均哈希。
pub fn ahash_f(img : @types.ImageF) -> Array[Int] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("ahash_f: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed("ahash_f: 通道数必须在1-4之间")
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "ahash_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let img8 = imgf_to_img8_iq(img)
  ahash(img8)
}

///|
/// float 差异哈希。
pub fn dhash_f(img : @types.ImageF) -> Array[Int] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("dhash_f: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed("dhash_f: 通道数必须在1-4之间")
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "dhash_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let img8 = imgf_to_img8_iq(img)
  dhash(img8)
}

///|
/// float 感知哈希。
pub fn phash_f(img : @types.ImageF) -> Array[Int] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("phash_f: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed("phash_f: 通道数必须在1-4之间")
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "phash_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let img8 = imgf_to_img8_iq(img)
  phash(img8)
}

// ========== 图像质量 16-bit ==========

///|
/// 16-bit 均方误差。
pub fn mse_16(
  img1 : @types.Image16,
  img2 : @types.Image16,
) -> Double raise @types.LoadError {
  // 输入验证
  if img1.width <= 0 || img1.height <= 0 {
    raise @types.LoadError::DecodeFailed("mse_16: 图像1尺寸必须大于0")
  }
  if img1.channels < 1 || img1.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "mse_16: 图像1通道数必须在1-4之间",
    )
  }
  let img1_expected_size = img1.width * img1.height * img1.channels * 2
  if img1.data.length() != img1_expected_size {
    raise @types.LoadError::DecodeFailed(
      "mse_16: 图像1数据大小不匹配，期望 " +
      img1_expected_size.to_string() +
      "，实际 " +
      img1.data.length().to_string(),
    )
  }
  if img2.width <= 0 || img2.height <= 0 {
    raise @types.LoadError::DecodeFailed("mse_16: 图像2尺寸必须大于0")
  }
  if img2.channels < 1 || img2.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "mse_16: 图像2通道数必须在1-4之间",
    )
  }
  let img2_expected_size = img2.width * img2.height * img2.channels * 2
  if img2.data.length() != img2_expected_size {
    raise @types.LoadError::DecodeFailed(
      "mse_16: 图像2数据大小不匹配，期望 " +
      img2_expected_size.to_string() +
      "，实际 " +
      img2.data.length().to_string(),
    )
  }
  if img1.width != img2.width || img1.height != img2.height {
    raise @types.LoadError::DecodeFailed("mse_16: 两图像尺寸必须一致")
  }

  let img1_8 = img16_to_img8_iq(img1)
  let img2_8 = img16_to_img8_iq(img2)
  mse(img1_8, img2_8)
}

///|
/// 16-bit 峰值信噪比。
pub fn psnr_16(
  img1 : @types.Image16,
  img2 : @types.Image16,
) -> Double raise @types.LoadError {
  // 输入验证
  if img1.width <= 0 || img1.height <= 0 {
    raise @types.LoadError::DecodeFailed("psnr_16: 图像1尺寸必须大于0")
  }
  if img1.channels < 1 || img1.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "psnr_16: 图像1通道数必须在1-4之间",
    )
  }
  let img1_expected_size = img1.width * img1.height * img1.channels * 2
  if img1.data.length() != img1_expected_size {
    raise @types.LoadError::DecodeFailed(
      "psnr_16: 图像1数据大小不匹配，期望 " +
      img1_expected_size.to_string() +
      "，实际 " +
      img1.data.length().to_string(),
    )
  }
  if img2.width <= 0 || img2.height <= 0 {
    raise @types.LoadError::DecodeFailed("psnr_16: 图像2尺寸必须大于0")
  }
  if img2.channels < 1 || img2.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "psnr_16: 图像2通道数必须在1-4之间",
    )
  }
  let img2_expected_size = img2.width * img2.height * img2.channels * 2
  if img2.data.length() != img2_expected_size {
    raise @types.LoadError::DecodeFailed(
      "psnr_16: 图像2数据大小不匹配，期望 " +
      img2_expected_size.to_string() +
      "，实际 " +
      img2.data.length().to_string(),
    )
  }
  if img1.width != img2.width || img1.height != img2.height {
    raise @types.LoadError::DecodeFailed("psnr_16: 两图像尺寸必须一致")
  }

  let img1_8 = img16_to_img8_iq(img1)
  let img2_8 = img16_to_img8_iq(img2)
  psnr(img1_8, img2_8)
}

///|
/// 16-bit 结构相似性。
pub fn ssim_16(
  img1 : @types.Image16,
  img2 : @types.Image16,
) -> Double raise @types.LoadError {
  // 输入验证
  if img1.width <= 0 || img1.height <= 0 {
    raise @types.LoadError::DecodeFailed("ssim_16: 图像1尺寸必须大于0")
  }
  if img1.channels < 1 || img1.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "ssim_16: 图像1通道数必须在1-4之间",
    )
  }
  let img1_expected_size = img1.width * img1.height * img1.channels * 2
  if img1.data.length() != img1_expected_size {
    raise @types.LoadError::DecodeFailed(
      "ssim_16: 图像1数据大小不匹配，期望 " +
      img1_expected_size.to_string() +
      "，实际 " +
      img1.data.length().to_string(),
    )
  }
  if img2.width <= 0 || img2.height <= 0 {
    raise @types.LoadError::DecodeFailed("ssim_16: 图像2尺寸必须大于0")
  }
  if img2.channels < 1 || img2.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "ssim_16: 图像2通道数必须在1-4之间",
    )
  }
  let img2_expected_size = img2.width * img2.height * img2.channels * 2
  if img2.data.length() != img2_expected_size {
    raise @types.LoadError::DecodeFailed(
      "ssim_16: 图像2数据大小不匹配，期望 " +
      img2_expected_size.to_string() +
      "，实际 " +
      img2.data.length().to_string(),
    )
  }
  if img1.width != img2.width || img1.height != img2.height {
    raise @types.LoadError::DecodeFailed("ssim_16: 两图像尺寸必须一致")
  }

  let img1_8 = img16_to_img8_iq(img1)
  let img2_8 = img16_to_img8_iq(img2)
  ssim(img1_8, img2_8)
}

// ========== 图像质量 float ==========

///|
/// float 均方误差。
pub fn mse_f(
  img1 : @types.ImageF,
  img2 : @types.ImageF,
) -> Double raise @types.LoadError {
  // 输入验证
  if img1.width <= 0 || img1.height <= 0 {
    raise @types.LoadError::DecodeFailed("mse_f: 图像1尺寸必须大于0")
  }
  if img1.channels < 1 || img1.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "mse_f: 图像1通道数必须在1-4之间",
    )
  }
  let img1_expected_size = img1.width * img1.height * img1.channels * 4
  if img1.data.length() != img1_expected_size {
    raise @types.LoadError::DecodeFailed(
      "mse_f: 图像1数据大小不匹配，期望 " +
      img1_expected_size.to_string() +
      "，实际 " +
      img1.data.length().to_string(),
    )
  }
  if img2.width <= 0 || img2.height <= 0 {
    raise @types.LoadError::DecodeFailed("mse_f: 图像2尺寸必须大于0")
  }
  if img2.channels < 1 || img2.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "mse_f: 图像2通道数必须在1-4之间",
    )
  }
  let img2_expected_size = img2.width * img2.height * img2.channels * 4
  if img2.data.length() != img2_expected_size {
    raise @types.LoadError::DecodeFailed(
      "mse_f: 图像2数据大小不匹配，期望 " +
      img2_expected_size.to_string() +
      "，实际 " +
      img2.data.length().to_string(),
    )
  }
  if img1.width != img2.width || img1.height != img2.height {
    raise @types.LoadError::DecodeFailed("mse_f: 两图像尺寸必须一致")
  }

  let img1_8 = imgf_to_img8_iq(img1)
  let img2_8 = imgf_to_img8_iq(img2)
  mse(img1_8, img2_8)
}

///|
/// float 峰值信噪比。
pub fn psnr_f(
  img1 : @types.ImageF,
  img2 : @types.ImageF,
) -> Double raise @types.LoadError {
  // 输入验证
  if img1.width <= 0 || img1.height <= 0 {
    raise @types.LoadError::DecodeFailed("psnr_f: 图像1尺寸必须大于0")
  }
  if img1.channels < 1 || img1.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "psnr_f: 图像1通道数必须在1-4之间",
    )
  }
  let img1_expected_size = img1.width * img1.height * img1.channels * 4
  if img1.data.length() != img1_expected_size {
    raise @types.LoadError::DecodeFailed(
      "psnr_f: 图像1数据大小不匹配，期望 " +
      img1_expected_size.to_string() +
      "，实际 " +
      img1.data.length().to_string(),
    )
  }
  if img2.width <= 0 || img2.height <= 0 {
    raise @types.LoadError::DecodeFailed("psnr_f: 图像2尺寸必须大于0")
  }
  if img2.channels < 1 || img2.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "psnr_f: 图像2通道数必须在1-4之间",
    )
  }
  let img2_expected_size = img2.width * img2.height * img2.channels * 4
  if img2.data.length() != img2_expected_size {
    raise @types.LoadError::DecodeFailed(
      "psnr_f: 图像2数据大小不匹配，期望 " +
      img2_expected_size.to_string() +
      "，实际 " +
      img2.data.length().to_string(),
    )
  }
  if img1.width != img2.width || img1.height != img2.height {
    raise @types.LoadError::DecodeFailed("psnr_f: 两图像尺寸必须一致")
  }

  let img1_8 = imgf_to_img8_iq(img1)
  let img2_8 = imgf_to_img8_iq(img2)
  psnr(img1_8, img2_8)
}

///|
/// float 结构相似性。
pub fn ssim_f(
  img1 : @types.ImageF,
  img2 : @types.ImageF,
) -> Double raise @types.LoadError {
  // 输入验证
  if img1.width <= 0 || img1.height <= 0 {
    raise @types.LoadError::DecodeFailed("ssim_f: 图像1尺寸必须大于0")
  }
  if img1.channels < 1 || img1.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "ssim_f: 图像1通道数必须在1-4之间",
    )
  }
  let img1_expected_size = img1.width * img1.height * img1.channels * 4
  if img1.data.length() != img1_expected_size {
    raise @types.LoadError::DecodeFailed(
      "ssim_f: 图像1数据大小不匹配，期望 " +
      img1_expected_size.to_string() +
      "，实际 " +
      img1.data.length().to_string(),
    )
  }
  if img2.width <= 0 || img2.height <= 0 {
    raise @types.LoadError::DecodeFailed("ssim_f: 图像2尺寸必须大于0")
  }
  if img2.channels < 1 || img2.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "ssim_f: 图像2通道数必须在1-4之间",
    )
  }
  let img2_expected_size = img2.width * img2.height * img2.channels * 4
  if img2.data.length() != img2_expected_size {
    raise @types.LoadError::DecodeFailed(
      "ssim_f: 图像2数据大小不匹配，期望 " +
      img2_expected_size.to_string() +
      "，实际 " +
      img2.data.length().to_string(),
    )
  }
  if img1.width != img2.width || img1.height != img2.height {
    raise @types.LoadError::DecodeFailed("ssim_f: 两图像尺寸必须一致")
  }

  let img1_8 = imgf_to_img8_iq(img1)
  let img2_8 = imgf_to_img8_iq(img2)
  ssim(img1_8, img2_8)
}

// ========== 积分图像 16-bit ==========

///|
/// 16-bit 积分图像。
pub fn integral_image_16(
  img : @types.Image16,
) -> IntegralImage raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "integral_image_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "integral_image_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "integral_image_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let img8 = img16_to_img8_iq(img)
  integral_image(img8)
}

///|
/// 16-bit 平方积分图像。
pub fn integral_image_sq_16(
  img : @types.Image16,
) -> IntegralImageSq raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "integral_image_sq_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "integral_image_sq_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "integral_image_sq_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let img8 = img16_to_img8_iq(img)
  integral_image_sq(img8)
}

// ========== 积分图像 float ==========

///|
/// float 积分图像。
pub fn integral_image_f(
  img : @types.ImageF,
) -> IntegralImage raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "integral_image_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "integral_image_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "integral_image_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let img8 = imgf_to_img8_iq(img)
  integral_image(img8)
}

///|
/// float 平方积分图像。
pub fn integral_image_sq_f(
  img : @types.ImageF,
) -> IntegralImageSq raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "integral_image_sq_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "integral_image_sq_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "integral_image_sq_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let img8 = imgf_to_img8_iq(img)
  integral_image_sq(img8)
}
