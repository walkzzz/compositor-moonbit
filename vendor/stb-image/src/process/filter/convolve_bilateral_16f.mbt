// 卷积 + 双边滤波 16-bit/float 变体

// ========== 辅助函数 ==========

///|
fn read_u16_le_cb(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn write_u16_le_cb(buf : Array[Byte], offset : Int, val : Int) -> Unit {
  buf[offset] = (val & 0xFF).to_byte()
  buf[offset + 1] = ((val >> 8) & 0xFF).to_byte()
}

///|
fn read_float_le_cb(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
fn write_f32_le_cb(buf : Array[Byte], offset : Int, val : Float) -> Unit {
  let bits = val.reinterpret_as_int()
  buf[offset] = (bits & 0xFF).to_byte()
  buf[offset + 1] = ((bits >> 8) & 0xFF).to_byte()
  buf[offset + 2] = ((bits >> 16) & 0xFF).to_byte()
  buf[offset + 3] = ((bits >> 24) & 0xFF).to_byte()
}

///|
fn clamp_int_cb(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
fn img16_to_img8_cb(img : @types.Image16) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let v16 = read_u16_le_cb(img.data, i * 2)
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
fn imgf_to_img8_cb(img : @types.ImageF) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data8 : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    let vf = read_float_le_cb(img.data, i * 4)
    let v8 = clamp_int_cb((vf * 255.0F).to_int(), 0, 255)
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
fn img8_to_img16_cb(img : @types.Image) -> @types.Image16 {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let data16 : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  for i in 0..<(w * h * ch) {
    let v8 = img.data[i].to_int()
    write_u16_le_cb(data16, i * 2, v8 * 257)
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data16),
  }
}

///|
fn img8_to_imgf_cb(img : @types.Image) -> @types.ImageF {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let dataf : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  for i in 0..<(w * h * ch) {
    let v8 = img.data[i].to_int()
    write_f32_le_cb(dataf, i * 4, Float::from_int(v8) / 255.0F)
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(dataf),
  }
}

// ========== 卷积 16-bit ==========

///|
/// 16-bit 3x3 卷积。
pub fn convolve_16(
  img : @types.Image16,
  kernel : Array[Float],
  bias : Float,
  scale : Float,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "convolve_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "convolve_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "convolve_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if kernel.length() != 9 {
    raise @types.LoadError::DecodeFailed(
      "convolve_16: kernel必须为9个值（3x3）",
    )
  }
  if scale == 0.0F {
    raise @types.LoadError::DecodeFailed("convolve_16: scale不能为0")
  }

  let img8 = img16_to_img8_cb(img)
  let result8 = convolve(img8, kernel, bias, scale)
  img8_to_img16_cb(result8)
}

// ========== 卷积 float ==========

///|
/// float 3x3 卷积。
pub fn convolve_f(
  img : @types.ImageF,
  kernel : Array[Float],
  bias : Float,
  scale : Float,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "convolve_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "convolve_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "convolve_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if kernel.length() != 9 {
    raise @types.LoadError::DecodeFailed(
      "convolve_f: kernel必须为9个值（3x3）",
    )
  }
  if scale == 0.0F {
    raise @types.LoadError::DecodeFailed("convolve_f: scale不能为0")
  }

  let img8 = imgf_to_img8_cb(img)
  let result8 = convolve(img8, kernel, bias, scale)
  img8_to_imgf_cb(result8)
}

// ========== 双边滤波 16-bit ==========

///|
/// 16-bit 双边滤波。
pub fn bilateral_filter_16(
  img : @types.Image16,
  radius : Int,
  sigma_space : Float,
  sigma_color : Float,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_16: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_16: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if radius < 1 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_16: radius必须 >= 1",
    )
  }
  if sigma_space <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_16: sigma_space必须大于0",
    )
  }
  if sigma_color <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_16: sigma_color必须大于0",
    )
  }

  let img8 = img16_to_img8_cb(img)
  let result8 = bilateral_filter(img8, radius, sigma_space, sigma_color)
  img8_to_img16_cb(result8)
}

// ========== 双边滤波 float ==========

///|
/// float 双边滤波。
pub fn bilateral_filter_f(
  img : @types.ImageF,
  radius : Int,
  sigma_space : Float,
  sigma_color : Float,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_f: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_f: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if radius < 1 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_f: radius必须 >= 1",
    )
  }
  if sigma_space <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_f: sigma_space必须大于0",
    )
  }
  if sigma_color <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_f: sigma_color必须大于0",
    )
  }

  let img8 = imgf_to_img8_cb(img)
  let result8 = bilateral_filter(img8, radius, sigma_space, sigma_color)
  img8_to_imgf_cb(result8)
}

// ========== 快速双边滤波 16-bit ==========

///|
/// 16-bit 快速双边滤波。
pub fn bilateral_filter_fast_16(
  img : @types.Image16,
  radius : Int,
  sigma_space : Float,
  sigma_color : Float,
  downsample : Int,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast_16: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast_16: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if radius < 1 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast_16: radius必须 >= 1",
    )
  }
  if sigma_space <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast_16: sigma_space必须大于0",
    )
  }
  if sigma_color <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast_16: sigma_color必须大于0",
    )
  }
  if downsample < 1 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast_16: downsample必须 >= 1",
    )
  }

  let img8 = img16_to_img8_cb(img)
  let result8 = bilateral_filter_fast(
    img8, radius, sigma_space, sigma_color, downsample,
  )
  img8_to_img16_cb(result8)
}

// ========== 快速双边滤波 float ==========

///|
/// float 快速双边滤波。
pub fn bilateral_filter_fast_f(
  img : @types.ImageF,
  radius : Int,
  sigma_space : Float,
  sigma_color : Float,
  downsample : Int,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast_f: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast_f: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if radius < 1 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast_f: radius必须 >= 1",
    )
  }
  if sigma_space <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast_f: sigma_space必须大于0",
    )
  }
  if sigma_color <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast_f: sigma_color必须大于0",
    )
  }
  if downsample < 1 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast_f: downsample必须 >= 1",
    )
  }

  let img8 = imgf_to_img8_cb(img)
  let result8 = bilateral_filter_fast(
    img8, radius, sigma_space, sigma_color, downsample,
  )
  img8_to_imgf_cb(result8)
}
