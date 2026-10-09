// color_convert.mbt：色彩空间与通道操作
// 本文件包含两类操作：
//   1. 色彩空间转换：rgb_to_hsv/hsv_to_rgb、rgb_to_xyz/xyz_to_rgb、rgb_to_lab/lab_to_rgb、
//      rgb_to_ycbcr/ycbcr_to_rgb、rgb_to_cmyk/cmyk_to_rgb 等
//   2. 通道操作：to_grayscale/to_rgb/to_rgba、premultiply_alpha/unpremultiply_alpha 等

///|
/// 转为灰度图（channels=1）
/// 使用 ITU-R BT.601 亮度公式: Y = 0.299R + 0.587G + 0.114B
/// 优化：直接从 Bytes 读取，避免额外数组分配
pub fn to_grayscale(img : @types.Image) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "to_grayscale: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "to_grayscale: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "to_grayscale: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if img.channels == 1 {
    return img
  }
  let pixel_count = img.width * img.height
  let ch = img.channels
  let out : Array[Byte] = Array::make(pixel_count, b'\x00')
  let data = img.data
  for i in 0..<pixel_count {
    let base = i * ch
    let r = data[base].to_int()
    let g = data[base + 1].to_int()
    let b = data[base + 2].to_int()
    let gray = (r * 299 + g * 587 + b * 114) / 1000
    out[i] = gray.to_byte()
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// 去除 alpha 通道（RGBA → RGB，channels=3）
pub fn to_rgb(img : @types.Image) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("to_rgb: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed("to_rgb: 通道数必须在1-4之间")
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "to_rgb: 数据大小不匹配，期望 " +
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
  let pixel_count = img.width * img.height
  let out : Array[Byte] = Array::make(pixel_count * 3, b'\x00')
  for i in 0..<pixel_count {
    out[i * 3] = img.data[i * img.channels]
    out[i * 3 + 1] = img.data[i * img.channels + 1]
    out[i * 3 + 2] = img.data[i * img.channels + 2]
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: 3,
    data: Bytes::from_array(out),
  }
}

///|
/// 添加 alpha 通道（RGB → RGBA，channels=4，alpha=255）
pub fn to_rgba(img : @types.Image) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("to_rgba: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed("to_rgba: 通道数必须在1-4之间")
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "to_rgba: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if img.channels == 4 {
    return img
  }
  let pixel_count = img.width * img.height
  let out : Array[Byte] = Array::make(pixel_count * 4, b'\x00')
  for i in 0..<pixel_count {
    let src_ch = img.channels
    out[i * 4] = img.data[i * src_ch]
    out[i * 4 + 1] = if src_ch >= 2 {
      img.data[i * src_ch + 1]
    } else {
      b'\x00'
    }
    out[i * 4 + 2] = if src_ch >= 3 {
      img.data[i * src_ch + 2]
    } else {
      b'\x00'
    }
    out[i * 4 + 3] = b'\xFF'
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: 4,
    data: Bytes::from_array(out),
  }
}

///|
/// 预乘 alpha（RGBA → RGBA premultiplied）
/// 要求 channels=4
pub fn premultiply_alpha(
  img : @types.Image,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "premultiply_alpha: 图像尺寸必须大于0",
    )
  }
  if img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "premultiply_alpha 需要 channels=4 (RGBA)",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "premultiply_alpha: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let pixel_count = img.width * img.height
  let data_int : Array[Int] = Array::make(pixel_count * 4, 0)
  for i in 0..<(pixel_count * 4) {
    data_int[i] = img.data[i].to_int()
  }
  let out : Array[Byte] = Array::make(pixel_count * 4, b'\x00')
  for i in 0..<pixel_count {
    let r = data_int[i * 4]
    let g = data_int[i * 4 + 1]
    let b = data_int[i * 4 + 2]
    let a = data_int[i * 4 + 3]
    out[i * 4] = (r * a / 255).to_byte()
    out[i * 4 + 1] = (g * a / 255).to_byte()
    out[i * 4 + 2] = (b * a / 255).to_byte()
    out[i * 4 + 3] = a.to_byte()
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: 4,
    data: Bytes::from_array(out),
  }
}

///|
/// 反预乘 alpha（RGBA premA → RGBA unpremultiplied）
/// 要求 channels=4
pub fn unpremultiply_alpha(
  img : @types.Image,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "unpremultiply_alpha: 图像尺寸必须大于0",
    )
  }
  if img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "unpremultiply_alpha 需要 channels=4 (RGBA)",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "unpremultiply_alpha: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let pixel_count = img.width * img.height
  let data_int : Array[Int] = Array::make(pixel_count * 4, 0)
  for i in 0..<(pixel_count * 4) {
    data_int[i] = img.data[i].to_int()
  }
  let out : Array[Byte] = Array::make(pixel_count * 4, b'\x00')
  for i in 0..<pixel_count {
    let r = data_int[i * 4]
    let g = data_int[i * 4 + 1]
    let b = data_int[i * 4 + 2]
    let a = data_int[i * 4 + 3]
    if a == 0 {
      out[i * 4] = b'\x00'
      out[i * 4 + 1] = b'\x00'
      out[i * 4 + 2] = b'\x00'
      out[i * 4 + 3] = b'\x00'
    } else {
      out[i * 4] = (r * 255 / a).to_byte()
      out[i * 4 + 1] = (g * 255 / a).to_byte()
      out[i * 4 + 2] = (b * 255 / a).to_byte()
      out[i * 4 + 3] = a.to_byte()
    }
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: 4,
    data: Bytes::from_array(out),
  }
}

///|
/// RGB → YCbCr（ITU-R BT.601）。返回 (Y, Cb, Cr)，范围 0-255。
pub fn rgb_to_ycbcr(
  r : Int,
  g : Int,
  b : Int,
) -> (Int, Int, Int) raise @types.LoadError {
  // 输入验证
  if r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255 {
    raise @types.LoadError::DecodeFailed(
      "rgb_to_ycbcr: r,g,b必须在[0,255]范围内",
    )
  }
  let y = (299 * r + 587 * g + 114 * b) / 1000
  let cb = (-169 * r - 331 * g + 500 * b) / 1000 + 128
  let cr = (500 * r - 419 * g - 81 * b) / 1000 + 128
  (y.clamp(min=0, max=255), cb.clamp(min=0, max=255), cr.clamp(min=0, max=255))
}

///|
/// YCbCr → RGB（ITU-R BT.601）。输入范围 0-255。
pub fn ycbcr_to_rgb(
  y : Int,
  cb : Int,
  cr : Int,
) -> (Int, Int, Int) raise @types.LoadError {
  // 输入验证
  if y < 0 || y > 255 || cb < 0 || cb > 255 || cr < 0 || cr > 255 {
    raise @types.LoadError::DecodeFailed(
      "ycbcr_to_rgb: y,cb,cr必须在[0,255]范围内",
    )
  }
  let cb0 = cb - 128
  let cr0 = cr - 128
  let r = y + 1402 * cr0 / 1000
  let g = y - 344 * cb0 / 1000 - 714 * cr0 / 1000
  let b = y + 1772 * cb0 / 1000
  (r.clamp(min=0, max=255), g.clamp(min=0, max=255), b.clamp(min=0, max=255))
}

///|
/// RGB → XYZ（sRGB, D65 白点）。返回 (X, Y, Z)，范围 0.0-1.0。
pub fn rgb_to_xyz(
  r : Int,
  g : Int,
  b : Int,
) -> (Float, Float, Float) raise @types.LoadError {
  // 输入验证
  if r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255 {
    raise @types.LoadError::DecodeFailed(
      "rgb_to_xyz: r,g,b必须在[0,255]范围内",
    )
  }
  fn linearize(c : Int) -> Float {
    let cf = Float::from_int(c) / 255.0F
    if cf <= 0.04045F {
      cf / 12.92F
    } else {
      @math.powf((cf + 0.055F) / 1.055F, 2.4F)
    }
  }
  let rl = linearize(r)
  let gl = linearize(g)
  let bl = linearize(b)
  let x = 0.4124F * rl + 0.3576F * gl + 0.1805F * bl
  let y = 0.2126F * rl + 0.7152F * gl + 0.0722F * bl
  let z = 0.0193F * rl + 0.1192F * gl + 0.9505F * bl
  (x, y, z)
}

///|
/// XYZ → RGB（sRGB, D65 白点）。输入范围 0.0-1.0。
pub fn xyz_to_rgb(
  x : Float,
  y : Float,
  z : Float,
) -> (Int, Int, Int) raise @types.LoadError {
  // 输入验证
  if x < 0.0F || x > 1.0F || y < 0.0F || y > 1.0F || z < 0.0F || z > 1.0F {
    raise @types.LoadError::DecodeFailed(
      "xyz_to_rgb: x,y,z必须在[0,1]范围内",
    )
  }
  let rl = 3.2406F * x - 1.5372F * y - 0.4986F * z
  let gl = -0.9689F * x + 1.8758F * y + 0.0415F * z
  let bl = 0.0557F * x - 0.2040F * y + 1.0570F * z
  fn srgb(c : Float) -> Int {
    let v = if c <= 0.0031308F {
      12.92F * c
    } else {
      1.055F * @math.powf(c, 1.0F / 2.4F) - 0.055F
    }
    (v * 255.0F + 0.5F).to_int().clamp(min=0, max=255)
  }
  (srgb(rl), srgb(gl), srgb(bl))
}

///|
/// RGB → Lab（CIELAB, D65 白点）。返回 (L, a, b)，L 范围 0-100，a/b 范围 -128-127。
pub fn rgb_to_lab(
  r : Int,
  g : Int,
  b : Int,
) -> (Float, Float, Float) raise @types.LoadError {
  // 输入验证
  if r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255 {
    raise @types.LoadError::DecodeFailed(
      "rgb_to_lab: r,g,b必须在[0,255]范围内",
    )
  }
  let (x, y, z) = rgb_to_xyz(r, g, b)
  let xn = 0.9505F
  let yn = 1.0F
  let zn = 1.089F
  fn f(t : Float) -> Float {
    if t > 0.008856F {
      @math.powf(t, 1.0F / 3.0F)
    } else {
      7.787F * t + 16.0F / 116.0F
    }
  }
  let fx = f(x / xn)
  let fy = f(y / yn)
  let fz = f(z / zn)
  let l = 116.0F * fy - 16.0F
  let a = 500.0F * (fx - fy)
  let b_val = 200.0F * (fy - fz)
  (l, a, b_val)
}

///|
/// Lab → RGB（CIELAB, D65 白点）。输入 L 范围 0-100，a/b 范围 -128-127。
pub fn lab_to_rgb(
  l : Float,
  a : Float,
  b : Float,
) -> (Int, Int, Int) raise @types.LoadError {
  // 输入验证
  if l < 0.0F || l > 100.0F {
    raise @types.LoadError::DecodeFailed(
      "lab_to_rgb: L必须在[0,100]范围内",
    )
  }
  let yn = 1.0F
  let xn = 0.9505F
  let zn = 1.089F
  let fy = (l + 16.0F) / 116.0F
  let fx = a / 500.0F + fy
  let fz = fy - b / 200.0F
  fn f_inv(t : Float) -> Float {
    if @math.powf(t, 3.0F) > 0.008856F {
      @math.powf(t, 3.0F)
    } else {
      (t - 16.0F / 116.0F) / 7.787F
    }
  }
  let x = xn * f_inv(fx)
  let y = yn * f_inv(fy)
  let z = zn * f_inv(fz)
  xyz_to_rgb(x, y, z)
}

///|
/// RGB → CMYK。返回 (C, M, Y, K)，范围 0-255。
pub fn rgb_to_cmyk(
  r : Int,
  g : Int,
  b : Int,
) -> (Int, Int, Int, Int) raise @types.LoadError {
  // 输入验证
  if r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255 {
    raise @types.LoadError::DecodeFailed(
      "rgb_to_cmyk: r,g,b必须在[0,255]范围内",
    )
  }
  let c = 255 - r
  let m = 255 - g
  let y = 255 - b
  let k = if c < m { if c < y { c } else { y } } else if m < y { m } else { y }
  if k == 255 {
    (0, 0, 0, 255)
  } else {
    let denom = 255 - k
    ((c - k) * 255 / denom, (m - k) * 255 / denom, (y - k) * 255 / denom, k)
  }
}

///|
/// CMYK → RGB。输入范围 0-255。
pub fn cmyk_to_rgb(
  c : Int,
  m : Int,
  y : Int,
  k : Int,
) -> (Int, Int, Int) raise @types.LoadError {
  // 输入验证
  if c < 0 ||
    c > 255 ||
    m < 0 ||
    m > 255 ||
    y < 0 ||
    y > 255 ||
    k < 0 ||
    k > 255 {
    raise @types.LoadError::DecodeFailed(
      "cmyk_to_rgb: c,m,y,k必须在[0,255]范围内",
    )
  }
  let r = 255 - (c * (255 - k) / 255 + k)
  let g = 255 - (m * (255 - k) / 255 + k)
  let b = 255 - (y * (255 - k) / 255 + k)
  (r.clamp(min=0, max=255), g.clamp(min=0, max=255), b.clamp(min=0, max=255))
}
