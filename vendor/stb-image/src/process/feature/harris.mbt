// Harris 角点检测（纯 MoonBit）

///|
/// 角点信息
pub(all) struct CornerPoint {
  x : Int
  y : Int
  response : Float // Harris 响应值
}

///|
/// Harris 角点检测。
/// 适用于灰度图（channels=1）或 RGB/RGBA 图（channels=3/4，自动转灰度）。
/// k 为 Harris 参数（默认 0.04），threshold 为响应阈值，min_distance 为角点间最小距离。
pub fn harris_corners(
  img : @types.Image,
  k? : Float = 0.04F,
  threshold? : Float = 1000.0F,
  min_distance? : Int = 5,
) -> Array[CornerPoint] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "harris_corners: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "harris_corners: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "harris_corners: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if k <= 0.0F {
    raise @types.LoadError::DecodeFailed("harris_corners: k必须大于0")
  }
  if threshold < 0.0F {
    raise @types.LoadError::DecodeFailed("harris_corners: threshold必须 >= 0")
  }
  if min_distance < 0 {
    raise @types.LoadError::DecodeFailed(
      "harris_corners: min_distance必须 >= 0",
    )
  }
  let w = img.width
  let h = img.height
  let n = w * h
  if n == 0 {
    return []
  }
  // 转灰度
  let gray : Array[Float] = Array::make(n, 0.0F)
  let ch = img.channels
  for i in 0..<n {
    let v = if ch == 1 {
      img.data[i].to_int()
    } else {
      let r = img.data[i * ch].to_int()
      let g = img.data[i * ch + 1].to_int()
      let b = img.data[i * ch + 2].to_int()
      (r * 299 + g * 587 + b * 114) / 1000
    }
    gray[i] = Float::from_int(v)
  }
  // Sobel 梯度
  let ix : Array[Float] = Array::make(n, 0.0F)
  let iy : Array[Float] = Array::make(n, 0.0F)
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      ix[idx] = (
          gray[(y - 1) * w + (x + 1)] +
          2.0F * gray[y * w + (x + 1)] +
          gray[(y + 1) * w + (x + 1)] -
          gray[(y - 1) * w + (x - 1)] -
          2.0F * gray[y * w + (x - 1)] -
          gray[(y + 1) * w + (x - 1)]
        ) /
        8.0F
      iy[idx] = (
          gray[(y + 1) * w + (x - 1)] +
          2.0F * gray[(y + 1) * w + x] +
          gray[(y + 1) * w + (x + 1)] -
          gray[(y - 1) * w + (x - 1)] -
          2.0F * gray[(y - 1) * w + x] -
          gray[(y - 1) * w + (x + 1)]
        ) /
        8.0F
    }
  }
  // 计算 Ix², Iy², IxIy
  let ixx : Array[Float] = Array::make(n, 0.0F)
  let iyy : Array[Float] = Array::make(n, 0.0F)
  let ixy : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    ixx[i] = ix[i] * ix[i]
    iyy[i] = iy[i] * iy[i]
    ixy[i] = ix[i] * iy[i]
  }
  // 高斯加权（sigma=1, 3x3 核）
  let sxx = harris_gaussian_blur(ixx, w, h)
  let syy = harris_gaussian_blur(iyy, w, h)
  let sxy = harris_gaussian_blur(ixy, w, h)
  // Harris 响应: R = det(M) - k * trace(M)²
  let response : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    let det = sxx[i] * syy[i] - sxy[i] * sxy[i]
    let trace = sxx[i] + syy[i]
    response[i] = det - k * trace * trace
  }
  // 非极大值抑制 + 阈值
  let candidates : Array[CornerPoint] = []
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let r = response[idx]
      if r < threshold {
        continue
      }
      // 检查是否为局部最大值
      let mut is_max = true
      for dy in -1..<=1 {
        for dx in -1..<=1 {
          if dx == 0 && dy == 0 {
            continue
          }
          if response[(y + dy) * w + (x + dx)] > r {
            is_max = false
            break
          }
        }
        if !is_max {
          break
        }
      }
      if is_max {
        candidates.push(CornerPoint::{ x, y, response: r })
      }
    }
  }
  // 按响应值排序（降序）
  candidates.sort_by(fn(a, b) { b.response.compare(a.response) })
  // 距离过滤
  let result : Array[CornerPoint] = []
  for c in candidates {
    let mut ok = true
    for r in result {
      let dx = c.x - r.x
      let dy = c.y - r.y
      if dx * dx + dy * dy < min_distance * min_distance {
        ok = false
        break
      }
    }
    if ok {
      result.push(c)
    }
  }
  result
}

///|
/// 3x3 高斯模糊（sigma=1.0），分离内部/边界区域以消除热点 clamp 调用
fn harris_gaussian_blur(data : Array[Float], w : Int, h : Int) -> Array[Float] {
  let n = w * h
  let out : Array[Float] = Array::make(n, 0.0F)
  let kernel : Array[Float] = [
    0.0625F, 0.125F, 0.0625F, 0.125F, 0.25F, 0.125F, 0.0625F, 0.125F, 0.0625F,
  ]
  // 内部区域：x in [1, w-1), y in [1, h-1)，3x3 核完全在图像内
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let base = (y - 1) * w + (x - 1)
      out[y * w + x] = data[base] * kernel[0] +
        data[base + 1] * kernel[1] +
        data[base + 2] * kernel[2] +
        data[base + w] * kernel[3] +
        data[base + w + 1] * kernel[4] +
        data[base + w + 2] * kernel[5] +
        data[base + 2 * w] * kernel[6] +
        data[base + 2 * w + 1] * kernel[7] +
        data[base + 2 * w + 2] * kernel[8]
    }
  }
  // 边界区域：需要 clamp
  for y in 0..<h {
    let y_inner = y >= 1 && y < h - 1
    for x in 0..<w {
      if y_inner && x >= 1 && x < w - 1 {
        continue
      }
      let mut sum = 0.0F
      for ky in 0..<3 {
        for kx in 0..<3 {
          let px = (x + kx - 1).clamp(min=0, max=w - 1)
          let py = (y + ky - 1).clamp(min=0, max=h - 1)
          sum += data[py * w + px] * kernel[ky * 3 + kx]
        }
      }
      out[y * w + x] = sum
    }
  }
  out
}

///|
/// 在图像上绘制角点。
pub fn draw_corners(
  img : @types.Image,
  corners : Array[CornerPoint],
  color? : Array[Byte] = [b'\xFF', b'\x00', b'\x00'],
  radius? : Int = 2,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "draw_corners: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "draw_corners: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "draw_corners: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if color.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "draw_corners: color数组不能为空",
    )
  }
  if radius < 0 {
    raise @types.LoadError::DecodeFailed("draw_corners: radius必须 >= 0")
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let out : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for i in 0..<(w * h * ch) {
    out[i] = img.data[i]
  }
  let draw_ch = if ch >= 3 { 3 } else { 1 }
  for corner in corners {
    for dy in -radius..<=radius {
      for dx in -radius..<=radius {
        let nx = corner.x + dx
        let ny = corner.y + dy
        if nx >= 0 && nx < w && ny >= 0 && ny < h {
          for c in 0..<draw_ch {
            if c < color.length() {
              out[(ny * w + nx) * ch + c] = color[c]
            }
          }
        }
      }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}
