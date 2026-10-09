// 色调映射 16-bit/float 变体
// Gamma + Reinhard，返回 Image16/ImageF

///|
fn read_float_le_tm(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
fn write_float_le_tm(data : Array[Byte], offset : Int, v : Float) -> Unit {
  let bits = v.reinterpret_as_int()
  data[offset] = (bits & 0xFF).to_byte()
  data[offset + 1] = ((bits >> 8) & 0xFF).to_byte()
  data[offset + 2] = ((bits >> 16) & 0xFF).to_byte()
  data[offset + 3] = ((bits >> 24) & 0xFF).to_byte()
}

///|
fn write_u16_le_tm(data : Array[Byte], offset : Int, v : Int) -> Unit {
  data[offset] = (v & 0xFF).to_byte()
  data[offset + 1] = ((v >> 8) & 0xFF).to_byte()
}

///|
fn log_f_tm(x : Float) -> Float {
  Float::from_double(@math.log2(x.to_double()) * 0.6931471805599453)
}

// ========== Gamma 色调映射 float ==========

///|
/// Gamma 色调映射（float 输出）。
/// 先归一化到 [0,1]，再应用 gamma 校正：L_out = L^(1/gamma)。
/// gamma > 1 提亮暗部，gamma < 1 压暗。
pub fn gamma_tonemap_f(
  imgf : @types.ImageF,
  gamma : Float,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if imgf.width <= 0 || imgf.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "gamma_tonemap_f: 图像尺寸必须大于0",
    )
  }
  if imgf.channels < 1 || imgf.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "gamma_tonemap_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = imgf.width * imgf.height * imgf.channels * 4
  if imgf.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "gamma_tonemap_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      imgf.data.length().to_string(),
    )
  }
  if gamma <= 0.0F {
    raise @types.LoadError::DecodeFailed("gamma_tonemap_f: gamma必须大于0")
  }
  let w = imgf.width
  let h = imgf.height
  let ch = imgf.channels
  let n = w * h
  let color_ch = if ch >= 3 { 3 } else { ch }
  // 找最大值用于归一化
  let mut max_val = 0.0F
  for i in 0..<n {
    for c in 0..<color_ch {
      let v = read_float_le_tm(imgf.data, (i * ch + c) * 4)
      if v > max_val {
        max_val = v
      }
    }
  }
  if max_val <= 0.0F {
    return @types.ImageF::{
      width: w,
      height: h,
      channels: ch,
      data: Bytes::from_array(Array::make(n * ch * 4, b'\x00')),
    }
  }
  let inv_gamma = 1.0F / gamma
  let out : Array[Byte] = Array::make(n * ch * 4, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let v = read_float_le_tm(imgf.data, (i * ch + c) * 4)
      let normalized = v / max_val
      let mapped = if normalized > 0.0F {
        @math.powf(normalized, inv_gamma)
      } else {
        0.0F
      }
      write_float_le_tm(out, (i * ch + c) * 4, mapped)
    }
    if ch == 4 {
      write_float_le_tm(out, (i * ch + 3) * 4, 1.0F)
    }
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== Reinhard 色调映射 float ==========

///|
/// Reinhard 全局色调映射（float 输出）。
/// key 控制整体亮度（默认 0.18），值越大越亮。
/// 公式：L_out = L_scaled / (1 + L_scaled)，其中 L_scaled = key * L / L_avg。
pub fn reinhard_tonemap_f(
  imgf : @types.ImageF,
  key? : Float = 0.18F,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if imgf.width <= 0 || imgf.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "reinhard_tonemap_f: 图像尺寸必须大于0",
    )
  }
  if imgf.channels < 1 || imgf.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "reinhard_tonemap_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = imgf.width * imgf.height * imgf.channels * 4
  if imgf.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "reinhard_tonemap_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      imgf.data.length().to_string(),
    )
  }
  if key <= 0.0F {
    raise @types.LoadError::DecodeFailed("reinhard_tonemap_f: key必须大于0")
  }
  let w = imgf.width
  let h = imgf.height
  let ch = imgf.channels
  let n = w * h
  let color_ch = if ch >= 3 { 3 } else { ch }
  // 计算对数平均亮度
  let mut log_sum = 0.0F
  for i in 0..<n {
    let r = read_float_le_tm(imgf.data, i * ch * 4)
    let g = read_float_le_tm(imgf.data, i * ch * 4 + 4)
    let b = read_float_le_tm(imgf.data, i * ch * 4 + 8)
    let lum = 0.2126F * r + 0.7152F * g + 0.0722F * b
    let lum_safe = if lum > 0.0F { lum } else { 0.0001F }
    log_sum += log_f_tm(lum_safe)
  }
  let log_avg = @math.expf(log_sum / Float::from_int(n))
  let scale = key / log_avg
  // 应用 Reinhard 映射
  let out : Array[Byte] = Array::make(n * ch * 4, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let v = read_float_le_tm(imgf.data, (i * ch + c) * 4)
      let scaled = v * scale
      let mapped = scaled / (1.0F + scaled)
      write_float_le_tm(out, (i * ch + c) * 4, mapped)
    }
    if ch == 4 {
      write_float_le_tm(out, (i * ch + 3) * 4, 1.0F)
    }
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== Gamma 色调映射 16-bit ==========

///|
/// Gamma 色调映射（16-bit 输出）。
/// 输入 ImageF，输出 Image16（0-65535）。
pub fn gamma_tonemap_16(
  imgf : @types.ImageF,
  gamma : Float,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if imgf.width <= 0 || imgf.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "gamma_tonemap_16: 图像尺寸必须大于0",
    )
  }
  if imgf.channels < 1 || imgf.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "gamma_tonemap_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = imgf.width * imgf.height * imgf.channels * 4
  if imgf.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "gamma_tonemap_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      imgf.data.length().to_string(),
    )
  }
  if gamma <= 0.0F {
    raise @types.LoadError::DecodeFailed("gamma_tonemap_16: gamma必须大于0")
  }
  let w = imgf.width
  let h = imgf.height
  let ch = imgf.channels
  let n = w * h
  let color_ch = if ch >= 3 { 3 } else { ch }
  // 找最大值用于归一化
  let mut max_val = 0.0F
  for i in 0..<n {
    for c in 0..<color_ch {
      let v = read_float_le_tm(imgf.data, (i * ch + c) * 4)
      if v > max_val {
        max_val = v
      }
    }
  }
  if max_val <= 0.0F {
    return @types.Image16::{
      width: w,
      height: h,
      channels: ch,
      data: Bytes::from_array(Array::make(n * ch * 2, b'\x00')),
    }
  }
  let inv_gamma = 1.0F / gamma
  let out : Array[Byte] = Array::make(n * ch * 2, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let v = read_float_le_tm(imgf.data, (i * ch + c) * 4)
      let normalized = v / max_val
      let mapped = if normalized > 0.0F {
        @math.powf(normalized, inv_gamma)
      } else {
        0.0F
      }
      let val = (mapped * 65535.0F + 0.5F).to_int()
      let clamped = if val < 0 { 0 } else if val > 65535 { 65535 } else { val }
      write_u16_le_tm(out, (i * ch + c) * 2, clamped)
    }
    if ch == 4 {
      write_u16_le_tm(out, (i * ch + 3) * 2, 65535)
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== Reinhard 色调映射 16-bit ==========

///|
/// Reinhard 全局色调映射（16-bit 输出）。
/// 输入 ImageF，输出 Image16（0-65535）。
pub fn reinhard_tonemap_16(
  imgf : @types.ImageF,
  key? : Float = 0.18F,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if imgf.width <= 0 || imgf.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "reinhard_tonemap_16: 图像尺寸必须大于0",
    )
  }
  if imgf.channels < 1 || imgf.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "reinhard_tonemap_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = imgf.width * imgf.height * imgf.channels * 4
  if imgf.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "reinhard_tonemap_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      imgf.data.length().to_string(),
    )
  }
  if key <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "reinhard_tonemap_16: key必须大于0",
    )
  }
  let w = imgf.width
  let h = imgf.height
  let ch = imgf.channels
  let n = w * h
  let color_ch = if ch >= 3 { 3 } else { ch }
  // 计算对数平均亮度
  let mut log_sum = 0.0F
  for i in 0..<n {
    let r = read_float_le_tm(imgf.data, i * ch * 4)
    let g = read_float_le_tm(imgf.data, i * ch * 4 + 4)
    let b = read_float_le_tm(imgf.data, i * ch * 4 + 8)
    let lum = 0.2126F * r + 0.7152F * g + 0.0722F * b
    let lum_safe = if lum > 0.0F { lum } else { 0.0001F }
    log_sum += log_f_tm(lum_safe)
  }
  let log_avg = @math.expf(log_sum / Float::from_int(n))
  let scale = key / log_avg
  // 应用 Reinhard 映射
  let out : Array[Byte] = Array::make(n * ch * 2, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let v = read_float_le_tm(imgf.data, (i * ch + c) * 4)
      let scaled = v * scale
      let mapped = scaled / (1.0F + scaled)
      let val = (mapped * 65535.0F + 0.5F).to_int()
      let clamped = if val < 0 { 0 } else if val > 65535 { 65535 } else { val }
      write_u16_le_tm(out, (i * ch + c) * 2, clamped)
    }
    if ch == 4 {
      write_u16_le_tm(out, (i * ch + 3) * 2, 65535)
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}
