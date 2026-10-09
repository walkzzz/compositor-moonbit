// 颜色空间转换 16-bit/float 变体
// 支持 Image16 / ImageF 两种类型

// 复用 color_16f.mbt 中的 read_u16_le_c / write_u16_le_c / write_f32_le
// 复用 tonemap.mbt 中的 read_float_le

///|
fn clamp_float(v : Float) -> Float {
  if v < 0.0F {
    0.0F
  } else if v > 1.0F {
    1.0F
  } else {
    v
  }
}

///|
/// 16-bit 去除 alpha 通道（RGBA → RGB，channels=3）
pub fn to_rgb_16(img : @types.Image16) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width < 0 || img.height < 0 {
    raise @types.LoadError::DecodeFailed("to_rgb_16: 图像尺寸不能为负")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "to_rgb_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "to_rgb_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if img.channels == 3 {
    return img
  }
  if img.channels < 3 {
    return img
  }
  let n = img.width * img.height
  let src_ch = img.channels
  let src_bpp = src_ch * 2
  let out_bpp = 6
  let out : Array[Byte] = Array::make(n * out_bpp, b'\x00')
  for i in 0..<n {
    for c in 0..<3 {
      let src_off = i * src_bpp + c * 2
      let dst_off = i * out_bpp + c * 2
      out[dst_off] = img.data[src_off]
      out[dst_off + 1] = img.data[src_off + 1]
    }
  }
  @types.Image16::{
    width: img.width,
    height: img.height,
    channels: 3,
    data: Bytes::from_array(out),
  }
}

///|
/// float 去除 alpha 通道（RGBA → RGB，channels=3）
pub fn to_rgb_f(img : @types.ImageF) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("to_rgb_f: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "to_rgb_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "to_rgb_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if img.channels == 3 {
    return img
  }
  if img.channels < 3 {
    return img
  }
  let n = img.width * img.height
  let src_ch = img.channels
  let src_bpp = src_ch * 4
  let out_bpp = 12
  let out : Array[Byte] = Array::make(n * out_bpp, b'\x00')
  for i in 0..<n {
    for c in 0..<3 {
      let src_off = i * src_bpp + c * 4
      let dst_off = i * out_bpp + c * 4
      for b in 0..<4 {
        out[dst_off + b] = img.data[src_off + b]
      }
    }
  }
  @types.ImageF::{
    width: img.width,
    height: img.height,
    channels: 3,
    data: Bytes::from_array(out),
  }
}

///|
/// 16-bit 添加 alpha 通道（RGB → RGBA，channels=4，alpha=65535）
pub fn to_rgba_16(
  img : @types.Image16,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width < 0 || img.height < 0 {
    raise @types.LoadError::DecodeFailed("to_rgba_16: 图像尺寸不能为负")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "to_rgba_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "to_rgba_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if img.channels == 4 {
    return img
  }
  let n = img.width * img.height
  let src_ch = img.channels
  let src_bpp = src_ch * 2
  let out_bpp = 8
  let out : Array[Byte] = Array::make(n * out_bpp, b'\x00')
  for i in 0..<n {
    for c in 0..<3 {
      let src_off = if c < src_ch { i * src_bpp + c * 2 } else { -1 }
      let dst_off = i * out_bpp + c * 2
      if src_off >= 0 {
        out[dst_off] = img.data[src_off]
        out[dst_off + 1] = img.data[src_off + 1]
      }
    }
    // alpha = 65535
    let alpha_off = i * out_bpp + 6
    out[alpha_off] = b'\xFF'
    out[alpha_off + 1] = b'\xFF'
  }
  @types.Image16::{
    width: img.width,
    height: img.height,
    channels: 4,
    data: Bytes::from_array(out),
  }
}

///|
/// float 添加 alpha 通道（RGB → RGBA，channels=4，alpha=1.0）
pub fn to_rgba_f(img : @types.ImageF) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("to_rgba_f: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "to_rgba_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "to_rgba_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if img.channels == 4 {
    return img
  }
  let n = img.width * img.height
  let src_ch = img.channels
  let src_bpp = src_ch * 4
  let out_bpp = 16
  let out : Array[Byte] = Array::make(n * out_bpp, b'\x00')
  for i in 0..<n {
    for c in 0..<3 {
      if c < src_ch {
        let src_off = i * src_bpp + c * 4
        let dst_off = i * out_bpp + c * 4
        for b in 0..<4 {
          out[dst_off + b] = img.data[src_off + b]
        }
      }
    }
    // alpha = 1.0
    write_f32_le(out, i * out_bpp + 12, 1.0F)
  }
  @types.ImageF::{
    width: img.width,
    height: img.height,
    channels: 4,
    data: Bytes::from_array(out),
  }
}

///|
/// 16-bit 预乘 alpha（RGBA → RGBA premultiplied）。要求 channels=4。
pub fn premultiply_alpha_16(
  img : @types.Image16,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "premultiply_alpha_16: 图像尺寸必须大于0",
    )
  }
  if img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "premultiply_alpha_16 需要 channels=4 (RGBA)",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "premultiply_alpha_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let n = img.width * img.height
  let bpp = 8
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<n {
    let r = read_u16_le_c(img.data, i * bpp)
    let g = read_u16_le_c(img.data, i * bpp + 2)
    let b = read_u16_le_c(img.data, i * bpp + 4)
    let a = read_u16_le_c(img.data, i * bpp + 6)
    write_u16_le_c(out, i * bpp, r * a / 65535)
    write_u16_le_c(out, i * bpp + 2, g * a / 65535)
    write_u16_le_c(out, i * bpp + 4, b * a / 65535)
    write_u16_le_c(out, i * bpp + 6, a)
  }
  @types.Image16::{
    width: img.width,
    height: img.height,
    channels: 4,
    data: Bytes::from_array(out),
  }
}

///|
/// float 预乘 alpha（RGBA → RGBA premultiplied）。要求 channels=4。
pub fn premultiply_alpha_f(
  img : @types.ImageF,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "premultiply_alpha_f: 图像尺寸必须大于0",
    )
  }
  if img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "premultiply_alpha_f 需要 channels=4 (RGBA)",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "premultiply_alpha_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let n = img.width * img.height
  let bpp = 16
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<n {
    let r = read_float_le(img.data, i * bpp)
    let g = read_float_le(img.data, i * bpp + 4)
    let b = read_float_le(img.data, i * bpp + 8)
    let a = read_float_le(img.data, i * bpp + 12)
    write_f32_le(out, i * bpp, r * a)
    write_f32_le(out, i * bpp + 4, g * a)
    write_f32_le(out, i * bpp + 8, b * a)
    write_f32_le(out, i * bpp + 12, a)
  }
  @types.ImageF::{
    width: img.width,
    height: img.height,
    channels: 4,
    data: Bytes::from_array(out),
  }
}

///|
/// 16-bit 反预乘 alpha（RGBA premA → RGBA unpremultiplied）。要求 channels=4。
pub fn unpremultiply_alpha_16(
  img : @types.Image16,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "unpremultiply_alpha_16: 图像尺寸必须大于0",
    )
  }
  if img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "unpremultiply_alpha_16 需要 channels=4 (RGBA)",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "unpremultiply_alpha_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let n = img.width * img.height
  let bpp = 8
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<n {
    let r = read_u16_le_c(img.data, i * bpp)
    let g = read_u16_le_c(img.data, i * bpp + 2)
    let b = read_u16_le_c(img.data, i * bpp + 4)
    let a = read_u16_le_c(img.data, i * bpp + 6)
    if a == 0 {
      write_u16_le_c(out, i * bpp, 0)
      write_u16_le_c(out, i * bpp + 2, 0)
      write_u16_le_c(out, i * bpp + 4, 0)
      write_u16_le_c(out, i * bpp + 6, 0)
    } else {
      write_u16_le_c(out, i * bpp, r * 65535 / a)
      write_u16_le_c(out, i * bpp + 2, g * 65535 / a)
      write_u16_le_c(out, i * bpp + 4, b * 65535 / a)
      write_u16_le_c(out, i * bpp + 6, a)
    }
  }
  @types.Image16::{
    width: img.width,
    height: img.height,
    channels: 4,
    data: Bytes::from_array(out),
  }
}

///|
/// float 反预乘 alpha（RGBA premA → RGBA unpremultiplied）。要求 channels=4。
pub fn unpremultiply_alpha_f(
  img : @types.ImageF,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "unpremultiply_alpha_f: 图像尺寸必须大于0",
    )
  }
  if img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "unpremultiply_alpha_f 需要 channels=4 (RGBA)",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "unpremultiply_alpha_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let n = img.width * img.height
  let bpp = 16
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for i in 0..<n {
    let r = read_float_le(img.data, i * bpp)
    let g = read_float_le(img.data, i * bpp + 4)
    let b = read_float_le(img.data, i * bpp + 8)
    let a = read_float_le(img.data, i * bpp + 12)
    if a < 0.000001F {
      write_f32_le(out, i * bpp, 0.0F)
      write_f32_le(out, i * bpp + 4, 0.0F)
      write_f32_le(out, i * bpp + 8, 0.0F)
      write_f32_le(out, i * bpp + 12, 0.0F)
    } else {
      write_f32_le(out, i * bpp, r / a)
      write_f32_le(out, i * bpp + 4, g / a)
      write_f32_le(out, i * bpp + 8, b / a)
      write_f32_le(out, i * bpp + 12, a)
    }
  }
  @types.ImageF::{
    width: img.width,
    height: img.height,
    channels: 4,
    data: Bytes::from_array(out),
  }
}

// ===== 像素级颜色空间转换函数 =====

///|
/// 16-bit RGB → YCbCr（ITU-R BT.601）。输入范围 0-65535，输出范围 0-65535。
pub fn rgb_to_ycbcr_16(
  r : Int,
  g : Int,
  b : Int,
) -> (Int, Int, Int) raise @types.LoadError {
  // 输入验证
  if r < 0 || r > 65535 || g < 0 || g > 65535 || b < 0 || b > 65535 {
    raise @types.LoadError::DecodeFailed(
      "rgb_to_ycbcr_16: r,g,b必须在[0,65535]范围内",
    )
  }
  let y = (299 * r + 587 * g + 114 * b) / 1000
  let cb = (-169 * r - 331 * g + 500 * b) / 1000 + 32768
  let cr = (500 * r - 419 * g - 81 * b) / 1000 + 32768
  (
    y.clamp(min=0, max=65535),
    cb.clamp(min=0, max=65535),
    cr.clamp(min=0, max=65535),
  )
}

///|
/// float RGB → YCbCr（ITU-R BT.601）。输入范围 0.0-1.0，输出范围 0.0-1.0。
pub fn rgb_to_ycbcr_f(
  r : Float,
  g : Float,
  b : Float,
) -> (Float, Float, Float) raise @types.LoadError {
  // 输入验证
  if r < 0.0F || r > 1.0F || g < 0.0F || g > 1.0F || b < 0.0F || b > 1.0F {
    raise @types.LoadError::DecodeFailed(
      "rgb_to_ycbcr_f: r,g,b必须在[0,1]范围内",
    )
  }
  let y = 0.299F * r + 0.587F * g + 0.114F * b
  let cb = -0.169F * r - 0.331F * g + 0.5F * b + 0.5F
  let cr = 0.5F * r - 0.419F * g - 0.081F * b + 0.5F
  (clamp_float(y), clamp_float(cb), clamp_float(cr))
}

///|
/// 16-bit YCbCr → RGB（ITU-R BT.601）。输入范围 0-65535。
pub fn ycbcr_to_rgb_16(
  y : Int,
  cb : Int,
  cr : Int,
) -> (Int, Int, Int) raise @types.LoadError {
  // 输入验证
  if y < 0 || y > 65535 || cb < 0 || cb > 65535 || cr < 0 || cr > 65535 {
    raise @types.LoadError::DecodeFailed(
      "ycbcr_to_rgb_16: y,cb,cr必须在[0,65535]范围内",
    )
  }
  let cb0 = cb - 32768
  let cr0 = cr - 32768
  let r = y + 1402 * cr0 / 1000
  let g = y - 344 * cb0 / 1000 - 714 * cr0 / 1000
  let b = y + 1772 * cb0 / 1000
  (
    r.clamp(min=0, max=65535),
    g.clamp(min=0, max=65535),
    b.clamp(min=0, max=65535),
  )
}

///|
/// float YCbCr → RGB（ITU-R BT.601）。输入范围 0.0-1.0。
pub fn ycbcr_to_rgb_f(
  y : Float,
  cb : Float,
  cr : Float,
) -> (Float, Float, Float) raise @types.LoadError {
  // 输入验证
  if y < 0.0F || y > 1.0F || cb < 0.0F || cb > 1.0F || cr < 0.0F || cr > 1.0F {
    raise @types.LoadError::DecodeFailed(
      "ycbcr_to_rgb_f: y,cb,cr必须在[0,1]范围内",
    )
  }
  let cb0 = cb - 0.5F
  let cr0 = cr - 0.5F
  let r = y + 1.402F * cr0
  let g = y - 0.344F * cb0 - 0.714F * cr0
  let b = y + 1.772F * cb0
  (clamp_float(r), clamp_float(g), clamp_float(b))
}

///|
/// 16-bit RGB → CMYK。输入范围 0-65535，输出范围 0-65535。
pub fn rgb_to_cmyk_16(
  r : Int,
  g : Int,
  b : Int,
) -> (Int, Int, Int, Int) raise @types.LoadError {
  // 输入验证
  if r < 0 || r > 65535 || g < 0 || g > 65535 || b < 0 || b > 65535 {
    raise @types.LoadError::DecodeFailed(
      "rgb_to_cmyk_16: r,g,b必须在[0,65535]范围内",
    )
  }
  let c = 65535 - r
  let m = 65535 - g
  let y = 65535 - b
  let k = if c < m { if c < y { c } else { y } } else if m < y { m } else { y }
  if k == 65535 {
    (0, 0, 0, 65535)
  } else {
    let denom = 65535 - k
    (
      (c - k) * 65535 / denom,
      (m - k) * 65535 / denom,
      (y - k) * 65535 / denom,
      k,
    )
  }
}

///|
/// float RGB → CMYK。输入范围 0.0-1.0，输出范围 0.0-1.0。
pub fn rgb_to_cmyk_f(
  r : Float,
  g : Float,
  b : Float,
) -> (Float, Float, Float, Float) raise @types.LoadError {
  // 输入验证
  if r < 0.0F || r > 1.0F || g < 0.0F || g > 1.0F || b < 0.0F || b > 1.0F {
    raise @types.LoadError::DecodeFailed(
      "rgb_to_cmyk_f: r,g,b必须在[0,1]范围内",
    )
  }
  let c = 1.0F - r
  let m = 1.0F - g
  let y = 1.0F - b
  let k = if c < m { if c < y { c } else { y } } else if m < y { m } else { y }
  if k > 0.999999F {
    (0.0F, 0.0F, 0.0F, 1.0F)
  } else {
    let denom = 1.0F - k
    ((c - k) / denom, (m - k) / denom, (y - k) / denom, k)
  }
}

///|
/// 16-bit CMYK → RGB。输入范围 0-65535。
pub fn cmyk_to_rgb_16(
  c : Int,
  m : Int,
  y : Int,
  k : Int,
) -> (Int, Int, Int) raise @types.LoadError {
  // 输入验证
  if c < 0 ||
    c > 65535 ||
    m < 0 ||
    m > 65535 ||
    y < 0 ||
    y > 65535 ||
    k < 0 ||
    k > 65535 {
    raise @types.LoadError::DecodeFailed(
      "cmyk_to_rgb_16: c,m,y,k必须在[0,65535]范围内",
    )
  }
  let r = 65535 - (c * (65535 - k) / 65535 + k)
  let g = 65535 - (m * (65535 - k) / 65535 + k)
  let b = 65535 - (y * (65535 - k) / 65535 + k)
  (
    r.clamp(min=0, max=65535),
    g.clamp(min=0, max=65535),
    b.clamp(min=0, max=65535),
  )
}

///|
/// float CMYK → RGB。输入范围 0.0-1.0。
pub fn cmyk_to_rgb_f(
  c : Float,
  m : Float,
  y : Float,
  k : Float,
) -> (Float, Float, Float) raise @types.LoadError {
  // 输入验证
  if c < 0.0F ||
    c > 1.0F ||
    m < 0.0F ||
    m > 1.0F ||
    y < 0.0F ||
    y > 1.0F ||
    k < 0.0F ||
    k > 1.0F {
    raise @types.LoadError::DecodeFailed(
      "cmyk_to_rgb_f: c,m,y,k必须在[0,1]范围内",
    )
  }
  let r = 1.0F - (c * (1.0F - k) + k)
  let g = 1.0F - (m * (1.0F - k) + k)
  let b = 1.0F - (y * (1.0F - k) + k)
  (clamp_float(r), clamp_float(g), clamp_float(b))
}
