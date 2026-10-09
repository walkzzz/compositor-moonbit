// ORB 特征检测与描述（纯 MoonBit）
// Oriented FAST and Rotated BRIEF
// 参考: https://docs.opencv.org/4.x/d5/d3c/classcv_1_1Feature2D.html

///|
/// ORB 关键点：位置 + 响应 + 方向
pub(all) struct OrbKeyPoint {
  x : Int
  y : Int
  response : Float
  angle : Float // 方向角（弧度）
}

///|
/// ORB 描述子：256 位二进制描述（32 个 Int）
pub(all) struct OrbDescriptor {
  kp : OrbKeyPoint
  data : Array[Int] // 32 个 Int，每个 32 位，共 256 位
}

///|
/// 特征匹配结果
pub(all) struct DescriptorMatch {
  query_idx : Int
  train_idx : Int
  distance : Int // 汉明距离
}

// ==================== FAST 角点检测 ====================

///|
/// FAST-9 圆周偏移（半径 3，16 个点）
let fast_offsets : Array[(Int, Int)] = [
  (0, -3),
  (1, -3),
  (2, -2),
  (3, -1),
  (3, 0),
  (3, 1),
  (2, 2),
  (1, 3),
  (0, 3),
  (-1, 3),
  (-2, 2),
  (-3, 1),
  (-3, 0),
  (-3, -1),
  (-2, -2),
  (-1, -3),
]

///|
/// FAST-9 角点检测
fn fast_detect(
  gray : Array[Int],
  w : Int,
  h : Int,
  threshold : Int,
) -> Array[OrbKeyPoint] {
  let corners : Array[OrbKeyPoint] = []
  for y in 3..<(h - 3) {
    for x in 3..<(w - 3) {
      let p = gray[y * w + x]
      let high_thresh = p + threshold
      let low_thresh = p - threshold
      // 读取圆周 16 个像素
      let vals : Array[Int] = Array::make(16, 0)
      for i in 0..<16 {
        let (dx, dy) = fast_offsets[i]
        vals[i] = gray[(y + dy) * w + (x + dx)]
      }
      // 检查是否有 9 个连续 brighter 或 darker
      let is_corner = check_fast9(vals, high_thresh, low_thresh)
      if is_corner {
        // 计算方向
        let angle = compute_orientation(gray, w, h, x, y)
        corners.push(OrbKeyPoint::{ x, y, response: 1.0F, angle })
      }
    }
  }
  corners
}

///|
/// 检查 FAST-9 条件：圆周上是否有 9 个连续像素都 > high 或都 < low
fn check_fast9(vals : Array[Int], high : Int, low : Int) -> Bool {
  // 将 16 个点复制两遍以处理环绕
  let brighter : Array[Bool] = Array::make(32, false)
  let darker : Array[Bool] = Array::make(32, false)
  for i in 0..<16 {
    brighter[i] = vals[i] > high
    darker[i] = vals[i] < low
    brighter[i + 16] = brighter[i]
    darker[i + 16] = darker[i]
  }
  // 检查 9 连续
  let mut b_run = 0
  let mut d_run = 0
  for i in 0..<32 {
    if brighter[i] {
      b_run += 1
      if b_run >= 9 {
        return true
      }
    } else {
      b_run = 0
    }
    if darker[i] {
      d_run += 1
      if d_run >= 9 {
        return true
      }
    } else {
      d_run = 0
    }
  }
  false
}

///|
/// 计算关键点方向（图像矩质心法）
/// θ = atan2(m01, m10), m_pq = Σ x^p * y^q * I(x,y)
fn compute_orientation(
  gray : Array[Int],
  w : Int,
  h : Int,
  cx : Int,
  cy : Int,
) -> Float {
  let r = 15 // 取 31x31 patch
  let mut m01 = 0.0F
  let mut m10 = 0.0F
  for dy in -r..<=r {
    let y = cy + dy
    if y < 0 || y >= h {
      continue
    }
    for dx in -r..<=r {
      let x = cx + dx
      if x < 0 || x >= w {
        continue
      }
      let v = Float::from_int(gray[y * w + x])
      m01 += Float::from_int(dy) * v
      m10 += Float::from_int(dx) * v
    }
  }
  Float::from_double(@math.atan2(m01.to_double(), m10.to_double()))
}

// ==================== BRIEF 描述子 ====================

///|
/// 生成 BRIEF 采样点对（256 对）
/// 使用固定伪随机模式（基于质心高斯分布）
fn brief_pattern() -> Array[(Float, Float, Float, Float)] {
  // 256 个点对 (x1, y1, x2, y2)，相对于关键点中心
  // 使用固定模式确保可重复性
  let pairs : Array[(Float, Float, Float, Float)] = []
  // 使用简单的 LCG 伪随机生成器
  let mut seed = 12345
  fn next_rand() -> Int {
    seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
    seed
  }
  for _ in 0..<256 {
    let x1 = (Float::from_int(next_rand() % 48) - 24.0F) / 24.0F * 15.0F
    let y1 = (Float::from_int(next_rand() % 48) - 24.0F) / 24.0F * 15.0F
    let x2 = (Float::from_int(next_rand() % 48) - 24.0F) / 24.0F * 15.0F
    let y2 = (Float::from_int(next_rand() % 48) - 24.0F) / 24.0F * 15.0F
    pairs.push((x1, y1, x2, y2))
  }
  pairs
}

///|
/// 计算 rBRIEF 描述子（旋转后的 BRIEF）
fn compute_brief(
  gray : Array[Int],
  w : Int,
  h : Int,
  kp : OrbKeyPoint,
  pattern : Array[(Float, Float, Float, Float)],
) -> Array[Int] {
  let desc : Array[Int] = Array::make(32, 0)
  let cos_a = Float::from_double(@math.cos(kp.angle.to_double()))
  let sin_a = Float::from_double(@math.sin(kp.angle.to_double()))
  for i in 0..<256 {
    let (x1, y1, x2, y2) = pattern[i]
    // 旋转采样点
    let rx1 = x1 * cos_a - y1 * sin_a
    let ry1 = x1 * sin_a + y1 * cos_a
    let rx2 = x2 * cos_a - y2 * sin_a
    let ry2 = x2 * sin_a + y2 * cos_a
    // 采样像素值（双线性插值）
    let v1 = sample_bilinear(gray, w, h, kp.x, kp.y, rx1, ry1)
    let v2 = sample_bilinear(gray, w, h, kp.x, kp.y, rx2, ry2)
    // 二进制测试
    if v1 < v2 {
      let word = i / 32
      let bit = i % 32
      desc[word] = desc[word] | (1 << bit)
    }
  }
  desc
}

///|
/// 双线性插值采样
fn sample_bilinear(
  gray : Array[Int],
  w : Int,
  h : Int,
  cx : Int,
  cy : Int,
  dx : Float,
  dy : Float,
) -> Int {
  let fx = Float::from_int(cx) + dx
  let fy = Float::from_int(cy) + dy
  let x0 = fx.to_int()
  let y0 = fy.to_int()
  let x1 = x0 + 1
  let y1 = y0 + 1
  let x0c = x0.clamp(min=0, max=w - 1)
  let x1c = x1.clamp(min=0, max=w - 1)
  let y0c = y0.clamp(min=0, max=h - 1)
  let y1c = y1.clamp(min=0, max=h - 1)
  let p00 = gray[y0c * w + x0c]
  let p01 = gray[y0c * w + x1c]
  let p10 = gray[y1c * w + x0c]
  let p11 = gray[y1c * w + x1c]
  let wx = fx - Float::from_int(x0)
  let wy = fy - Float::from_int(y0)
  let v = Float::from_int(p00) * (1.0F - wx) * (1.0F - wy) +
    Float::from_int(p01) * wx * (1.0F - wy) +
    Float::from_int(p10) * (1.0F - wx) * wy +
    Float::from_int(p11) * wx * wy
  v.to_int()
}

// ==================== 灰度转换 ====================

///|
fn to_gray_orb(img : @types.Image) -> (Array[Int], Int, Int) {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let n = w * h
  let gray : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    if ch >= 3 {
      let r = img.data[i * ch].to_int()
      let g = img.data[i * ch + 1].to_int()
      let b = img.data[i * ch + 2].to_int()
      gray[i] = (r * 299 + g * 587 + b * 114) / 1000
    } else {
      gray[i] = img.data[i * ch].to_int()
    }
  }
  (gray, w, h)
}

// ==================== 公开 API ====================

///|
/// ORB 特征检测。
/// 检测 FAST 关键点并计算 rBRIEF 描述子。
/// max_features 控制最大特征数，threshold 为 FAST 阈值。
pub fn orb_detect(
  img : @types.Image,
  max_features? : Int = 500,
  threshold? : Int = 20,
) -> Array[OrbDescriptor] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "orb_detect: 图像尺寸必须大于0",
    )
  }
  if img.width < 7 || img.height < 7 {
    raise @types.LoadError::DecodeFailed(
      "orb_detect: ORB 需要至少 7x7 图像",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "orb_detect: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "orb_detect: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if max_features <= 0 {
    raise @types.LoadError::DecodeFailed(
      "orb_detect: max_features必须大于0",
    )
  }
  if threshold <= 0 || threshold > 255 {
    raise @types.LoadError::DecodeFailed(
      "orb_detect: threshold必须在1-255范围内",
    )
  }
  let (gray, w, h) = to_gray_orb(img)
  // FAST 检测
  let keypoints = fast_detect(gray, w, h, threshold)
  // 限制特征数：取前 max_features 个
  let kps = if keypoints.length() > max_features {
    keypoints[0:max_features]
  } else {
    keypoints
  }
  // 计算 BRIEF 描述子
  let pattern = brief_pattern()
  let descriptors : Array[OrbDescriptor] = []
  for kp in kps {
    let desc = compute_brief(gray, w, h, kp, pattern)
    descriptors.push(OrbDescriptor::{ kp, data: desc })
  }
  descriptors
}

///|
/// ORB 描述子汉明距离
pub fn orb_hamming(d1 : OrbDescriptor, d2 : OrbDescriptor) -> Int {
  let mut dist = 0
  for i in 0..<32 {
    let xor = d1.data[i] ^ d2.data[i]
    // 计算位计数
    let mut bits = xor
    bits = (bits & 0x55555555) + ((bits >> 1) & 0x55555555)
    bits = (bits & 0x33333333) + ((bits >> 2) & 0x33333333)
    bits = (bits & 0x0F0F0F0F) + ((bits >> 4) & 0x0F0F0F0F)
    bits = (bits & 0x00FF00FF) + ((bits >> 8) & 0x00FF00FF)
    bits = (bits & 0x0000FFFF) + ((bits >> 16) & 0x0000FFFF)
    dist += bits
  }
  dist
}

///|
/// ORB 特征匹配。
/// 对 query 中每个描述子，找 train 中汉明距离最小的匹配。
/// max_distance 为最大允许距离（默认 64）。
pub fn orb_match(
  query : Array[OrbDescriptor],
  train : Array[OrbDescriptor],
  max_distance? : Int = 64,
) -> Array[DescriptorMatch] raise @types.LoadError {
  // 参数验证
  if query.length() == 0 {
    raise @types.LoadError::DecodeFailed("orb_match: query数组不能为空")
  }
  if train.length() == 0 {
    raise @types.LoadError::DecodeFailed("orb_match: train数组不能为空")
  }
  if max_distance < 0 {
    raise @types.LoadError::DecodeFailed("orb_match: max_distance必须 >= 0")
  }

  let matches : Array[DescriptorMatch] = []
  for i in 0..<query.length() {
    let mut best_j = -1
    let mut best_dist = max_distance + 1
    for j in 0..<train.length() {
      let dist = orb_hamming(query[i], train[j])
      if dist < best_dist {
        best_dist = dist
        best_j = j
      }
    }
    if best_j >= 0 && best_dist <= max_distance {
      matches.push(DescriptorMatch::{
        query_idx: i,
        train_idx: best_j,
        distance: best_dist,
      })
    }
  }
  matches
}
