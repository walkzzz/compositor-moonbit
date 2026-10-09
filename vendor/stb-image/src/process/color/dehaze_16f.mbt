// 去雾 16-bit/float 变体（color 包）
// dehaze / guided_filter 支持 Image16 / ImageF

// ========== 辅助函数 ==========

///|
fn read_u16_le_dh(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn write_u16_le_dh(buf : Array[Byte], offset : Int, val : Int) -> Unit {
  buf[offset] = (val & 0xFF).to_byte()
  buf[offset + 1] = ((val >> 8) & 0xFF).to_byte()
}

///|
fn read_float_le_dh(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
fn write_f32_le_dh(buf : Array[Byte], offset : Int, val : Float) -> Unit {
  let bits = val.reinterpret_as_int()
  buf[offset] = (bits & 0xFF).to_byte()
  buf[offset + 1] = ((bits >> 8) & 0xFF).to_byte()
  buf[offset + 2] = ((bits >> 16) & 0xFF).to_byte()
  buf[offset + 3] = ((bits >> 24) & 0xFF).to_byte()
}

///|
fn clamp_int_dh(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
fn img16_to_img8_dh(img : @types.Image16) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let v16 = read_u16_le_dh(img.data, i * 2)
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
fn imgf_to_img8_dh(img : @types.ImageF) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let vf = read_float_le_dh(img.data, i * 4)
    let v8 = clamp_int_dh((vf * 255.0F).to_int(), 0, 255)
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
fn img8_to_img16_dh(img : @types.Image) -> @types.Image16 {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let out : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  for i in 0..<(w * h * ch) {
    let v8 = img.data[i].to_int()
    write_u16_le_dh(out, i * 2, v8 * 257)
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
fn img8_to_imgf_dh(img : @types.Image) -> @types.ImageF {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let out : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  for i in 0..<(w * h * ch) {
    let v8 = img.data[i].to_int()
    write_f32_le_dh(out, i * 4, Float::from_int(v8) / 255.0F)
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== Dehaze 16-bit ==========

///|
/// 16-bit 图像去雾。
pub fn dehaze_16(
  img : @types.Image16,
  patch_size? : Int = 7,
  omega? : Float = 0.95F,
  t0? : Float = 0.1F,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("dehaze_16: 图像尺寸必须大于0")
  }
  if img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "dehaze_16: 仅支持RGB/RGBA图像（channels=3/4）",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "dehaze_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let img8 = img16_to_img8_dh(img)
  let out8 = dehaze(img8, patch_size~, omega~, t0~)
  img8_to_img16_dh(out8)
}

// ========== Dehaze float ==========

///|
/// float 图像去雾。
pub fn dehaze_f(
  img : @types.ImageF,
  patch_size? : Int = 7,
  omega? : Float = 0.95F,
  t0? : Float = 0.1F,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("dehaze_f: 图像尺寸必须大于0")
  }
  if img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "dehaze_f: 仅支持RGB/RGBA图像（channels=3/4）",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "dehaze_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let img8 = imgf_to_img8_dh(img)
  let out8 = dehaze(img8, patch_size~, omega~, t0~)
  img8_to_imgf_dh(out8)
}

// ========== Guided Filter 16-bit ==========

///|
/// 16-bit 引导滤波。
pub fn guided_filter_16(
  img : @types.Image16,
  input : Array[Float],
  radius? : Int = 20,
  eps? : Float = 0.001F,
) -> Array[Float] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "guided_filter_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "guided_filter_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "guided_filter_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if radius < 1 {
    raise @types.LoadError::DecodeFailed("guided_filter_16: radius必须>=1")
  }
  if eps <= 0.0F {
    raise @types.LoadError::DecodeFailed("guided_filter_16: eps必须大于0")
  }
  let img8 = img16_to_img8_dh(img)
  guided_filter(img8, input, radius~, eps~)
}

// ========== Guided Filter float ==========

///|
/// float 引导滤波。
pub fn guided_filter_f(
  img : @types.ImageF,
  input : Array[Float],
  radius? : Int = 20,
  eps? : Float = 0.001F,
) -> Array[Float] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "guided_filter_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "guided_filter_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "guided_filter_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if radius < 1 {
    raise @types.LoadError::DecodeFailed("guided_filter_f: radius必须>=1")
  }
  if eps <= 0.0F {
    raise @types.LoadError::DecodeFailed("guided_filter_f: eps必须大于0")
  }
  let img8 = imgf_to_img8_dh(img)
  guided_filter(img8, input, radius~, eps~)
}
