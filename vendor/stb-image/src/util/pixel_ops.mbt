// 像素操作（纯 MoonBit）：threshold / posterize / extract_channel / blend 模式

///|
fn clamp_byte_v(v : Int) -> Byte {
  if v < 0 {
    b'\x00'
  } else if v > 255 {
    b'\xFF'
  } else {
    v.to_byte()
  }
}

///|
/// 二值化。像素值 >= threshold 设为 255，否则设为 0。
/// 仅影响颜色通道，alpha 通道不变。
pub fn threshold(img : @types.Image, thresh : Int) -> @types.Image {
  let n = img.width * img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      out[i * ch + c] = if img.data[i * ch + c].to_int() >= thresh {
        b'\xFF'
      } else {
        b'\x00'
      }
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
/// 色调分离。将每个通道的值量化到 levels 个级别。
/// levels=2 等价于二值化，levels=4 将 0-255 分成 4 段。
pub fn posterize(
  img : @types.Image,
  levels : Int,
) -> @types.Image raise @types.LoadError {
  if levels < 2 || levels > 256 {
    raise @types.LoadError::DecodeFailed(
      "posterize levels 必须在 [2, 256] 范围内",
    )
  }
  let n = img.width * img.height
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let step = 256.0F / Float::from_int(levels)
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let v = img.data[i * ch + c].to_int()
      let quantized = (Float::from_int(v) / step).to_int() * step.to_int()
      out[i * ch + c] = clamp_byte_v(quantized)
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
/// 提取单个通道。返回单通道 Image（channels=1）。
/// channel: 0=R/Gray, 1=G, 2=B, 3=A
pub fn extract_channel(
  img : @types.Image,
  channel : Int,
) -> @types.Image raise @types.LoadError {
  if channel < 0 || channel >= img.channels {
    raise @types.LoadError::DecodeFailed("channel 索引越界")
  }
  let n = img.width * img.height
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    out[i] = img.data[i * img.channels + channel]
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// 乘法混合。result = base * blend / 255。
/// 两图必须尺寸和通道数相同。
pub fn blend_multiply(
  base : @types.Image,
  blend : @types.Image,
) -> @types.Image raise @types.LoadError {
  if base.width != blend.width ||
    base.height != blend.height ||
    base.channels != blend.channels {
    raise @types.LoadError::DecodeFailed(
      "blend 两图尺寸/通道数必须相同",
    )
  }
  let n = base.width * base.height * base.channels
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    let b = base.data[i].to_int()
    let l = blend.data[i].to_int()
    out[i] = (b * l / 255).to_byte()
  }
  @types.Image::{
    width: base.width,
    height: base.height,
    channels: base.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 滤色混合。result = 255 - (255 - base) * (255 - blend) / 255。
pub fn blend_screen(
  base : @types.Image,
  blend : @types.Image,
) -> @types.Image raise @types.LoadError {
  if base.width != blend.width ||
    base.height != blend.height ||
    base.channels != blend.channels {
    raise @types.LoadError::DecodeFailed(
      "blend 两图尺寸/通道数必须相同",
    )
  }
  let n = base.width * base.height * base.channels
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    let b = base.data[i].to_int()
    let l = blend.data[i].to_int()
    out[i] = (255 - (255 - b) * (255 - l) / 255).to_byte()
  }
  @types.Image::{
    width: base.width,
    height: base.height,
    channels: base.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 叠加混合。暗部用乘法，亮部用滤色。
/// result = if base < 128: 2*base*blend/255 else: 255 - 2*(255-base)*(255-blend)/255
pub fn blend_overlay(
  base : @types.Image,
  blend : @types.Image,
) -> @types.Image raise @types.LoadError {
  if base.width != blend.width ||
    base.height != blend.height ||
    base.channels != blend.channels {
    raise @types.LoadError::DecodeFailed(
      "blend 两图尺寸/通道数必须相同",
    )
  }
  let n = base.width * base.height * base.channels
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    let b = base.data[i].to_int()
    let l = blend.data[i].to_int()
    out[i] = if b < 128 {
      (2 * b * l / 255).to_byte()
    } else {
      clamp_byte_v(255 - 2 * (255 - b) * (255 - l) / 255)
    }
  }
  @types.Image::{
    width: base.width,
    height: base.height,
    channels: base.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 变暗混合。result = min(base, blend)。
pub fn blend_darken(
  base : @types.Image,
  blend : @types.Image,
) -> @types.Image raise @types.LoadError {
  if base.width != blend.width ||
    base.height != blend.height ||
    base.channels != blend.channels {
    raise @types.LoadError::DecodeFailed(
      "blend 两图尺寸/通道数必须相同",
    )
  }
  let n = base.width * base.height * base.channels
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    let b = base.data[i].to_int()
    let l = blend.data[i].to_int()
    out[i] = (if b < l { b } else { l }).to_byte()
  }
  @types.Image::{
    width: base.width,
    height: base.height,
    channels: base.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 变亮混合。result = max(base, blend)。
pub fn blend_lighten(
  base : @types.Image,
  blend : @types.Image,
) -> @types.Image raise @types.LoadError {
  if base.width != blend.width ||
    base.height != blend.height ||
    base.channels != blend.channels {
    raise @types.LoadError::DecodeFailed(
      "blend 两图尺寸/通道数必须相同",
    )
  }
  let n = base.width * base.height * base.channels
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    let b = base.data[i].to_int()
    let l = blend.data[i].to_int()
    out[i] = (if b > l { b } else { l }).to_byte()
  }
  @types.Image::{
    width: base.width,
    height: base.height,
    channels: base.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 差值混合。result = |base - blend|。
pub fn blend_difference(
  base : @types.Image,
  blend : @types.Image,
) -> @types.Image raise @types.LoadError {
  if base.width != blend.width ||
    base.height != blend.height ||
    base.channels != blend.channels {
    raise @types.LoadError::DecodeFailed(
      "blend 两图尺寸/通道数必须相同",
    )
  }
  let n = base.width * base.height * base.channels
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    let b = base.data[i].to_int()
    let l = blend.data[i].to_int()
    out[i] = (if b > l { b - l } else { l - b }).to_byte()
  }
  @types.Image::{
    width: base.width,
    height: base.height,
    channels: base.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 排除混合。result = base + blend - 2 * base * blend / 255。
pub fn blend_exclusion(
  base : @types.Image,
  blend : @types.Image,
) -> @types.Image raise @types.LoadError {
  if base.width != blend.width ||
    base.height != blend.height ||
    base.channels != blend.channels {
    raise @types.LoadError::DecodeFailed(
      "blend 两图尺寸/通道数必须相同",
    )
  }
  let n = base.width * base.height * base.channels
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    let b = base.data[i].to_int()
    let l = blend.data[i].to_int()
    out[i] = clamp_byte_v(b + l - 2 * b * l / 255)
  }
  @types.Image::{
    width: base.width,
    height: base.height,
    channels: base.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 颜色减淡。result = base * 255 / (255 - blend)，blend=255 时结果为 255。
pub fn blend_color_dodge(
  base : @types.Image,
  blend : @types.Image,
) -> @types.Image raise @types.LoadError {
  if base.width != blend.width ||
    base.height != blend.height ||
    base.channels != blend.channels {
    raise @types.LoadError::DecodeFailed(
      "blend 两图尺寸/通道数必须相同",
    )
  }
  let n = base.width * base.height * base.channels
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    let b = base.data[i].to_int()
    let l = blend.data[i].to_int()
    out[i] = if l == 255 { b'\xFF' } else { clamp_byte_v(b * 255 / (255 - l)) }
  }
  @types.Image::{
    width: base.width,
    height: base.height,
    channels: base.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 颜色加深。result = 255 - (255 - base) * 255 / blend，blend=0 时结果为 0。
pub fn blend_color_burn(
  base : @types.Image,
  blend : @types.Image,
) -> @types.Image raise @types.LoadError {
  if base.width != blend.width ||
    base.height != blend.height ||
    base.channels != blend.channels {
    raise @types.LoadError::DecodeFailed(
      "blend 两图尺寸/通道数必须相同",
    )
  }
  let n = base.width * base.height * base.channels
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    let b = base.data[i].to_int()
    let l = blend.data[i].to_int()
    out[i] = if l == 0 {
      b'\x00'
    } else {
      clamp_byte_v(255 - (255 - b) * 255 / l)
    }
  }
  @types.Image::{
    width: base.width,
    height: base.height,
    channels: base.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 强光。blend < 128 时用颜色加深，否则用颜色减淡。
pub fn blend_hard_light(
  base : @types.Image,
  blend : @types.Image,
) -> @types.Image raise @types.LoadError {
  if base.width != blend.width ||
    base.height != blend.height ||
    base.channels != blend.channels {
    raise @types.LoadError::DecodeFailed(
      "blend 两图尺寸/通道数必须相同",
    )
  }
  let n = base.width * base.height * base.channels
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    let b = base.data[i].to_int()
    let l = blend.data[i].to_int()
    out[i] = if l < 128 {
      clamp_byte_v(2 * b * l / 255)
    } else {
      clamp_byte_v(255 - 2 * (255 - b) * (255 - l) / 255)
    }
  }
  @types.Image::{
    width: base.width,
    height: base.height,
    channels: base.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 柔光。基于 blend 的亮度在乘法和滤色之间平滑过渡。
/// result = (1 - 2*blend/255) * base^2/255 + (2*blend/255) * base
pub fn blend_soft_light(
  base : @types.Image,
  blend : @types.Image,
) -> @types.Image raise @types.LoadError {
  if base.width != blend.width ||
    base.height != blend.height ||
    base.channels != blend.channels {
    raise @types.LoadError::DecodeFailed(
      "blend 两图尺寸/通道数必须相同",
    )
  }
  let n = base.width * base.height * base.channels
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    let b = base.data[i].to_int()
    let l = blend.data[i].to_int()
    let w = 2 * l
    out[i] = clamp_byte_v((255 - w) * b * b / (255 * 255) + w * b / 255)
  }
  @types.Image::{
    width: base.width,
    height: base.height,
    channels: base.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 线性减淡（相加）。result = min(base + blend, 255)。
pub fn blend_linear_dodge(
  base : @types.Image,
  blend : @types.Image,
) -> @types.Image raise @types.LoadError {
  if base.width != blend.width ||
    base.height != blend.height ||
    base.channels != blend.channels {
    raise @types.LoadError::DecodeFailed(
      "blend 两图尺寸/通道数必须相同",
    )
  }
  let n = base.width * base.height * base.channels
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    let b = base.data[i].to_int()
    let l = blend.data[i].to_int()
    out[i] = clamp_byte_v(b + l)
  }
  @types.Image::{
    width: base.width,
    height: base.height,
    channels: base.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 线性加深（相减）。result = max(base + blend - 255, 0)。
pub fn blend_linear_burn(
  base : @types.Image,
  blend : @types.Image,
) -> @types.Image raise @types.LoadError {
  if base.width != blend.width ||
    base.height != blend.height ||
    base.channels != blend.channels {
    raise @types.LoadError::DecodeFailed(
      "blend 两图尺寸/通道数必须相同",
    )
  }
  let n = base.width * base.height * base.channels
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    let b = base.data[i].to_int()
    let l = blend.data[i].to_int()
    out[i] = clamp_byte_v(b + l - 255)
  }
  @types.Image::{
    width: base.width,
    height: base.height,
    channels: base.channels,
    data: Bytes::from_array(out),
  }
}
