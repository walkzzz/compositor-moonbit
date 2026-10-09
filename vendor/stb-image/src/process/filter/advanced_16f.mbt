// 高级算法 16-bit/float 变体（filter 包）
// inpaint / NLM 去噪 支持 Image16 / ImageF

// ========== 辅助函数 ==========

///|
fn read_u16_le_adv(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn write_u16_le_adv(buf : Array[Byte], offset : Int, val : Int) -> Unit {
  buf[offset] = (val & 0xFF).to_byte()
  buf[offset + 1] = ((val >> 8) & 0xFF).to_byte()
}

///|
fn read_float_le_adv(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
fn write_f32_le_adv(buf : Array[Byte], offset : Int, val : Float) -> Unit {
  let bits = val.reinterpret_as_int()
  buf[offset] = (bits & 0xFF).to_byte()
  buf[offset + 1] = ((bits >> 8) & 0xFF).to_byte()
  buf[offset + 2] = ((bits >> 16) & 0xFF).to_byte()
  buf[offset + 3] = ((bits >> 24) & 0xFF).to_byte()
}

///|
fn clamp_int_adv(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
fn img16_to_img8_adv(img : @types.Image16) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let v16 = read_u16_le_adv(img.data, i * 2)
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
fn imgf_to_img8_adv(img : @types.ImageF) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let vf = read_float_le_adv(img.data, i * 4)
    let v8 = clamp_int_adv((vf * 255.0F).to_int(), 0, 255)
    data8[i] = v8.to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data8),
  }
}

///|
fn img8_to_img16_adv(img : @types.Image) -> @types.Image16 {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let out : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  for i in 0..<(w * h * ch) {
    let v8 = img.data[i].to_int()
    write_u16_le_adv(out, i * 2, v8 * 257)
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
fn img8_to_imgf_adv(img : @types.Image) -> @types.ImageF {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let out : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  for i in 0..<(w * h * ch) {
    let v8 = img.data[i].to_int()
    write_f32_le_adv(out, i * 4, Float::from_int(v8) / 255.0F)
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== Inpaint 16-bit ==========

///|
/// 16-bit 图像修复。
pub fn inpaint_16(
  img : @types.Image16,
  mask : @types.Image16,
  iterations? : Int = 100,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "inpaint_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "inpaint_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "inpaint_16: 图像数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if mask.width != img.width || mask.height != img.height {
    raise @types.LoadError::DecodeFailed(
      "inpaint_16: 掩码图像尺寸必须与原图一致",
    )
  }
  if iterations <= 0 {
    raise @types.LoadError::DecodeFailed("inpaint_16: iterations必须大于0")
  }

  let img8 = img16_to_img8_adv(img)
  let mask8 = img16_to_img8_adv(mask)
  let out8 = inpaint(img8, mask8, iterations~)
  img8_to_img16_adv(out8)
}

///|
/// 16-bit 快速图像修复。
pub fn inpaint_fast_16(
  img : @types.Image16,
  mask : @types.Image16,
  radius? : Int = 5,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "inpaint_fast_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "inpaint_fast_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "inpaint_fast_16: 图像数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if mask.width != img.width || mask.height != img.height {
    raise @types.LoadError::DecodeFailed(
      "inpaint_fast_16: 掩码图像尺寸必须与原图一致",
    )
  }
  if radius <= 0 {
    raise @types.LoadError::DecodeFailed("inpaint_fast_16: radius必须大于0")
  }

  let img8 = img16_to_img8_adv(img)
  let mask8 = img16_to_img8_adv(mask)
  let out8 = inpaint_fast(img8, mask8, radius~)
  img8_to_img16_adv(out8)
}

// ========== Inpaint float ==========

///|
/// float 图像修复。
pub fn inpaint_f(
  img : @types.ImageF,
  mask : @types.ImageF,
  iterations? : Int = 100,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("inpaint_f: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "inpaint_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "inpaint_f: 图像数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if mask.width != img.width || mask.height != img.height {
    raise @types.LoadError::DecodeFailed(
      "inpaint_f: 掩码图像尺寸必须与原图一致",
    )
  }
  if iterations <= 0 {
    raise @types.LoadError::DecodeFailed("inpaint_f: iterations必须大于0")
  }

  let img8 = imgf_to_img8_adv(img)
  let mask8 = imgf_to_img8_adv(mask)
  let out8 = inpaint(img8, mask8, iterations~)
  img8_to_imgf_adv(out8)
}

///|
/// float 快速图像修复。
pub fn inpaint_fast_f(
  img : @types.ImageF,
  mask : @types.ImageF,
  radius? : Int = 5,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "inpaint_fast_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "inpaint_fast_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "inpaint_fast_f: 图像数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if mask.width != img.width || mask.height != img.height {
    raise @types.LoadError::DecodeFailed(
      "inpaint_fast_f: 掩码图像尺寸必须与原图一致",
    )
  }
  if radius <= 0 {
    raise @types.LoadError::DecodeFailed("inpaint_fast_f: radius必须大于0")
  }

  let img8 = imgf_to_img8_adv(img)
  let mask8 = imgf_to_img8_adv(mask)
  let out8 = inpaint_fast(img8, mask8, radius~)
  img8_to_imgf_adv(out8)
}

// ========== NLM 16-bit ==========

///|
/// 16-bit 非局部均值去噪。
pub fn nlm_denoise_16(
  img : @types.Image16,
  patch_size? : Int = 3,
  search_size? : Int = 7,
  h? : Int = 10,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if patch_size < 1 || patch_size > 10 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_16: patch_size必须在1-10之间",
    )
  }
  if search_size < 1 || search_size > 20 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_16: search_size必须在1-20之间",
    )
  }
  if h < 1 {
    raise @types.LoadError::DecodeFailed("nlm_denoise_16: h必须 >= 1")
  }

  let img8 = img16_to_img8_adv(img)
  let out8 = nlm_denoise(img8, patch_size~, search_size~, h~)
  img8_to_img16_adv(out8)
}

///|
/// 16-bit 快速非局部均值去噪。
pub fn nlm_denoise_fast_16(
  img : @types.Image16,
  patch_size? : Int = 3,
  search_size? : Int = 7,
  h? : Int = 10,
  step? : Int = 2,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_fast_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_fast_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_fast_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if patch_size < 1 || patch_size > 10 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_fast_16: patch_size必须在1-10之间",
    )
  }
  if search_size < 1 || search_size > 20 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_fast_16: search_size必须在1-20之间",
    )
  }
  if h < 1 {
    raise @types.LoadError::DecodeFailed("nlm_denoise_fast_16: h必须 >= 1")
  }
  if step < 1 || step > 5 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_fast_16: step必须在1-5之间",
    )
  }

  let img8 = img16_to_img8_adv(img)
  let out8 = nlm_denoise_fast(img8, patch_size~, search_size~, h~, step~)
  img8_to_img16_adv(out8)
}

// ========== NLM float ==========

///|
/// float 非局部均值去噪。
pub fn nlm_denoise_f(
  img : @types.ImageF,
  patch_size? : Int = 3,
  search_size? : Int = 7,
  h? : Int = 10,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if patch_size < 1 || patch_size > 10 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_f: patch_size必须在1-10之间",
    )
  }
  if search_size < 1 || search_size > 20 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_f: search_size必须在1-20之间",
    )
  }
  if h < 1 {
    raise @types.LoadError::DecodeFailed("nlm_denoise_f: h必须 >= 1")
  }

  let img8 = imgf_to_img8_adv(img)
  let out8 = nlm_denoise(img8, patch_size~, search_size~, h~)
  img8_to_imgf_adv(out8)
}

///|
/// float 快速非局部均值去噪。
pub fn nlm_denoise_fast_f(
  img : @types.ImageF,
  patch_size? : Int = 3,
  search_size? : Int = 7,
  h? : Int = 10,
  step? : Int = 2,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_fast_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_fast_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_fast_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if patch_size < 1 || patch_size > 10 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_fast_f: patch_size必须在1-10之间",
    )
  }
  if search_size < 1 || search_size > 20 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_fast_f: search_size必须在1-20之间",
    )
  }
  if h < 1 {
    raise @types.LoadError::DecodeFailed("nlm_denoise_fast_f: h必须 >= 1")
  }
  if step < 1 || step > 5 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_fast_f: step必须在1-5之间",
    )
  }

  let img8 = imgf_to_img8_adv(img)
  let out8 = nlm_denoise_fast(img8, patch_size~, search_size~, h~, step~)
  img8_to_imgf_adv(out8)
}
