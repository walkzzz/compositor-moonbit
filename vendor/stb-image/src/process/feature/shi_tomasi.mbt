// Shi-Tomasi 角点检测 (good_features_to_track)
// 基于 Harris 的结构张量，用 min eigenvalue 代替 Harris 响应

///|
/// Shi-Tomasi 角点检测（goodFeaturesToTrack）。
/// 使用结构张量的最小特征值作为响应：R = min(λ1, λ2)。
/// 适用于光流跟踪的前置角点检测。
pub fn good_features_to_track(
  img : @types.Image,
  max_corners : Int,
  quality_level : Float,
  min_distance? : Int = 5,
) -> Array[CornerPoint] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "good_features_to_track: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "good_features_to_track: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "good_features_to_track: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if max_corners <= 0 {
    raise @types.LoadError::DecodeFailed(
      "good_features_to_track: max_corners必须大于0",
    )
  }
  if quality_level <= 0.0F || quality_level > 1.0F {
    raise @types.LoadError::DecodeFailed(
      "good_features_to_track: quality_level必须在(0, 1]范围内",
    )
  }
  if min_distance < 0 {
    raise @types.LoadError::DecodeFailed(
      "good_features_to_track: min_distance必须 >= 0",
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
  // 结构张量分量
  let ixx : Array[Float] = Array::make(n, 0.0F)
  let iyy : Array[Float] = Array::make(n, 0.0F)
  let ixy : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    ixx[i] = ix[i] * ix[i]
    iyy[i] = iy[i] * iy[i]
    ixy[i] = ix[i] * iy[i]
  }
  // 高斯加权
  let sxx = shi_tomasi_gaussian_blur(ixx, w, h)
  let syy = shi_tomasi_gaussian_blur(iyy, w, h)
  let sxy = shi_tomasi_gaussian_blur(ixy, w, h)
  // Shi-Tomasi 响应: R = min(λ1, λ2) = (trace - sqrt(trace² - 4*det)) / 2
  let response : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    let det = sxx[i] * syy[i] - sxy[i] * sxy[i]
    let trace = sxx[i] + syy[i]
    let disc = trace * trace - 4.0F * det
    if disc < 0.0F {
      response[i] = 0.0F
    } else {
      response[i] = (trace - disc.sqrt()) / 2.0F
    }
  }
  // 找最大响应值用于 quality threshold
  let mut max_response = 0.0F
  for i in 0..<n {
    if response[i] > max_response {
      max_response = response[i]
    }
  }
  let threshold = max_response * quality_level
  // 非极大值抑制 + 阈值
  let candidates : Array[CornerPoint] = []
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let r = response[idx]
      if r <= threshold {
        continue
      }
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
    if result.length() >= max_corners {
      break
    }
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
fn shi_tomasi_gaussian_blur(
  data : Array[Float],
  w : Int,
  h : Int,
) -> Array[Float] {
  let n = w * h
  let out : Array[Float] = Array::make(n, 0.0F)
  let kernel : Array[Float] = [
    0.0625F, 0.125F, 0.0625F, 0.125F, 0.25F, 0.125F, 0.0625F, 0.125F, 0.0625F,
  ]
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
