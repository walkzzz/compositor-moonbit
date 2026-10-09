// Haar 小波变换（纯 MoonBit）

///|
/// Haar 小波变换结果
pub struct HaarWaveletResult {
  width : Int
  height : Int
  levels : Int // 分解层数
  coefficients : Array[Float] // 小波系数
}

///|
/// 一维 Haar 小波变换（原地）。
/// 对长度为 n（2 的幂）的数组进行 Haar 变换。
pub fn haar_transform_1d(data : Array[Float]) -> Array[Float] {
  let n = data.length()
  if n < 2 {
    return data.copy()
  }
  let out = data.copy()
  let sqrt2 = 2.0F.sqrt()
  let mut len = n
  while len > 1 {
    let half = len / 2
    let temp : Array[Float] = Array::make(len, 0.0F)
    for i in 0..<half {
      temp[i] = (out[2 * i] + out[2 * i + 1]) / sqrt2
      temp[half + i] = (out[2 * i] - out[2 * i + 1]) / sqrt2
    }
    for i in 0..<len {
      out[i] = temp[i]
    }
    len = half
  }
  out
}

///|
/// 一维 Haar 小波逆变换。
pub fn ihaar_transform_1d(data : Array[Float]) -> Array[Float] {
  let n = data.length()
  if n < 2 {
    return data.copy()
  }
  let out = data.copy()
  let sqrt2 = 2.0F.sqrt()
  // 从最小级别开始逆变换
  let mut len = 2
  while len <= n {
    let half = len / 2
    let temp : Array[Float] = Array::make(len, 0.0F)
    for i in 0..<half {
      temp[2 * i] = (out[i] + out[half + i]) / sqrt2
      temp[2 * i + 1] = (out[i] - out[half + i]) / sqrt2
    }
    for i in 0..<len {
      out[i] = temp[i]
    }
    len *= 2
  }
  out
}

///|
/// 二维 Haar 小波变换。
/// 适用于灰度图（channels=1）或 RGB/RGBA 图（channels=3/4，自动转灰度）。
/// levels 为分解层数。
pub fn haar_transform_2d(
  img : @types.Image,
  levels? : Int = 1,
) -> HaarWaveletResult raise @types.LoadError {
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "haar_transform_2d 仅支持 channels=1/3/4",
    )
  }
  if levels < 1 || levels > 10 {
    raise @types.LoadError::DecodeFailed("levels 必须在 1..10 之间")
  }
  let w = img.width
  let h = img.height
  let n = w * h
  if n == 0 {
    return HaarWaveletResult::{
      width: w,
      height: h,
      levels: 0,
      coefficients: [],
    }
  }
  // 转灰度为 Float
  let coeffs : Array[Float] = Array::make(n, 0.0F)
  let ch = img.channels
  let data_int : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    data_int[i] = img.data[i].to_int()
  }
  for i in 0..<n {
    let v = if ch == 1 {
      data_int[i]
    } else {
      let r = data_int[i * ch]
      let g = data_int[i * ch + 1]
      let b = data_int[i * ch + 2]
      (r * 299 + g * 587 + b * 114) / 1000
    }
    coeffs[i] = Float::from_int(v)
  }
  // 多级分解
  let mut cur_w = w
  let mut cur_h = h
  for _ in 0..<levels {
    if cur_w < 2 || cur_h < 2 {
      break
    }
    // 行变换
    for y in 0..<cur_h {
      let row : Array[Float] = Array::make(cur_w, 0.0F)
      for x in 0..<cur_w {
        row[x] = coeffs[y * w + x]
      }
      let transformed = haar_transform_1d(row)
      for x in 0..<cur_w {
        coeffs[y * w + x] = transformed[x]
      }
    }
    // 列变换
    for x in 0..<cur_w {
      let col : Array[Float] = Array::make(cur_h, 0.0F)
      for y in 0..<cur_h {
        col[y] = coeffs[y * w + x]
      }
      let transformed = haar_transform_1d(col)
      for y in 0..<cur_h {
        coeffs[y * w + x] = transformed[y]
      }
    }
    cur_w /= 2
    cur_h /= 2
  }
  HaarWaveletResult::{ width: w, height: h, levels, coefficients: coeffs }
}

///|
/// 二维 Haar 小波逆变换。
pub fn haar_inverse_transform_2d(result : HaarWaveletResult) -> @types.Image {
  let w = result.width
  let h = result.height
  let n = w * h
  if n == 0 {
    return @types.Image::{
      width: 0,
      height: 0,
      channels: 1,
      data: Bytes::from_array([]),
    }
  }
  let coeffs = result.coefficients.copy()
  // 多级重构（从最小级别开始）
  let mut cur_w = w
  let mut cur_h = h
  for _ in 0..<result.levels {
    if cur_w < 2 || cur_h < 2 {
      break
    }
    cur_w /= 2
    cur_h /= 2
  }
  for _ in 0..<result.levels {
    if cur_w * 2 > w || cur_h * 2 > h {
      break
    }
    cur_w *= 2
    cur_h *= 2
    // 列逆变换
    for x in 0..<cur_w {
      let col : Array[Float] = Array::make(cur_h, 0.0F)
      for y in 0..<cur_h {
        col[y] = coeffs[y * w + x]
      }
      let inversed = ihaar_transform_1d(col)
      for y in 0..<cur_h {
        coeffs[y * w + x] = inversed[y]
      }
    }
    // 行逆变换
    for y in 0..<cur_h {
      let row : Array[Float] = Array::make(cur_w, 0.0F)
      for x in 0..<cur_w {
        row[x] = coeffs[y * w + x]
      }
      let inversed = ihaar_transform_1d(row)
      for x in 0..<cur_w {
        coeffs[y * w + x] = inversed[x]
      }
    }
  }
  // 转为图像
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    let val = coeffs[i].to_int()
    out[i] = val.clamp(min=0, max=255).to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// Haar 小波去噪（阈值去噪）。
/// 对小波系数应用软阈值或硬阈值，然后逆变换重构。
/// 适用于灰度图（channels=1）或 RGB/RGBA 图（channels=3/4，自动转灰度）。
/// threshold 为阈值，soft=true 为软阈值，false 为硬阈值。
pub fn haar_denoise(
  img : @types.Image,
  threshold? : Float = 10.0F,
  soft? : Bool = true,
  levels? : Int = 3,
) -> @types.Image raise @types.LoadError {
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "haar_denoise 仅支持 channels=1/3/4",
    )
  }
  let result = haar_transform_2d(img, levels~)
  let w = result.width
  let h = result.height
  let coeffs = result.coefficients
  // 阈值处理（保留低频系数不变）
  let low_w = w >> levels
  let low_h = h >> levels
  for y in 0..<h {
    for x in 0..<w {
      // 保留低频区域
      if x < low_w && y < low_h {
        continue
      }
      let idx = y * w + x
      let c = coeffs[idx]
      if soft {
        // 软阈值
        if c > threshold {
          coeffs[idx] = c - threshold
        } else if c < -threshold {
          coeffs[idx] = c + threshold
        } else {
          coeffs[idx] = 0.0F
        }
        // 硬阈值
      } else if c.abs() < threshold {
        coeffs[idx] = 0.0F
      }
    }
  }
  haar_inverse_transform_2d(result)
}
