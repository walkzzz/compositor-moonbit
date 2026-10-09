// SIFT 特征检测（纯 MoonBit）
// Scale-Invariant Feature Transform
// Lowe, "Distinctive Image Features from Scale-Invariant Keypoints" (2004)

///|
/// SIFT 关键点
pub(all) struct SiftKeyPoint {
  x : Float
  y : Float
  octave : Int
  layer : Int
  sigma : Float
  response : Float
  angle : Float
}

///|
/// SIFT 描述子（128 维）
pub(all) struct SiftDescriptor {
  kp : SiftKeyPoint
  data : Array[Float] // 128 维浮点描述子
}

///|
/// SIFT 特征检测。
/// 检测尺度不变关键点并计算 128 维描述子。
/// max_features 控制最大特征数，contrast_threshold 为对比度阈值。
pub fn sift_detect(
  img : @types.Image,
  max_features? : Int = 500,
  contrast_threshold? : Float = 0.04F,
) -> Array[SiftDescriptor] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "sift_detect: 图像尺寸必须大于0",
    )
  }
  if img.width < 16 || img.height < 16 {
    raise @types.LoadError::DecodeFailed(
      "sift_detect: SIFT 需要至少 16x16 图像",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "sift_detect: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "sift_detect: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if max_features <= 0 {
    raise @types.LoadError::DecodeFailed(
      "sift_detect: max_features必须大于0",
    )
  }
  if contrast_threshold <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "sift_detect: contrast_threshold必须大于0",
    )
  }
  let (gray, w, h) = to_gray_sift(img)
  let n_layers = 3
  let sigma0 = 1.6F
  let edge_thresh = 10.0F
  // 构建高斯金字塔: 每个元素为 (levels, w, h)
  let gauss_pyramid = build_gaussian_pyramid_sift(gray, w, h, n_layers, sigma0)
  // 构建 DoG 金字塔
  let dog_pyramid = build_dog_pyramid(gauss_pyramid)
  // 检测关键点
  let keypoints : Array[SiftKeyPoint] = []
  for oct in 0..<gauss_pyramid.length() {
    let (gauss_levels, oct_w, oct_h) = gauss_pyramid[oct]
    let (dog_levels, _, _) = dog_pyramid[oct]
    // dog_levels 有 n_levels-1 层，在 1..<(n_levels-2) 检测
    for layer in 1..<(dog_levels.length() - 1) {
      let prev_dog = dog_levels[layer - 1]
      let curr_dog = dog_levels[layer]
      let next_dog = dog_levels[layer + 1]
      let sigma = sigma0 *
        Float::from_int(1 << oct) *
        Float::from_double(
          @math.pow(
            2.0,
            Float::from_int(layer).to_double() /
            Float::from_int(n_layers).to_double(),
          ),
        )
      for y in 1..<(oct_h - 1) {
        for x in 1..<(oct_w - 1) {
          let val = curr_dog[y * oct_w + x]
          // 检查是否为 3x3x3 局部极值
          if !is_extremum(prev_dog, curr_dog, next_dog, x, y, oct_w) {
            continue
          }
          // 对比度过滤
          if val.abs() < contrast_threshold * 0.5F {
            continue
          }
          // 边缘响应过滤
          let ratio = edge_response(curr_dog, x, y, oct_w)
          if ratio > edge_thresh {
            continue
          }
          let fx = Float::from_int(x)
          let fy = Float::from_int(y)
          // 方向分配
          let base_gray = gauss_levels[layer]
          let angles = compute_orientation_sift(
            base_gray, oct_w, oct_h, fx, fy, sigma,
          )
          for angle in angles {
            keypoints.push(SiftKeyPoint::{
              x: fx * Float::from_int(1 << oct),
              y: fy * Float::from_int(1 << oct),
              octave: oct,
              layer,
              sigma,
              response: val,
              angle,
            })
          }
        }
      }
    }
  }
  // 限制特征数
  let kps = if keypoints.length() > max_features {
    keypoints[0:max_features]
  } else {
    keypoints
  }
  // 计算描述子
  let descriptors : Array[SiftDescriptor] = []
  for kp in kps {
    let (gauss_levels, oct_w, oct_h) = gauss_pyramid[kp.octave]
    let scale = Float::from_int(1 << kp.octave)
    let local_x = kp.x / scale
    let local_y = kp.y / scale
    let level_gray = gauss_levels[kp.layer]
    let desc = compute_sift_descriptor(
      level_gray,
      oct_w,
      oct_h,
      local_x,
      local_y,
      kp.angle,
      kp.sigma,
    )
    descriptors.push(SiftDescriptor::{ kp, data: desc })
  }
  descriptors
}

// ==================== 高斯金字塔 ====================

///|
fn build_gaussian_pyramid_sift(
  gray : Array[Float],
  w : Int,
  h : Int,
  n_layers : Int,
  sigma0 : Float,
) -> Array[(Array[Array[Float]], Int, Int)] {
  let n_levels = n_layers + 3
  let n_octaves = compute_n_octaves(w, h)
  let pyramid : Array[(Array[Array[Float]], Int, Int)] = []
  let mut cur_gray = gray
  let mut cur_w = w
  let mut cur_h = h
  for oct in 0..<n_octaves {
    let levels : Array[Array[Float]] = []
    // 第一层：octave 0 需要模糊 sigma0，后续 octave 直接用下采样图
    let first = if oct == 0 {
      gaussian_blur_float(cur_gray, cur_w, cur_h, sigma0)
    } else {
      cur_gray.copy()
    }
    levels.push(first)
    // 后续层：逐层增量模糊
    for i in 1..<n_levels {
      let target_sigma = sigma0 *
        Float::from_double(
          @math.pow(
            2.0,
            Float::from_int(i).to_double() /
            Float::from_int(n_layers).to_double(),
          ),
        )
      let prev_sigma = sigma0 *
        Float::from_double(
          @math.pow(
            2.0,
            Float::from_int(i - 1).to_double() /
            Float::from_int(n_layers).to_double(),
          ),
        )
      let delta_sq = target_sigma * target_sigma - prev_sigma * prev_sigma
      let delta_sigma = if delta_sq > 0.0F { delta_sq.sqrt() } else { 0.0F }
      let blurred = gaussian_blur_float(
        levels[i - 1],
        cur_w,
        cur_h,
        delta_sigma,
      )
      levels.push(blurred)
    }
    pyramid.push((levels, cur_w, cur_h))
    // 下采样为下一 octave 准备
    if oct < n_octaves - 1 {
      let down_idx = n_layers
      let (down_gray, down_w, down_h) = downsample(
        levels[down_idx],
        cur_w,
        cur_h,
      )
      cur_gray = down_gray
      cur_w = down_w
      cur_h = down_h
    }
  }
  pyramid
}

///|
fn compute_n_octaves(w : Int, h : Int) -> Int {
  let min_dim = if w < h { w } else { h }
  let mut n = 0
  let mut d = min_dim
  while d >= 16 {
    n += 1
    d = d / 2
  }
  if n < 1 {
    1
  } else {
    n
  }
}

///|
fn build_dog_pyramid(
  pyramid : Array[(Array[Array[Float]], Int, Int)],
) -> Array[(Array[Array[Float]], Int, Int)] {
  let result : Array[(Array[Array[Float]], Int, Int)] = []
  for oct in 0..<pyramid.length() {
    let (levels, w, h) = pyramid[oct]
    let dog_levels : Array[Array[Float]] = []
    for i in 1..<levels.length() {
      let diff : Array[Float] = Array::make(w * h, 0.0F)
      for j in 0..<(w * h) {
        diff[j] = levels[i][j] - levels[i - 1][j]
      }
      dog_levels.push(diff)
    }
    result.push((dog_levels, w, h))
  }
  result
}

// ==================== 关键点检测 ====================

///|
fn is_extremum(
  prev_dog : Array[Float],
  curr_dog : Array[Float],
  next_dog : Array[Float],
  x : Int,
  y : Int,
  w : Int,
) -> Bool {
  let val = curr_dog[y * w + x]
  let is_max = val > 0.0F
  for dy in -1..<=1 {
    for dx in -1..<=1 {
      let idx = (y + dy) * w + (x + dx)
      if is_max {
        if !(dx == 0 && dy == 0) && curr_dog[idx] >= val {
          return false
        }
        if prev_dog[idx] >= val {
          return false
        }
        if next_dog[idx] >= val {
          return false
        }
      } else {
        if !(dx == 0 && dy == 0) && curr_dog[idx] <= val {
          return false
        }
        if prev_dog[idx] <= val {
          return false
        }
        if next_dog[idx] <= val {
          return false
        }
      }
    }
  }
  true
}

///|
fn edge_response(dog : Array[Float], x : Int, y : Int, w : Int) -> Float {
  let dxx = dog[y * w + x + 1] - 2.0F * dog[y * w + x] + dog[y * w + x - 1]
  let dyy = dog[(y + 1) * w + x] - 2.0F * dog[y * w + x] + dog[(y - 1) * w + x]
  let dxy = (
      dog[(y + 1) * w + x + 1] -
      dog[(y + 1) * w + x - 1] -
      dog[(y - 1) * w + x + 1] +
      dog[(y - 1) * w + x - 1]
    ) /
    4.0F
  let trace = dxx + dyy
  let det = dxx * dyy - dxy * dxy
  if det <= 0.0F {
    return 100.0F
  }
  trace * trace / det
}

///|
fn compute_orientation_sift(
  gray : Array[Float],
  w : Int,
  h : Int,
  cx : Float,
  cy : Float,
  sigma : Float,
) -> Array[Float] {
  let n_bins = 36
  let hist : Array[Float] = Array::make(n_bins, 0.0F)
  let radius = (sigma * 3.0F).to_int()
  let ix = cx.to_int()
  let iy = cy.to_int()
  let two_pi = 2.0F * 3.14159265F
  for dy in -radius..<=radius {
    let y = iy + dy
    if y < 1 || y >= h - 1 {
      continue
    }
    for dx in -radius..<=radius {
      let x = ix + dx
      if x < 1 || x >= w - 1 {
        continue
      }
      let gx = gray[y * w + x + 1] - gray[y * w + x - 1]
      let gy = gray[(y + 1) * w + x] - gray[(y - 1) * w + x]
      let mag = (gx * gx + gy * gy).sqrt()
      let angle = Float::from_double(
        @math.atan2(gy.to_double(), gx.to_double()),
      )
      let norm_angle = if angle < 0.0F { angle + two_pi } else { angle }
      let bin = (norm_angle / two_pi * Float::from_int(n_bins)).to_int() %
        n_bins
      let weight = Float::from_double(
        @math.exp(
          -Float::from_int(dx * dx + dy * dy).to_double() /
          (2.0F * sigma * sigma).to_double(),
        ),
      )
      hist[bin] += weight * mag
    }
  }
  // 找峰值
  let angles : Array[Float] = []
  let mut max_val = 0.0F
  let mut max_bin = 0
  for i in 0..<n_bins {
    if hist[i] > max_val {
      max_val = hist[i]
      max_bin = i
    }
  }
  if max_val > 0.0F {
    let angle = Float::from_int(max_bin) * two_pi / Float::from_int(n_bins)
    angles.push(angle)
    // 检查 80% 峰值
    for i in 0..<n_bins {
      if i != max_bin && hist[i] > 0.8F * max_val {
        let a = Float::from_int(i) * two_pi / Float::from_int(n_bins)
        angles.push(a)
      }
    }
  }
  angles
}

// ==================== 描述子 ====================

///|
fn compute_sift_descriptor(
  gray : Array[Float],
  w : Int,
  h : Int,
  cx : Float,
  cy : Float,
  angle : Float,
  sigma : Float,
) -> Array[Float] {
  let desc : Array[Float] = Array::make(128, 0.0F)
  let radius = (sigma * 4.0F).to_int()
  let cos_a = Float::from_double(@math.cos(angle.to_double()))
  let sin_a = Float::from_double(@math.sin(angle.to_double()))
  let ix = cx.to_int()
  let iy = cy.to_int()
  let two_pi = 2.0F * 3.14159265F
  for dy in -radius..<=radius {
    let y = iy + dy
    if y < 1 || y >= h - 1 {
      continue
    }
    for dx in -radius..<=radius {
      let x = ix + dx
      if x < 1 || x >= w - 1 {
        continue
      }
      // 旋转到关键点坐标系
      let rx = Float::from_int(dx) * cos_a + Float::from_int(dy) * sin_a
      let ry = -Float::from_int(dx) * sin_a + Float::from_int(dy) * cos_a
      // 分配到 4x4 cell
      let cell_x = (rx / (sigma * 2.0F) + 2.0F).to_int()
      let cell_y = (ry / (sigma * 2.0F) + 2.0F).to_int()
      if cell_x < 0 || cell_x >= 4 || cell_y < 0 || cell_y >= 4 {
        continue
      }
      // 梯度
      let gx = gray[y * w + x + 1] - gray[y * w + x - 1]
      let gy = gray[(y + 1) * w + x] - gray[(y - 1) * w + x]
      let mag = (gx * gx + gy * gy).sqrt()
      let grad_angle = Float::from_double(
          @math.atan2(gy.to_double(), gx.to_double()),
        ) -
        angle
      let norm_angle = if grad_angle < 0.0F {
        grad_angle + two_pi
      } else {
        grad_angle
      }
      let bin = (norm_angle / two_pi * 8.0F).to_int() % 8
      // 高斯加权
      let weight = Float::from_double(
        @math.exp(
          -Float::from_int(dx * dx + dy * dy).to_double() /
          (2.0F * sigma * sigma * 4.0F).to_double(),
        ),
      )
      let idx = cell_y * 32 + cell_x * 8 + bin
      desc[idx] += weight * mag
    }
  }
  // 归一化
  let mut norm = 0.0F
  for v in desc {
    norm += v * v
  }
  norm = norm.sqrt()
  if norm > 0.0F {
    for i in 0..<128 {
      desc[i] = desc[i] / norm
      if desc[i] > 0.2F {
        desc[i] = 0.2F
      }
    }
    // 再次归一化
    let mut norm2 = 0.0F
    for v in desc {
      norm2 += v * v
    }
    norm2 = norm2.sqrt()
    if norm2 > 0.0F {
      for i in 0..<128 {
        desc[i] = desc[i] / norm2
      }
    }
  }
  desc
}

// ==================== 辅助函数 ====================

///|
fn to_gray_sift(img : @types.Image) -> (Array[Float], Int, Int) {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let n = w * h
  let gray : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    if ch >= 3 {
      let r = img.data[i * ch].to_int()
      let g = img.data[i * ch + 1].to_int()
      let b = img.data[i * ch + 2].to_int()
      gray[i] = Float::from_int((r * 299 + g * 587 + b * 114) / 1000) / 255.0F
    } else {
      gray[i] = Float::from_int(img.data[i * ch].to_int()) / 255.0F
    }
  }
  (gray, w, h)
}

///|
fn gaussian_blur_float(
  gray : Array[Float],
  w : Int,
  h : Int,
  sigma : Float,
) -> Array[Float] {
  if sigma < 0.1F {
    return gray.copy()
  }
  let radius = (sigma * 3.0F).to_int()
  if radius < 1 {
    return gray.copy()
  }
  // 可分离高斯：先水平后垂直
  let kernel : Array[Float] = Array::make(2 * radius + 1, 0.0F)
  let mut sum = 0.0F
  for i in -radius..<=radius {
    let v = Float::from_double(
      @math.exp(
        -Float::from_int(i * i).to_double() / (2.0F * sigma * sigma).to_double(),
      ),
    )
    kernel[i + radius] = v
    sum += v
  }
  for i in 0..<kernel.length() {
    kernel[i] = kernel[i] / sum
  }
  // 水平模糊
  let temp : Array[Float] = Array::make(w * h, 0.0F)
  for y in 0..<h {
    for x in 0..<w {
      let mut acc = 0.0F
      for k in -radius..<=radius {
        let sx = (x + k).clamp(min=0, max=w - 1)
        acc += kernel[k + radius] * gray[y * w + sx]
      }
      temp[y * w + x] = acc
    }
  }
  // 垂直模糊
  let out : Array[Float] = Array::make(w * h, 0.0F)
  for y in 0..<h {
    for x in 0..<w {
      let mut acc = 0.0F
      for k in -radius..<=radius {
        let sy = (y + k).clamp(min=0, max=h - 1)
        acc += kernel[k + radius] * temp[sy * w + x]
      }
      out[y * w + x] = acc
    }
  }
  out
}

///|
fn downsample(
  gray : Array[Float],
  w : Int,
  h : Int,
) -> (Array[Float], Int, Int) {
  let nw = w / 2
  let nh = h / 2
  if nw < 1 || nh < 1 {
    return (gray.copy(), w, h)
  }
  let out : Array[Float] = Array::make(nw * nh, 0.0F)
  for y in 0..<nh {
    for x in 0..<nw {
      out[y * nw + x] = gray[y * 2 * w + x * 2]
    }
  }
  (out, nw, nh)
}
