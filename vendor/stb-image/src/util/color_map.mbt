// 色彩映射与 alpha 操作（纯 MoonBit）：apply_lut / gradient_map / set_alpha / fill_alpha

///|

///|
/// 应用查找表（LUT）。lut 为 256 个 Byte 的映射表，将每个像素值 v 替换为 lut[v]。
/// 仅影响颜色通道，alpha 通道不变。
pub fn apply_lut(
  img : @types.Image,
  lut : Array[Byte],
) -> @types.Image raise @types.LoadError {
  if lut.length() < 256 {
    raise @types.LoadError::DecodeFailed("LUT 必须有 256 个条目")
  }
  let n = img.width * img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      out[i * ch + c] = lut[img.data[i * ch + c].to_int()]
    }
    if ch == 4 {
      out[i * ch + 3] = img.data[i * ch + 3]
    }
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 渐变映射。将图像亮度映射到 color_stops 定义的颜色渐变。
/// color_stops 为渐变颜色点，每个点是 (position, r, g, b)，position ∈ [0, 255]。
/// 返回 RGB 图像（channels=3）。
pub fn gradient_map(
  img : @types.Image,
  color_stops : Array[(Int, Byte, Byte, Byte)],
) -> @types.Image raise @types.LoadError {
  if color_stops.length() < 2 {
    raise @types.LoadError::DecodeFailed(
      "gradient_map 至少需要 2 个颜色点",
    )
  }
  let n = img.width * img.height
  let out : Array[Byte] = Array::make(n * 3, b'\x00')
  // 预计算 256 个亮度的映射
  let lut : Array[(Byte, Byte, Byte)] = Array::make(
    256,
    (b'\x00', b'\x00', b'\x00'),
  )
  for v in 0..<256 {
    lut[v] = interp_gradient(v, color_stops)
  }
  for i in 0..<n {
    let ch = img.channels
    let luminance = if ch >= 3 {
      // RGB -> luminance (0.299R + 0.587G + 0.114B)
      let r = img.data[i * ch].to_int()
      let g = img.data[i * ch + 1].to_int()
      let b = img.data[i * ch + 2].to_int()
      (r * 77 + g * 150 + b * 29) / 256
    } else {
      img.data[i * ch].to_int()
    }
    let (r, g, b) = lut[luminance]
    out[i * 3] = r
    out[i * 3 + 1] = g
    out[i * 3 + 2] = b
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: 3,
    data: Bytes::from_array(out),
  }
}

///|
fn interp_gradient(
  v : Int,
  stops : Array[(Int, Byte, Byte, Byte)],
) -> (Byte, Byte, Byte) {
  let len = stops.length()
  if v <= stops[0].0 {
    return (stops[0].1, stops[0].2, stops[0].3)
  }
  if v >= stops[len - 1].0 {
    return (stops[len - 1].1, stops[len - 1].2, stops[len - 1].3)
  }
  for i in 0..<(len - 1) {
    let (p0, r0, g0, b0) = stops[i]
    let (p1, r1, g1, b1) = stops[i + 1]
    if v >= p0 && v <= p1 {
      let range = p1 - p0
      if range == 0 {
        return (r0, g0, b0)
      }
      let t = v - p0
      let r = r0.to_int() + (r1.to_int() - r0.to_int()) * t / range
      let g = g0.to_int() + (g1.to_int() - g0.to_int()) * t / range
      let b = b0.to_int() + (b1.to_int() - b0.to_int()) * t / range
      return (clamp_b(r), clamp_b(g), clamp_b(b))
    }
  }
  (b'\x00', b'\x00', b'\x00')
}

///|
/// 设置所有像素的 alpha 通道为指定值。图像必须是 RGBA（channels=4）。
pub fn set_alpha(
  img : @types.Image,
  alpha : Byte,
) -> @types.Image raise @types.LoadError {
  if img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "set_alpha 需要 RGBA 图像（channels=4）",
    )
  }
  let n = img.width * img.height
  let out : Array[Byte] = Array::make(n * 4, b'\x00')
  for i in 0..<n {
    out[i * 4] = img.data[i * 4]
    out[i * 4 + 1] = img.data[i * 4 + 1]
    out[i * 4 + 2] = img.data[i * 4 + 2]
    out[i * 4 + 3] = alpha
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: 4,
    data: Bytes::from_array(out),
  }
}

///|
/// 用指定颜色填充 alpha 通道。将 alpha < threshold 的像素的 RGB 设为指定颜色。
pub fn fill_alpha(
  img : @types.Image,
  threshold : Int,
  fill_r : Byte,
  fill_g : Byte,
  fill_b : Byte,
) -> @types.Image raise @types.LoadError {
  if img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "fill_alpha 需要 RGBA 图像（channels=4）",
    )
  }
  let n = img.width * img.height
  let out : Array[Byte] = Array::make(n * 4, b'\x00')
  for i in 0..<n {
    let a = img.data[i * 4 + 3].to_int()
    if a < threshold {
      out[i * 4] = fill_r
      out[i * 4 + 1] = fill_g
      out[i * 4 + 2] = fill_b
    } else {
      out[i * 4] = img.data[i * 4]
      out[i * 4 + 1] = img.data[i * 4 + 1]
      out[i * 4 + 2] = img.data[i * 4 + 2]
    }
    out[i * 4 + 3] = img.data[i * 4 + 3]
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: 4,
    data: Bytes::from_array(out),
  }
}
