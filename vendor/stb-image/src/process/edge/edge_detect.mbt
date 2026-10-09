// 边缘检测扩展（纯 MoonBit）：edge_detect_laplacian / edge_detect_prewitt / edge_detect_sobel
// clamp_b 来自 pixel_advanced.mbt，clamp_i 来自 morphology.mbt

///|
/// Sobel 边缘检测。先转灰度，然后计算梯度幅值。
/// 输出为单通道灰度图（channels=1）。
pub fn edge_detect_sobel(
  img : @types.Image,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "edge_detect_sobel: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "edge_detect_sobel: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "edge_detect_sobel: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let w = img.width
  let h = img.height
  let ch = img.channels
  let n = w * h
  // 先转灰度
  let gray : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    if ch == 1 {
      gray[i] = img.data[i].to_int()
    } else {
      let r = img.data[i * ch].to_int()
      let g = img.data[i * ch + 1].to_int()
      let b = img.data[i * ch + 2].to_int()
      gray[i] = (r * 299 + g * 587 + b * 114) / 1000
    }
  }
  // Sobel 卷积
  let out : Array[Byte] = Array::make(n, b'\x00')
  // 内部区域：1 <= x < w-1 && 1 <= y < h-1，无需 clamp
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let idx_l = idx - 1
      let idx_r = idx + 1
      let idx_t = idx - w
      let idx_b = idx + w
      // Gx = [-1 0 1; -2 0 2; -1 0 1]
      let gx = -gray[idx_t - 1] +
        gray[idx_t + 1] -
        2 * gray[idx_l] +
        2 * gray[idx_r] -
        gray[idx_b - 1] +
        gray[idx_b + 1]
      // Gy = [-1 -2 -1; 0 0 0; 1 2 1]
      let gy = -gray[idx_t - 1] -
        2 * gray[idx_t] -
        gray[idx_t + 1] +
        gray[idx_b - 1] +
        2 * gray[idx_b] +
        gray[idx_b + 1]
      let mag = Float::from_int(gx * gx + gy * gy).sqrt()
      out[idx] = (mag + 0.5F).to_int().clamp(min=0, max=255).to_byte()
    }
  }
  // 边界区域
  for y in 0..<h {
    for x in 0..<w {
      if x >= 1 && x < w - 1 && y >= 1 && y < h - 1 {
        continue
      }
      let x_l = clamp_i(x - 1, 0, w - 1)
      let x_r = clamp_i(x + 1, 0, w - 1)
      let y_t = clamp_i(y - 1, 0, h - 1)
      let y_b = clamp_i(y + 1, 0, h - 1)
      let gx = -gray[y_t * w + x_l] +
        gray[y_t * w + x_r] -
        2 * gray[y * w + x_l] +
        2 * gray[y * w + x_r] -
        gray[y_b * w + x_l] +
        gray[y_b * w + x_r]
      let gy = -gray[y_t * w + x_l] -
        2 * gray[y_t * w + x] -
        gray[y_t * w + x_r] +
        gray[y_b * w + x_l] +
        2 * gray[y_b * w + x] +
        gray[y_b * w + x_r]
      let mag = Float::from_int(gx * gx + gy * gy).sqrt()
      out[y * w + x] = (mag + 0.5F).to_int().clamp(min=0, max=255).to_byte()
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// Laplacian 边缘检测。使用 3x3 Laplacian 核：
/// [0, 1, 0; 1, -4, 1; 0, 1, 0]
/// 返回灰度图（channels=1）。
pub fn edge_detect_laplacian(
  img : @types.Image,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "edge_detect_laplacian: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "edge_detect_laplacian: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "edge_detect_laplacian: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let out : Array[Byte] = Array::make(n, b'\x00')
  // 预计算灰度 Int 数组
  let gray : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    if ch >= 3 {
      let r = img.data[i * ch].to_int()
      let g = img.data[i * ch + 1].to_int()
      let b = img.data[i * ch + 2].to_int()
      gray[i] = (r * 77 + g * 150 + b * 29) / 256
    } else {
      gray[i] = img.data[i * ch].to_int()
    }
  }
  // 内部区域：x in [1, w-1), y in [1, h-1)，直接访问 4 邻域
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let center = gray[idx]
      let u = gray[idx - w]
      let d = gray[idx + w]
      let l = gray[idx - 1]
      let r = gray[idx + 1]
      let lap = u + d + l + r - 4 * center
      out[idx] = clamp_b(lap.abs())
    }
  }
  // 边界区域
  for y in 0..<h {
    let y_inner = y >= 1 && y < h - 1
    for x in 0..<w {
      if y_inner && x >= 1 && x < w - 1 {
        continue
      }
      let cx = clamp_i(x, 0, w - 1)
      let cy = clamp_i(y, 0, h - 1)
      let up = clamp_i(y - 1, 0, h - 1)
      let down = clamp_i(y + 1, 0, h - 1)
      let left = clamp_i(x - 1, 0, w - 1)
      let right = clamp_i(x + 1, 0, w - 1)
      let center = gray[cy * w + cx]
      let u = gray[up * w + cx]
      let d = gray[down * w + cx]
      let l = gray[cy * w + left]
      let r = gray[cy * w + right]
      let lap = u + d + l + r - 4 * center
      out[y * w + x] = clamp_b(lap.abs())
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// Prewitt 边缘检测。使用两个 3x3 Prewitt 核计算梯度幅值。
/// Gx = [-1, 0, 1; -1, 0, 1; -1, 0, 1]
/// Gy = [-1, -1, -1; 0, 0, 0; 1, 1, 1]
/// 返回灰度图（channels=1）。
pub fn edge_detect_prewitt(
  img : @types.Image,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "edge_detect_prewitt: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "edge_detect_prewitt: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "edge_detect_prewitt: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let out : Array[Byte] = Array::make(n, b'\x00')
  // 预计算灰度 Int 数组
  let gray : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    if ch >= 3 {
      let r = img.data[i * ch].to_int()
      let g = img.data[i * ch + 1].to_int()
      let b = img.data[i * ch + 2].to_int()
      gray[i] = (r * 77 + g * 150 + b * 29) / 256
    } else {
      gray[i] = img.data[i * ch].to_int()
    }
  }
  // 内部区域：x in [1, w-1), y in [1, h-1)
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let ul = gray[idx - w - 1]
      let ur = gray[idx - w + 1]
      let ll = gray[idx + w - 1]
      let lr = gray[idx + w + 1]
      let l = gray[idx - 1]
      let r = gray[idx + 1]
      let u = gray[idx - w]
      let d = gray[idx + w]
      let gx = ur + r + lr - ul - l - ll
      let gy = ll + d + lr - ul - u - ur
      let mag = Float::from_int(gx * gx + gy * gy).sqrt()
      out[idx] = clamp_b(mag.to_int())
    }
  }
  // 边界区域
  for y in 0..<h {
    let y_inner = y >= 1 && y < h - 1
    for x in 0..<w {
      if y_inner && x >= 1 && x < w - 1 {
        continue
      }
      let up = clamp_i(y - 1, 0, h - 1)
      let down = clamp_i(y + 1, 0, h - 1)
      let left = clamp_i(x - 1, 0, w - 1)
      let right = clamp_i(x + 1, 0, w - 1)
      let ul = gray[up * w + left]
      let ur = gray[up * w + right]
      let ll = gray[down * w + left]
      let lr = gray[down * w + right]
      let l = gray[y * w + left]
      let r = gray[y * w + right]
      let u = gray[up * w + x]
      let d = gray[down * w + x]
      let gx = ur + r + lr - ul - l - ll
      let gy = ll + d + lr - ul - u - ur
      let mag = Float::from_int(gx * gx + gy * gy).sqrt()
      out[y * w + x] = clamp_b(mag.to_int())
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out),
  }
}
