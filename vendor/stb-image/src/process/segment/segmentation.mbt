// 图像分割（v12.2.0）
// 分水岭算法 + 区域生长 + 阈值分割

///|
/// 分割结果
pub(all) struct SegmentationResult {
  labels : Array[Int] // 每个像素的标签
  num_regions : Int // 区域数量
  region_sizes : Array[Int] // 每个区域的大小
}

///|
/// 分水岭算法配置
pub(all) struct WatershedConfig {
  threshold : Double // 梯度阈值
  min_region_size : Int // 最小区域大小
  connectivity : Int // 连通性（4或8）
}

///|
/// 创建默认分水岭配置
pub fn watershed_default_config() -> WatershedConfig {
  WatershedConfig::{ threshold: 10.0, min_region_size: 50, connectivity: 8 }
}

///|
/// 计算图像梯度（Sobel）
fn compute_gradient(img : @types.Image) -> Array[Double] {
  let w = img.width
  let h = img.height
  let channels = img.channels
  let data = img.data
  let gradient : Array[Double] = Array::make(w * h, 0.0)
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let _ = (y * w + x) * channels
      // 灰度
      let gray = (px, py) => {
        let i = (py * w + px) * channels
        let r = data[i].to_double()
        let g = if channels >= 2 { data[i + 1].to_double() } else { r }
        let b = if channels >= 3 { data[i + 2].to_double() } else { r }
        0.299 * r + 0.587 * g + 0.114 * b
      }
      let gx = -gray(x - 1, y - 1) -
        2.0 * gray(x - 1, y) -
        gray(x - 1, y + 1) +
        gray(x + 1, y - 1) +
        2.0 * gray(x + 1, y) +
        gray(x + 1, y + 1)
      let gy = -gray(x - 1, y - 1) -
        2.0 * gray(x, y - 1) -
        gray(x + 1, y - 1) +
        gray(x - 1, y + 1) +
        2.0 * gray(x, y + 1) +
        gray(x + 1, y + 1)
      gradient[y * w + x] = (gx * gx + gy * gy).sqrt()
    }
  }
  gradient
}

///|
/// 分水岭算法（简化版）
/// 基于梯度图像的区域生长分割
pub fn watershed_segment(
  img : @types.Image,
  config? : WatershedConfig,
) -> SegmentationResult {
  let cfg = match config {
    Some(c) => c
    None => watershed_default_config()
  }
  let w = img.width
  let h = img.height
  // 1. 计算梯度
  let gradient = compute_gradient(img)
  // 2. 寻找局部最小值作为种子点
  let labels : Array[Int] = Array::make(w * h, 0)
  let mut next_label = 1
  let seeds : Array[(Int, Int)] = []
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let g = gradient[y * w + x]
      if g < cfg.threshold {
        // 检查是否是局部最小值
        let mut is_min = true
        let neighbors = [
          (-1, 0),
          (1, 0),
          (0, -1),
          (0, 1),
          (-1, -1),
          (1, 1),
          (-1, 1),
          (1, -1),
        ]
        for _tup0 in neighbors {
          let (dx, dy) = _tup0
          if gradient[(y + dy) * w + (x + dx)] < g {
            is_min = false
          }
        }
        if is_min && labels[y * w + x] == 0 {
          seeds.push((x, y))
          labels[y * w + x] = next_label
          next_label += 1
        }
      }
    }
  }
  // 3. 区域生长（从种子点开始，按梯度从小到大扩展）
  let mut changed = true
  while changed {
    changed = false
    for y in 0..<h {
      for x in 0..<w {
        if labels[y * w + x] == 0 && gradient[y * w + x] < cfg.threshold * 2.0 {
          // 检查邻域是否有已标记像素
          let neighbors = if cfg.connectivity == 8 {
            [
              (-1, 0),
              (1, 0),
              (0, -1),
              (0, 1),
              (-1, -1),
              (1, 1),
              (-1, 1),
              (1, -1),
            ]
          } else {
            [(-1, 0), (1, 0), (0, -1), (0, 1)]
          }
          for _tup1 in neighbors {
            let (dx, dy) = _tup1
            let nx = x + dx
            let ny = y + dy
            if nx >= 0 && nx < w && ny >= 0 && ny < h && labels[ny * w + nx] > 0 {
              labels[y * w + x] = labels[ny * w + nx]
              changed = true
              break
            }
          }
        }
      }
    }
  }
  // 4. 合并小区域
  let region_sizes : Array[Int] = Array::make(next_label, 0)
  for i in 0..<(w * h) {
    if labels[i] > 0 {
      region_sizes[labels[i]] += 1
    }
  }
  // 小区域合并到相邻大区域
  for label in 1..<next_label {
    if region_sizes[label] < cfg.min_region_size {
      // 找到第一个相邻的大区域
      for y in 0..<h {
        for x in 0..<w {
          if labels[y * w + x] == label {
            let neighbors = [(-1, 0), (1, 0), (0, -1), (0, 1)]
            for _tup2 in neighbors {
              let (dx, dy) = _tup2
              let nx = x + dx
              let ny = y + dy
              if nx >= 0 &&
                nx < w &&
                ny >= 0 &&
                ny < h &&
                labels[ny * w + nx] > 0 &&
                labels[ny * w + nx] != label &&
                region_sizes[labels[ny * w + nx]] >= cfg.min_region_size {
                // 合并
                let old_label = label
                let new_label = labels[ny * w + nx]
                for i in 0..<(w * h) {
                  if labels[i] == old_label {
                    labels[i] = new_label
                  }
                }
                region_sizes[new_label] += region_sizes[old_label]
                region_sizes[old_label] = 0
                break
              }
            }
          }
        }
      }
    }
  }
  // 5. 重新编号标签
  let label_map : Array[Int] = Array::make(next_label, 0)
  let mut new_num = 1
  let new_sizes : Array[Int] = []
  for label in 1..<next_label {
    if region_sizes[label] > 0 {
      label_map[label] = new_num
      new_sizes.push(region_sizes[label])
      new_num += 1
    }
  }
  for i in 0..<(w * h) {
    if labels[i] > 0 {
      labels[i] = label_map[labels[i]]
    }
  }
  SegmentationResult::{
    labels,
    num_regions: new_num - 1,
    region_sizes: new_sizes,
  }
}

///|
/// 区域生长分割
/// 从种子点开始，根据相似度生长区域
pub fn region_growing(
  img : @types.Image,
  seeds : Array[(Int, Int)],
  threshold? : Double = 30.0,
) -> SegmentationResult {
  let thresh = threshold
  let w = img.width
  let h = img.height
  let channels = img.channels
  let data = img.data
  let labels : Array[Int] = Array::make(w * h, 0)
  let region_sizes : Array[Int] = []
  let mut label = 1
  for _tup3 in seeds {
    let (sx, sy) = _tup3
    if sx < 0 || sx >= w || sy < 0 || sy >= h {
      continue
    }
    if labels[sy * w + sx] > 0 {
      continue
    }
    // 种子点颜色
    let seed_idx = (sy * w + sx) * channels
    let seed_r = data[seed_idx].to_double()
    let seed_g = if channels >= 2 {
      data[seed_idx + 1].to_double()
    } else {
      seed_r
    }
    let seed_b = if channels >= 3 {
      data[seed_idx + 2].to_double()
    } else {
      seed_r
    }
    // 区域生长（洪水填充）
    let stack : Array[(Int, Int)] = []
    stack.push((sx, sy))
    labels[sy * w + sx] = label
    let mut size = 0
    while stack.length() > 0 {
      match stack.pop() {
        Some((x, y)) => {
          size += 1
          let neighbors = [(-1, 0), (1, 0), (0, -1), (0, 1)]
          for _tup4 in neighbors {
            let (dx, dy) = _tup4
            let nx = x + dx
            let ny = y + dy
            if nx >= 0 &&
              nx < w &&
              ny >= 0 &&
              ny < h &&
              labels[ny * w + nx] == 0 {
              let idx = (ny * w + nx) * channels
              let r = data[idx].to_double()
              let g = if channels >= 2 { data[idx + 1].to_double() } else { r }
              let b = if channels >= 3 { data[idx + 2].to_double() } else { r }
              let dist = ((r - seed_r) * (r - seed_r) +
              (g - seed_g) * (g - seed_g) +
              (b - seed_b) * (b - seed_b)).sqrt()
              if dist < thresh {
                labels[ny * w + nx] = label
                stack.push((nx, ny))
              }
            }
          }
        }
        None => ignore(())
      }
    }
    region_sizes.push(size)
    label += 1
  }
  SegmentationResult::{ labels, num_regions: label - 1, region_sizes }
}

///|
/// 阈值分割（Otsu 自动阈值）
pub fn threshold_otsu(img : @types.Image) -> @types.Image {
  let w = img.width
  let h = img.height
  let channels = img.channels
  let data = img.data
  // 计算灰度直方图
  let histogram : Array[Int] = Array::make(256, 0)
  for i in 0..<(w * h) {
    let idx = i * channels
    let r = data[idx].to_int()
    let g = if channels >= 2 { data[idx + 1].to_int() } else { r }
    let b = if channels >= 3 { data[idx + 2].to_int() } else { r }
    let gray = (0.299 * r.to_double() +
    0.587 * g.to_double() +
    0.114 * b.to_double()).to_int()
    histogram[gray] += 1
  }
  // Otsu 阈值计算
  let total = w * h
  let mut sum = 0
  for t in 0..<256 {
    sum += t * histogram[t]
  }
  let mut sum_b = 0
  let mut w_b = 0
  let mut max_variance = 0.0
  let mut threshold = 128
  for t in 0..<256 {
    w_b += histogram[t]
    if w_b == 0 {
      continue
    }
    let w_f = total - w_b
    if w_f == 0 {
      break
    }
    sum_b += t * histogram[t]
    let m_b = sum_b.to_double() / w_b.to_double()
    let m_f = (sum - sum_b).to_double() / w_f.to_double()
    let variance = w_b.to_double() * w_f.to_double() * (m_b - m_f) * (m_b - m_f)
    if variance > max_variance {
      max_variance = variance
      threshold = t
    }
  }
  // 应用阈值
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  for i in 0..<(w * h) {
    let idx = i * channels
    let r = data[idx].to_int()
    let g = if channels >= 2 { data[idx + 1].to_int() } else { r }
    let b = if channels >= 3 { data[idx + 2].to_int() } else { r }
    let gray = (0.299 * r.to_double() +
    0.587 * g.to_double() +
    0.114 * b.to_double()).to_int()
    let value = if gray > threshold { 255 } else { 0 }
    for c in 0..<channels {
      out_data[idx + c] = value.to_byte()
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 将分割结果可视化为彩色图像
pub fn segmentation_to_color(
  result : SegmentationResult,
  width : Int,
  height : Int,
) -> @types.Image {
  let colors = [
    (255, 0, 0),
    (0, 255, 0),
    (0, 0, 255),
    (255, 255, 0),
    (255, 0, 255),
    (0, 255, 255),
    (128, 0, 0),
    (0, 128, 0),
    (0, 0, 128),
    (128, 128, 0),
    (128, 0, 128),
    (0, 128, 128),
    (192, 192, 192),
    (128, 128, 128),
    (255, 128, 0),
    (255, 0, 128),
  ]
  let out_data : Array[Byte] = Array::make(width * height * 3, b'\x00')
  for y in 0..<height {
    for x in 0..<width {
      let label = result.labels[y * width + x]
      let idx = (y * width + x) * 3
      if label > 0 && label <= colors.length() {
        let (r, g, b) = colors[label - 1]
        out_data[idx] = r.to_byte()
        out_data[idx + 1] = g.to_byte()
        out_data[idx + 2] = b.to_byte()
      } else {
        out_data[idx] = b'\x00'
        out_data[idx + 1] = b'\x00'
        out_data[idx + 2] = b'\x00'
      }
    }
  }
  @types.Image::{
    width,
    height,
    channels: 3,
    data: Bytes::from_array(out_data),
  }
}
