// 色彩调整操作（纯 MoonBit）
// 亮度/对比度/gamma/反色 + HSV/HSL 色彩空间转换

///|
fn clamp_byte(v : Int) -> Byte {
  if v < 0 {
    b'\x00'
  } else if v > 255 {
    b'\xFF'
  } else {
    v.to_byte()
  }
}

///|
/// 亮度调整。delta ∈ [-255, 255]，正值变亮，负值变暗。
/// 仅影响颜色通道（前 min(channels,3) 个），alpha 通道不变。
pub fn adjust_brightness(
  img : @types.Image,
  delta : Int,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "adjust_brightness: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "adjust_brightness: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "adjust_brightness: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let n = img.width * img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let lut : Array[Byte] = Array::make(256, b'\x00')
  for i in 0..<256 {
    lut[i] = clamp_byte(i + delta)
  }
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
/// 对比度调整。factor=1.0 为原图，>1 增加对比度，<1 降低。
/// 以 128 为中心缩放。仅影响颜色通道，alpha 不变。
/// 优化：直接处理所有像素，避免内层循环
pub fn adjust_contrast(
  img : @types.Image,
  factor : Float,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "adjust_contrast: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "adjust_contrast: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "adjust_contrast: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if factor < 0.0 {
    raise @types.LoadError::DecodeFailed(
      "adjust_contrast: factor必须大于等于0",
    )
  }
  let n = img.width * img.height
  let ch = img.channels
  let _ = if ch >= 3 { 3 } else { ch }
  let lut : Array[Byte] = Array::make(256, b'\x00')
  for i in 0..<256 {
    let adjusted = (Float::from_int(i - 128) * factor + 128.0F).to_int()
    lut[i] = clamp_byte(adjusted)
  }
  let total = n * ch
  let out : Array[Byte] = Array::make(total, b'\x00')
  let data = img.data
  if ch == 4 {
    // RGBA：处理 RGB，保留 A
    for i in 0..<n {
      let base = i * 4
      out[base] = lut[data[base].to_int()]
      out[base + 1] = lut[data[base + 1].to_int()]
      out[base + 2] = lut[data[base + 2].to_int()]
      out[base + 3] = data[base + 3]
    }
  } else if ch == 3 {
    // RGB
    for i in 0..<n {
      let base = i * 3
      out[base] = lut[data[base].to_int()]
      out[base + 1] = lut[data[base + 1].to_int()]
      out[base + 2] = lut[data[base + 2].to_int()]
    }
  } else {
    // 单通道
    for i in 0..<n {
      out[i] = lut[data[i].to_int()]
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
/// Gamma 校正。gamma=1.0 为原图，>1 变暗，<1 变亮。
/// 使用查找表加速。仅影响颜色通道，alpha 不变。
pub fn adjust_gamma(
  img : @types.Image,
  gamma : Float,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "adjust_gamma: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "adjust_gamma: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "adjust_gamma: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if gamma <= 0.0 {
    raise @types.LoadError::DecodeFailed("adjust_gamma: gamma必须大于0")
  }
  // 预计算 256 项查找表
  let lut : Array[Byte] = Array::make(256, b'\x00')
  for i in 0..<256 {
    let normalized = Float::from_int(i) / 255.0F
    let corrected = @math.powf(normalized, gamma)
    let val = (corrected * 255.0F + 0.5F).to_int()
    lut[i] = clamp_byte(val)
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
/// 反色（负片）。new = 255 - old。仅影响颜色通道，alpha 不变。
pub fn invert(img : @types.Image) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("invert: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed("invert: 通道数必须在1-4之间")
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "invert: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let n = img.width * img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      out[i * ch + c] = (255 - img.data[i * ch + c].to_int()).to_byte()
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
/// RGB → HSV 色彩空间转换。
/// 输入 r,g,b ∈ [0,255]，输出 h ∈ [0,360), s ∈ [0,1], v ∈ [0,1]
pub fn rgb_to_hsv(
  r : Int,
  g : Int,
  b : Int,
) -> (Float, Float, Float) raise @types.LoadError {
  // 输入验证
  if r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255 {
    raise @types.LoadError::DecodeFailed(
      "rgb_to_hsv: r,g,b必须在[0,255]范围内",
    )
  }
  let rf = Float::from_int(r) / 255.0F
  let gf = Float::from_int(g) / 255.0F
  let bf = Float::from_int(b) / 255.0F
  let mx = rf.max(gf).max(bf)
  let mn = rf.min(gf).min(bf)
  let delta = mx - mn
  let v = mx
  let s = if mx == 0.0F { 0.0F } else { delta / mx }
  let h = if delta == 0.0F {
    0.0F
  } else if mx == rf {
    60.0F * ((gf - bf) / delta)
  } else if mx == gf {
    60.0F * ((bf - rf) / delta + 2.0F)
  } else {
    60.0F * ((rf - gf) / delta + 4.0F)
  }
  let h_norm = if h < 0.0F { h + 360.0F } else { h }
  (h_norm, s, v)
}

///|
/// HSV → RGB 色彩空间转换。
/// 输入 h ∈ [0,360), s ∈ [0,1], v ∈ [0,1]，输出 r,g,b ∈ [0,255]
pub fn hsv_to_rgb(
  h : Float,
  s : Float,
  v : Float,
) -> (Int, Int, Int) raise @types.LoadError {
  // 输入验证
  if s < 0.0F || s > 1.0F || v < 0.0F || v > 1.0F {
    raise @types.LoadError::DecodeFailed(
      "hsv_to_rgb: s,v必须在[0,1]范围内",
    )
  }
  let c = v * s
  // 归一化 h 到 [0,6)
  let mut hp = h / 60.0F
  while hp >= 6.0F {
    hp = hp - 6.0F
  }
  while hp < 0.0F {
    hp = hp + 6.0F
  }
  // hp % 2.0
  let hp_mod2 = if hp < 2.0F {
    hp
  } else if hp < 4.0F {
    hp - 2.0F
  } else {
    hp - 4.0F
  }
  let x = c * (1.0F - (hp_mod2 - 1.0F).abs())
  let m = v - c
  let (r1, g1, b1) = if hp < 1.0F {
    (c, x, 0.0F)
  } else if hp < 2.0F {
    (x, c, 0.0F)
  } else if hp < 3.0F {
    (0.0F, c, x)
  } else if hp < 4.0F {
    (0.0F, x, c)
  } else if hp < 5.0F {
    (x, 0.0F, c)
  } else {
    (c, 0.0F, x)
  }
  (
    ((r1 + m) * 255.0F + 0.5F).to_int(),
    ((g1 + m) * 255.0F + 0.5F).to_int(),
    ((b1 + m) * 255.0F + 0.5F).to_int(),
  )
}

///|
/// RGB → HSL 色彩空间转换。
/// 输入 r,g,b ∈ [0,255]，输出 h ∈ [0,360), s ∈ [0,1], l ∈ [0,1]
pub fn rgb_to_hsl(
  r : Int,
  g : Int,
  b : Int,
) -> (Float, Float, Float) raise @types.LoadError {
  // 输入验证
  if r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255 {
    raise @types.LoadError::DecodeFailed(
      "rgb_to_hsl: r,g,b必须在[0,255]范围内",
    )
  }
  let rf = Float::from_int(r) / 255.0F
  let gf = Float::from_int(g) / 255.0F
  let bf = Float::from_int(b) / 255.0F
  let mx = rf.max(gf).max(bf)
  let mn = rf.min(gf).min(bf)
  let delta = mx - mn
  let l = (mx + mn) / 2.0F
  let s = if delta == 0.0F {
    0.0F
  } else {
    delta / (1.0F - (2.0F * l - 1.0F).abs())
  }
  let h = if delta == 0.0F {
    0.0F
  } else if mx == rf {
    60.0F * ((gf - bf) / delta)
  } else if mx == gf {
    60.0F * ((bf - rf) / delta + 2.0F)
  } else {
    60.0F * ((rf - gf) / delta + 4.0F)
  }
  let h_norm = if h < 0.0F { h + 360.0F } else { h }
  (h_norm, s, l)
}

///|
/// HSL → RGB 色彩空间转换。
/// 输入 h ∈ [0,360), s ∈ [0,1], l ∈ [0,1]，输出 r,g,b ∈ [0,255]
pub fn hsl_to_rgb(
  h : Float,
  s : Float,
  l : Float,
) -> (Int, Int, Int) raise @types.LoadError {
  // 输入验证
  if s < 0.0F || s > 1.0F || l < 0.0F || l > 1.0F {
    raise @types.LoadError::DecodeFailed(
      "hsl_to_rgb: s,l必须在[0,1]范围内",
    )
  }
  let c = (1.0F - (2.0F * l - 1.0F).abs()) * s
  // 归一化 h 到 [0,6)
  let mut hp = h / 60.0F
  while hp >= 6.0F {
    hp = hp - 6.0F
  }
  while hp < 0.0F {
    hp = hp + 6.0F
  }
  let hp_mod2 = if hp < 2.0F {
    hp
  } else if hp < 4.0F {
    hp - 2.0F
  } else {
    hp - 4.0F
  }
  let x = c * (1.0F - (hp_mod2 - 1.0F).abs())
  let m = l - c / 2.0F
  let (r1, g1, b1) = if hp < 1.0F {
    (c, x, 0.0F)
  } else if hp < 2.0F {
    (x, c, 0.0F)
  } else if hp < 3.0F {
    (0.0F, c, x)
  } else if hp < 4.0F {
    (0.0F, x, c)
  } else if hp < 5.0F {
    (x, 0.0F, c)
  } else {
    (c, 0.0F, x)
  }
  (
    ((r1 + m) * 255.0F + 0.5F).to_int(),
    ((g1 + m) * 255.0F + 0.5F).to_int(),
    ((b1 + m) * 255.0F + 0.5F).to_int(),
  )
}

///|
/// 饱和度调整。factor: 0.0 = 灰度, 1.0 = 原始, >1.0 = 增强饱和度
pub fn adjust_saturation(
  img : @types.Image,
  factor : Float,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "adjust_saturation: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "adjust_saturation: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "adjust_saturation: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let n = img.width * img.height
  let ch = img.channels
  if ch < 3 {
    return img
  }
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  let f = factor.clamp(min=0.0F, max=10.0F)
  for i in 0..<n {
    let r = Float::from_int(img.data[i * ch].to_int()) / 255.0F
    let g = Float::from_int(img.data[i * ch + 1].to_int()) / 255.0F
    let b = Float::from_int(img.data[i * ch + 2].to_int()) / 255.0F
    let gray = 0.299F * r + 0.587F * g + 0.114F * b
    let nr = (gray + (r - gray) * f).clamp(min=0.0F, max=1.0F)
    let ng = (gray + (g - gray) * f).clamp(min=0.0F, max=1.0F)
    let nb = (gray + (b - gray) * f).clamp(min=0.0F, max=1.0F)
    out[i * ch] = (nr * 255.0F + 0.5F).to_int().clamp(min=0, max=255).to_byte()
    out[i * ch + 1] = (ng * 255.0F + 0.5F)
      .to_int()
      .clamp(min=0, max=255)
      .to_byte()
    out[i * ch + 2] = (nb * 255.0F + 0.5F)
      .to_int()
      .clamp(min=0, max=255)
      .to_byte()
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
/// 色相调整。delta: 色相偏移量（度，0-360）
pub fn adjust_hue(
  img : @types.Image,
  delta : Float,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "adjust_hue: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "adjust_hue: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "adjust_hue: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let n = img.width * img.height
  let ch = img.channels
  if ch < 3 {
    return img
  }
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  for i in 0..<n {
    let r = img.data[i * ch].to_int()
    let g = img.data[i * ch + 1].to_int()
    let b = img.data[i * ch + 2].to_int()
    let (h, s, l) = rgb_to_hsl(r, g, b)
    let mut nh = h + delta
    while nh >= 360.0F {
      nh = nh - 360.0F
    }
    while nh < 0.0F {
      nh = nh + 360.0F
    }
    let (nr, ng, nb) = hsl_to_rgb(nh, s, l)
    out[i * ch] = nr.clamp(min=0, max=255).to_byte()
    out[i * ch + 1] = ng.clamp(min=0, max=255).to_byte()
    out[i * ch + 2] = nb.clamp(min=0, max=255).to_byte()
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
