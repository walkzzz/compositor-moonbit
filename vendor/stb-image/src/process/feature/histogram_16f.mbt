// 直方图操作 16-bit/float 变体
// 支持 Image16 / ImageF 两种类型

// ========== 辅助函数 ==========

///|
fn read_u16_le_h(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn write_u16_le_h(buf : Array[Byte], offset : Int, val : Int) -> Unit {
  buf[offset] = (val & 0xFF).to_byte()
  buf[offset + 1] = ((val >> 8) & 0xFF).to_byte()
}

///|
fn read_float_le_h(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
fn write_f32_le_h(buf : Array[Byte], offset : Int, val : Float) -> Unit {
  let bits = val.reinterpret_as_int()
  buf[offset] = (bits & 0xFF).to_byte()
  buf[offset + 1] = ((bits >> 8) & 0xFF).to_byte()
  buf[offset + 2] = ((bits >> 16) & 0xFF).to_byte()
  buf[offset + 3] = ((bits >> 24) & 0xFF).to_byte()
}

///|
fn clamp_int_h(v : Int, lo : Int, hi : Int) -> Int {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

///|
fn clamp_float_h(v : Float, lo : Float, hi : Float) -> Float {
  if v < lo {
    lo
  } else if v > hi {
    hi
  } else {
    v
  }
}

// ========== histogram ==========

///|
/// 16-bit 直方图。返回 65536 个 bin 的计数数组。彩色图像先转灰度（BT.601）。
pub fn histogram_16(img : @types.Image16) -> Array[Int] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "histogram_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "histogram_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "histogram_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let hist : Array[Int] = Array::make(65536, 0)
  let n = img.width * img.height
  let ch = img.channels
  for i in 0..<n {
    let v = if ch == 1 {
      read_u16_le_h(img.data, i * 2)
    } else {
      let r = read_u16_le_h(img.data, i * ch * 2)
      let g = read_u16_le_h(img.data, i * ch * 2 + 2)
      let b = read_u16_le_h(img.data, i * ch * 2 + 4)
      (r * 299 + g * 587 + b * 114) / 1000
    }
    hist[v] += 1
  }
  hist
}

///|
/// float 直方图。将值归一化到 [0,1] 后分 256 个 bin。彩色图像先转灰度。
pub fn histogram_f(img : @types.ImageF) -> Array[Int] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "histogram_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "histogram_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "histogram_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let hist : Array[Int] = Array::make(256, 0)
  let n = img.width * img.height
  let ch = img.channels
  for i in 0..<n {
    let v = if ch == 1 {
      read_float_le_h(img.data, i * 4)
    } else {
      let r = read_float_le_h(img.data, i * ch * 4)
      let g = read_float_le_h(img.data, i * ch * 4 + 4)
      let b = read_float_le_h(img.data, i * ch * 4 + 8)
      r * 0.299F + g * 0.587F + b * 0.114F
    }
    let bin = if v < 0.0F {
      0
    } else if v >= 1.0F {
      255
    } else {
      (v * 255.0F + 0.5F).to_int()
    }
    hist[bin] += 1
  }
  hist
}

// ========== histogram_equalize ==========

///|
/// 16-bit 直方图均衡化。基于灰度直方图计算映射 LUT，应用到所有颜色通道。
pub fn histogram_equalize_16(
  img : @types.Image16,
) -> @types.Image16 raise @types.LoadError {
  let hist = histogram_16(img)
  let n = img.width * img.height
  let ch = img.channels
  let bpp = ch * 2
  // 计算 CDF
  let cdf : Array[Int] = Array::make(65536, 0)
  let mut cum = 0
  for i in 0..<65536 {
    cum += hist[i]
    cdf[i] = cum
  }
  let mut cdf_min = 0
  for i in 0..<65536 {
    if cdf[i] > 0 {
      cdf_min = cdf[i]
      break
    }
  }
  let denom = n - cdf_min
  if denom <= 0 {
    return img
  }
  // 计算映射 LUT
  let lut : Array[Int] = Array::make(65536, 0)
  for i in 0..<65536 {
    let mapped = (cdf[i] - cdf_min) * 65535 / denom
    lut[i] = clamp_int_h(mapped, 0, 65535)
  }
  // 应用 LUT
  let color_ch = if ch >= 3 { 3 } else { ch }
  let n_total = n * ch
  let src : Array[Int] = Array::make(n_total, 0)
  for i in 0..<n_total {
    src[i] = read_u16_le_h(img.data, i * 2)
  }
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      write_u16_le_h(out, i * bpp + c * 2, lut[src[i * ch + c]])
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
/// float 直方图均衡化。基于灰度直方图计算映射 LUT，应用到所有颜色通道。
pub fn histogram_equalize_f(
  img : @types.ImageF,
) -> @types.ImageF raise @types.LoadError {
  let hist = histogram_f(img)
  let n = img.width * img.height
  let ch = img.channels
  let bpp = ch * 4
  let cdf : Array[Int] = Array::make(256, 0)
  let mut cum = 0
  for i in 0..<256 {
    cum += hist[i]
    cdf[i] = cum
  }
  let mut cdf_min = 0
  for i in 0..<256 {
    if cdf[i] > 0 {
      cdf_min = cdf[i]
      break
    }
  }
  let denom = n - cdf_min
  if denom <= 0 {
    return img
  }
  let lut : Array[Float] = Array::make(256, 0.0F)
  for i in 0..<256 {
    let mapped = Float::from_int(cdf[i] - cdf_min) / Float::from_int(denom)
    lut[i] = clamp_float_h(mapped, 0.0F, 1.0F)
  }
  let color_ch = if ch >= 3 { 3 } else { ch }
  let n_total = n * ch
  let src : Array[Float] = Array::make(n_total, 0.0F)
  for i in 0..<n_total {
    src[i] = read_float_le_h(img.data, i * 4)
  }
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let v = src[i * ch + c]
      let bin = if v < 0.0F {
        0
      } else if v >= 1.0F {
        255
      } else {
        (v * 255.0F + 0.5F).to_int()
      }
      write_f32_le_h(out, i * bpp + c * 4, lut[bin])
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

// ========== histogram_normalize ==========

///|
/// 16-bit 直方图归一化（线性拉伸）。将像素值范围线性映射到 [0, 65535]。
pub fn histogram_normalize_16(
  img : @types.Image16,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "histogram_normalize_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "histogram_normalize_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "histogram_normalize_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let n = img.width * img.height
  let bpp = ch * 2
  let n_total = n * ch
  let src : Array[Int] = Array::make(n_total, 0)
  for i in 0..<n_total {
    src[i] = read_u16_le_h(img.data, i * 2)
  }
  let mut min_val = 65535
  let mut max_val = 0
  for i in 0..<n {
    for c in 0..<color_ch {
      let v = src[i * ch + c]
      if v < min_val {
        min_val = v
      }
      if v > max_val {
        max_val = v
      }
    }
  }
  let range = max_val - min_val
  if range == 0 {
    return img
  }
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let v = src[i * ch + c]
      let scaled = (v - min_val) * 65535 / range
      write_u16_le_h(out, i * bpp + c * 2, clamp_int_h(scaled, 0, 65535))
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
/// float 直方图归一化（线性拉伸）。将像素值范围线性映射到 [0.0, 1.0]。
pub fn histogram_normalize_f(
  img : @types.ImageF,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "histogram_normalize_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "histogram_normalize_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "histogram_normalize_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let n = img.width * img.height
  let bpp = ch * 4
  let n_total = n * ch
  let src : Array[Float] = Array::make(n_total, 0.0F)
  for i in 0..<n_total {
    src[i] = read_float_le_h(img.data, i * 4)
  }
  let mut min_val = 1.0F
  let mut max_val = 0.0F
  for i in 0..<n {
    for c in 0..<color_ch {
      let v = src[i * ch + c]
      if v < min_val {
        min_val = v
      }
      if v > max_val {
        max_val = v
      }
    }
  }
  let range = max_val - min_val
  if range <= 0.000001F {
    return img
  }
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let v = src[i * ch + c]
      let scaled = (v - min_val) / range
      write_f32_le_h(out, i * bpp + c * 4, clamp_float_h(scaled, 0.0F, 1.0F))
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

// ========== histogram_matching ==========

///|
/// 16-bit 直方图匹配（规定化）。将输入图像的直方图匹配到参考图像的直方图。
pub fn histogram_matching_16(
  img : @types.Image16,
  reference : @types.Image16,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "histogram_matching_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "histogram_matching_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "histogram_matching_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if reference.width <= 0 || reference.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "histogram_matching_16: 参考图像尺寸必须大于0",
    )
  }
  if reference.channels < 1 || reference.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "histogram_matching_16: 参考图像通道数必须在1-4之间",
    )
  }
  let ref_expected_size = reference.width *
    reference.height *
    reference.channels *
    2
  if reference.data.length() != ref_expected_size {
    raise @types.LoadError::DecodeFailed(
      "histogram_matching_16: 参考图像数据大小不匹配，期望 " +
      ref_expected_size.to_string() +
      "，实际 " +
      reference.data.length().to_string(),
    )
  }

  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let n = img.width * img.height
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let n_ref = reference.width * reference.height
  let ref_ch = reference.channels
  let ref_color_ch = if ref_ch >= 3 { 3 } else { ref_ch }
  for c in 0..<color_ch {
    let hist_in : Array[Int] = Array::make(65536, 0)
    let hist_ref : Array[Int] = Array::make(65536, 0)
    for i in 0..<n {
      hist_in[read_u16_le_h(img.data, i * bpp + c * 2)] += 1
    }
    if c < ref_color_ch {
      for i in 0..<n_ref {
        hist_ref[read_u16_le_h(reference.data, i * ref_ch * 2 + c * 2)] += 1
      }
    }
    let cdf_in : Array[Float] = Array::make(65536, 0.0F)
    let cdf_ref : Array[Float] = Array::make(65536, 0.0F)
    let mut cum_in = 0
    let mut cum_ref = 0
    for i in 0..<65536 {
      cum_in += hist_in[i]
      cdf_in[i] = Float::from_int(cum_in) / Float::from_int(n)
      cum_ref += hist_ref[i]
      cdf_ref[i] = Float::from_int(cum_ref) / Float::from_int(n_ref)
    }
    let lut : Array[Int] = Array::make(65536, 0)
    for i in 0..<65536 {
      let target = cdf_in[i]
      let mut best_j = 0
      let mut best_diff = 1.0F
      for j in 0..<65536 {
        let diff = (cdf_ref[j] - target).abs()
        if diff < best_diff {
          best_diff = diff
          best_j = j
        }
      }
      lut[i] = best_j
    }
    for i in 0..<n {
      let v = read_u16_le_h(img.data, i * bpp + c * 2)
      write_u16_le_h(out, i * bpp + c * 2, lut[v])
    }
  }
  if ch == 4 {
    for i in 0..<n {
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
/// float 直方图匹配（规定化）。将输入图像的直方图匹配到参考图像的直方图。
pub fn histogram_matching_f(
  img : @types.ImageF,
  reference : @types.ImageF,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "histogram_matching_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "histogram_matching_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "histogram_matching_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if reference.width <= 0 || reference.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "histogram_matching_f: 参考图像尺寸必须大于0",
    )
  }
  if reference.channels < 1 || reference.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "histogram_matching_f: 参考图像通道数必须在1-4之间",
    )
  }
  let ref_expected_size = reference.width *
    reference.height *
    reference.channels *
    4
  if reference.data.length() != ref_expected_size {
    raise @types.LoadError::DecodeFailed(
      "histogram_matching_f: 参考图像数据大小不匹配，期望 " +
      ref_expected_size.to_string() +
      "，实际 " +
      reference.data.length().to_string(),
    )
  }

  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let n = img.width * img.height
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let n_ref = reference.width * reference.height
  let ref_ch = reference.channels
  let ref_color_ch = if ref_ch >= 3 { 3 } else { ref_ch }
  for c in 0..<color_ch {
    let hist_in : Array[Int] = Array::make(256, 0)
    let hist_ref : Array[Int] = Array::make(256, 0)
    for i in 0..<n {
      let v = read_float_le_h(img.data, i * bpp + c * 4)
      let bin = if v < 0.0F {
        0
      } else if v >= 1.0F {
        255
      } else {
        (v * 255.0F + 0.5F).to_int()
      }
      hist_in[bin] += 1
    }
    if c < ref_color_ch {
      for i in 0..<n_ref {
        let v = read_float_le_h(reference.data, i * ref_ch * 4 + c * 4)
        let bin = if v < 0.0F {
          0
        } else if v >= 1.0F {
          255
        } else {
          (v * 255.0F + 0.5F).to_int()
        }
        hist_ref[bin] += 1
      }
    }
    let cdf_in : Array[Float] = Array::make(256, 0.0F)
    let cdf_ref : Array[Float] = Array::make(256, 0.0F)
    let mut cum_in = 0
    let mut cum_ref = 0
    for i in 0..<256 {
      cum_in += hist_in[i]
      cdf_in[i] = Float::from_int(cum_in) / Float::from_int(n)
      cum_ref += hist_ref[i]
      cdf_ref[i] = Float::from_int(cum_ref) / Float::from_int(n_ref)
    }
    let lut : Array[Int] = Array::make(256, 0)
    for i in 0..<256 {
      let target = cdf_in[i]
      let mut best_j = 0
      let mut best_diff = 1.0F
      for j in 0..<256 {
        let diff = (cdf_ref[j] - target).abs()
        if diff < best_diff {
          best_diff = diff
          best_j = j
        }
      }
      lut[i] = best_j
    }
    for i in 0..<n {
      let v = read_float_le_h(img.data, i * bpp + c * 4)
      let bin = if v < 0.0F {
        0
      } else if v >= 1.0F {
        255
      } else {
        (v * 255.0F + 0.5F).to_int()
      }
      let mapped = Float::from_int(lut[bin]) / 255.0F
      write_f32_le_h(out, i * bpp + c * 4, clamp_float_h(mapped, 0.0F, 1.0F))
    }
  }
  if ch == 4 {
    for i in 0..<n {
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
