// Canny 边缘检测（纯 MoonBit）

///|
/// Canny 边缘检测。
/// 步骤：高斯模糊 → Sobel 梯度 → 非极大值抑制 → 双阈值 + 滞后连接。
/// 适用于灰度图（channels=1）或 RGB/RGBA 图（channels=3/4，自动转灰度）。
/// low_threshold 和 high_threshold 为双阈值（low 应 < high）。
pub fn canny_edge(
  img : @types.Image,
  low_threshold? : Int = 50,
  high_threshold? : Int = 100,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "canny_edge: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("canny_edge: 仅支持 channels=1/3/4")
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "canny_edge: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if low_threshold < 0 || low_threshold > 255 {
    raise @types.LoadError::DecodeFailed(
      "low_threshold 必须在 0..255 之间",
    )
  }
  if high_threshold < 0 || high_threshold > 255 {
    raise @types.LoadError::DecodeFailed(
      "high_threshold 必须在 0..255 之间",
    )
  }
  if low_threshold > high_threshold {
    raise @types.LoadError::DecodeFailed("low_threshold 应 <= high_threshold")
  }
  let w = img.width
  let h = img.height
  let n = w * h
  if n == 0 {
    return img
  }
  // 转灰度
  let gray : Array[Int] = Array::make(n, 0)
  let ch = img.channels
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
  // 1. 高斯模糊 (sigma=1.0, 5x5 核)
  let blurred = canny_gaussian_blur(gray, w, h)
  // 2. Sobel 梯度
  let gradient : Array[Int] = Array::make(n, 0)
  let direction : Array[Int] = Array::make(n, 0) // 0=0°, 1=45°, 2=90°, 3=135°
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      // Sobel X
      let gx = -blurred[(y - 1) * w + (x - 1)] -
        2 * blurred[y * w + (x - 1)] -
        blurred[(y + 1) * w + (x - 1)] +
        blurred[(y - 1) * w + (x + 1)] +
        2 * blurred[y * w + (x + 1)] +
        blurred[(y + 1) * w + (x + 1)]
      // Sobel Y
      let gy = -blurred[(y - 1) * w + (x - 1)] -
        2 * blurred[(y - 1) * w + x] -
        blurred[(y - 1) * w + (x + 1)] +
        blurred[(y + 1) * w + (x - 1)] +
        2 * blurred[(y + 1) * w + x] +
        blurred[(y + 1) * w + (x + 1)]
      // 梯度幅值（sqrt 比 powf(x, 0.5) 更快）
      let mag = Float::from_int(gx * gx + gy * gy).sqrt().to_int()
      gradient[idx] = mag
      // 梯度方向量化到 4 个方向
      let angle = @math.atan2f(Float::from_int(gy), Float::from_int(gx)) *
        180.0F /
        3.14159265F
      let norm_angle = if angle < 0.0F { angle + 180.0F } else { angle }
      direction[idx] = if norm_angle < 22.5F || norm_angle >= 157.5F {
        0 // 水平
      } else if norm_angle < 67.5F {
        1 // 45°
      } else if norm_angle < 112.5F {
        2 // 垂直
      } else {
        3 // 135°
      }
    }
  }
  // 3. 非极大值抑制
  let nms : Array[Int] = Array::make(n, 0)
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let mag = gradient[idx]
      if mag == 0 {
        continue
      }
      let dir = direction[idx]
      let (n1, n2) = match dir {
        0 => (gradient[idx - 1], gradient[idx + 1]) // 水平：比较左右
        1 => (gradient[(y - 1) * w + (x + 1)], gradient[(y + 1) * w + (x - 1)]) // 45°
        2 => (gradient[(y - 1) * w + x], gradient[(y + 1) * w + x]) // 垂直：比较上下
        _ => (gradient[(y - 1) * w + (x - 1)], gradient[(y + 1) * w + (x + 1)]) // 135°
      }
      if mag >= n1 && mag >= n2 {
        nms[idx] = mag
      }
    }
  }
  // 4. 双阈值 + 滞后连接
  let out : Array[Byte] = Array::make(n, b'\x00')
  let strong : Array[Bool] = Array::make(n, false)
  let weak : Array[Bool] = Array::make(n, false)
  for i in 0..<n {
    if nms[i] >= high_threshold {
      strong[i] = true
    } else if nms[i] >= low_threshold {
      weak[i] = true
    }
  }
  // 滞后连接：弱边缘如果与强边缘连通则保留
  let stack : Array[Int] = []
  for i in 0..<n {
    if strong[i] {
      out[i] = b'\xFF'
      stack.push(i)
    }
  }
  while stack.length() > 0 {
    let idx = stack.remove(stack.length() - 1)
    let x = idx % w
    let y = idx / w
    // 8 邻域
    for dy in -1..<=1 {
      for dx in -1..<=1 {
        if dx == 0 && dy == 0 {
          continue
        }
        let nx = x + dx
        let ny = y + dy
        if nx >= 0 && nx < w && ny >= 0 && ny < h {
          let nidx = ny * w + nx
          if weak[nidx] && !strong[nidx] {
            strong[nidx] = true
            out[nidx] = b'\xFF'
            stack.push(nidx)
          }
        }
      }
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
/// 5x5 高斯模糊（sigma=1.0），分离内部/边界区域以消除热点 clamp 调用
fn canny_gaussian_blur(gray : Array[Int], w : Int, h : Int) -> Array[Int] {
  let n = w * h
  let out : Array[Int] = Array::make(n, 0)
  // 5x5 高斯核 (sigma=1.0)
  let kernel : Array[Int] = [
    2, 4, 5, 4, 2, 4, 9, 12, 9, 4, 5, 12, 15, 12, 5, 4, 9, 12, 9, 4, 2, 4, 5, 4,
    2,
  ]
  let kernel_sum = 159
  // 内部区域：x in [2, w-2), y in [2, h-2)，5x5 核完全在图像内，无需 clamp
  for y in 2..<(h - 2) {
    for x in 2..<(w - 2) {
      let mut sum = 0
      let base = (y - 2) * w + (x - 2)
      for ky in 0..<5 {
        let row = base + ky * w
        let krow = ky * 5
        for kx in 0..<5 {
          sum += gray[row + kx] * kernel[krow + kx]
        }
      }
      out[y * w + x] = sum / kernel_sum
    }
  }
  // 边界区域：5x5 核可能超出图像，需要 clamp
  for y in 0..<h {
    let y_inner = y >= 2 && y < h - 2
    for x in 0..<w {
      if y_inner && x >= 2 && x < w - 2 {
        continue
      }
      let mut sum = 0
      for ky in 0..<5 {
        for kx in 0..<5 {
          let px = (x + kx - 2).clamp(min=0, max=w - 1)
          let py = (y + ky - 2).clamp(min=0, max=h - 1)
          sum += gray[py * w + px] * kernel[ky * 5 + kx]
        }
      }
      out[y * w + x] = sum / kernel_sum
    }
  }
  out
}
