// 色彩调整 16-bit/float 变体
// 支持 Image16 / ImageF 两种类型

///|
fn read_u16_le_c(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn write_u16_le_c(buf : Array[Byte], offset : Int, val : Int) -> Unit {
  buf[offset] = (val & 0xFF).to_byte()
  buf[offset + 1] = ((val >> 8) & 0xFF).to_byte()
}

///|
fn write_f32_le(buf : Array[Byte], offset : Int, val : Float) -> Unit {
  let bits = val.reinterpret_as_int()
  buf[offset] = (bits & 0xFF).to_byte()
  buf[offset + 1] = ((bits >> 8) & 0xFF).to_byte()
  buf[offset + 2] = ((bits >> 16) & 0xFF).to_byte()
  buf[offset + 3] = ((bits >> 24) & 0xFF).to_byte()
}

///|
/// 16-bit 亮度调整。delta ∈ [-65535, 65535]
pub fn adjust_brightness_16(
  img : @types.Image16,
  delta : Int,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "adjust_brightness_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "adjust_brightness_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "adjust_brightness_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let n = img.width * img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let offset = i * bpp + c * 2
      let val = read_u16_le_c(img.data, offset)
      let adjusted = if val + delta < 0 {
        0
      } else if val + delta > 65535 {
        65535
      } else {
        val + delta
      }
      write_u16_le_c(out, offset, adjusted)
    }
    if ch == 4 {
      let alpha_off = i * bpp + 6
      out[alpha_off] = img.data[alpha_off]
      out[alpha_off + 1] = img.data[alpha_off + 1]
    }
  }
  @types.Image16::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// float 亮度调整。delta 为浮点偏移量
pub fn adjust_brightness_f(
  img : @types.ImageF,
  delta : Float,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "adjust_brightness_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "adjust_brightness_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "adjust_brightness_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let n = img.width * img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let offset = i * bpp + c * 4
      let val = read_float_le(img.data, offset)
      write_f32_le(out, offset, val + delta)
    }
    if ch == 4 {
      let alpha_off = i * bpp + 12
      for b in 0..<4 {
        out[alpha_off + b] = img.data[alpha_off + b]
      }
    }
  }
  @types.ImageF::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 16-bit 对比度调整。factor=1.0 为原图，以 32768 为中心
pub fn adjust_contrast_16(
  img : @types.Image16,
  factor : Float,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "adjust_contrast_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "adjust_contrast_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "adjust_contrast_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if factor < 0.0F {
    raise @types.LoadError::DecodeFailed(
      "adjust_contrast_16: factor必须大于等于0",
    )
  }
  let n = img.width * img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let offset = i * bpp + c * 2
      let val = read_u16_le_c(img.data, offset)
      let adjusted = (Float::from_int(val - 32768) * factor + 32768.0F).to_int()
      let clamped = if adjusted < 0 {
        0
      } else if adjusted > 65535 {
        65535
      } else {
        adjusted
      }
      write_u16_le_c(out, offset, clamped)
    }
    if ch == 4 {
      let alpha_off = i * bpp + 6
      out[alpha_off] = img.data[alpha_off]
      out[alpha_off + 1] = img.data[alpha_off + 1]
    }
  }
  @types.Image16::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// float 对比度调整。factor=1.0 为原图，以 0.5 为中心
pub fn adjust_contrast_f(
  img : @types.ImageF,
  factor : Float,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "adjust_contrast_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "adjust_contrast_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "adjust_contrast_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if factor < 0.0F {
    raise @types.LoadError::DecodeFailed(
      "adjust_contrast_f: factor必须大于等于0",
    )
  }
  let n = img.width * img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let offset = i * bpp + c * 4
      let val = read_float_le(img.data, offset)
      write_f32_le(out, offset, (val - 0.5F) * factor + 0.5F)
    }
    if ch == 4 {
      let alpha_off = i * bpp + 12
      for b in 0..<4 {
        out[alpha_off + b] = img.data[alpha_off + b]
      }
    }
  }
  @types.ImageF::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 16-bit Gamma 校正。gamma=1.0 为原图，>1 变暗，<1 变亮。
/// 以 65535 为满量程。仅影响颜色通道，alpha 不变。
pub fn adjust_gamma_16(
  img : @types.Image16,
  gamma : Float,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "adjust_gamma_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "adjust_gamma_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "adjust_gamma_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if gamma <= 0.0F {
    raise @types.LoadError::DecodeFailed("adjust_gamma_16: gamma必须>0")
  }
  let n = img.width * img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let offset = i * bpp + c * 2
      let val = read_u16_le_c(img.data, offset)
      let normalized = Float::from_int(val) / 65535.0F
      let corrected = @math.powf(normalized, gamma)
      let new_val = (corrected * 65535.0F + 0.5F).to_int()
      let clamped = if new_val < 0 {
        0
      } else if new_val > 65535 {
        65535
      } else {
        new_val
      }
      write_u16_le_c(out, offset, clamped)
    }
    if ch == 4 {
      let alpha_off = i * bpp + 6
      out[alpha_off] = img.data[alpha_off]
      out[alpha_off + 1] = img.data[alpha_off + 1]
    }
  }
  @types.Image16::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// float Gamma 校正。gamma=1.0 为原图，>1 变暗，<1 变亮。
/// 以 1.0 为满量程。仅影响颜色通道，alpha 不变。
pub fn adjust_gamma_f(
  img : @types.ImageF,
  gamma : Float,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "adjust_gamma_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "adjust_gamma_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "adjust_gamma_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if gamma <= 0.0F {
    raise @types.LoadError::DecodeFailed("adjust_gamma_f: gamma必须>0")
  }
  let n = img.width * img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let offset = i * bpp + c * 4
      let val = read_float_le(img.data, offset)
      let corrected = if val < 0.0F {
        0.0F
      } else if val > 1.0F {
        1.0F
      } else {
        @math.powf(val, gamma)
      }
      write_f32_le(out, offset, corrected)
    }
    if ch == 4 {
      let alpha_off = i * bpp + 12
      for b in 0..<4 {
        out[alpha_off + b] = img.data[alpha_off + b]
      }
    }
  }
  @types.ImageF::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 16-bit 反色（负片）。new = 65535 - old。仅影响颜色通道，alpha 不变。
pub fn invert_16(img : @types.Image16) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("invert_16: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "invert_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "invert_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let n = img.width * img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let offset = i * bpp + c * 2
      let val = read_u16_le_c(img.data, offset)
      write_u16_le_c(out, offset, 65535 - val)
    }
    if ch == 4 {
      let alpha_off = i * bpp + 6
      out[alpha_off] = img.data[alpha_off]
      out[alpha_off + 1] = img.data[alpha_off + 1]
    }
  }
  @types.Image16::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// float 反色（负片）。new = 1.0 - old。仅影响颜色通道，alpha 不变。
pub fn invert_f(img : @types.ImageF) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("invert_f: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "invert_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "invert_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let n = img.width * img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let offset = i * bpp + c * 4
      let val = read_float_le(img.data, offset)
      write_f32_le(out, offset, 1.0F - val)
    }
    if ch == 4 {
      let alpha_off = i * bpp + 12
      for b in 0..<4 {
        out[alpha_off + b] = img.data[alpha_off + b]
      }
    }
  }
  @types.ImageF::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 16-bit 转灰度。ITU-R BT.601: Y = 0.299R + 0.587G + 0.114B。
/// 输出 channels=1 的 16-bit 灰度图。
pub fn to_grayscale_16(
  img : @types.Image16,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "to_grayscale_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "to_grayscale_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "to_grayscale_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let n = img.width * img.height
  let ch = img.channels
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(n * 2, b'\x00')
  for i in 0..<n {
    if ch >= 3 {
      let r = read_u16_le_c(img.data, i * bpp)
      let g = read_u16_le_c(img.data, i * bpp + 2)
      let b = read_u16_le_c(img.data, i * bpp + 4)
      let y = (Float::from_int(r) * 0.299F +
      Float::from_int(g) * 0.587F +
      Float::from_int(b) * 0.114F +
      0.5F).to_int()
      let clamped = if y < 0 { 0 } else if y > 65535 { 65535 } else { y }
      write_u16_le_c(out, i * 2, clamped)
    } else {
      let val = read_u16_le_c(img.data, i * bpp)
      write_u16_le_c(out, i * 2, val)
    }
  }
  @types.Image16::{
    width: img.width,
    height: img.height,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// float 转灰度。ITU-R BT.601: Y = 0.299R + 0.587G + 0.114B。
/// 输出 channels=1 的 float 灰度图。
pub fn to_grayscale_f(
  img : @types.ImageF,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "to_grayscale_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "to_grayscale_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "to_grayscale_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let n = img.width * img.height
  let ch = img.channels
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(n * 4, b'\x00')
  for i in 0..<n {
    if ch >= 3 {
      let r = read_float_le(img.data, i * bpp)
      let g = read_float_le(img.data, i * bpp + 4)
      let b = read_float_le(img.data, i * bpp + 8)
      let y = r * 0.299F + g * 0.587F + b * 0.114F
      write_f32_le(out, i * 4, y)
    } else {
      let val = read_float_le(img.data, i * bpp)
      write_f32_le(out, i * 4, val)
    }
  }
  @types.ImageF::{
    width: img.width,
    height: img.height,
    channels: 1,
    data: Bytes::from_array(out),
  }
}
