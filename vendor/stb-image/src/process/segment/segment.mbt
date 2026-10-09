// 图像分割（纯 MoonBit）：kmeans_segment / region_growing_segment / flood_fill / segment_to_color

///|
/// 分割标签图
pub(all) struct SegmentLabelImage {
  width : Int
  height : Int
  labels : Array[Int] // 每个像素的标签（0=背景，1..N=区域）
  num_regions : Int
}

///|
/// 分割区域信息
pub struct SegmentRegion {
  label : Int // 标签号
  area : Int // 像素数
  mean_r : Int // 平均颜色 R
  mean_g : Int // 平均颜色 G
  mean_b : Int // 平均颜色 B
  bbox_x : Int
  bbox_y : Int
  bbox_w : Int
  bbox_h : Int
}

///|
/// K-means 颜色分割。将图像像素按颜色聚为 k 类，返回标签图和区域信息。
/// 适用于 RGB/RGBA 图像（channels=3/4）。
pub fn kmeans_segment(
  img : @types.Image,
  k : Int,
  max_iters? : Int = 20,
) -> (SegmentLabelImage, Array[SegmentRegion]) raise @types.LoadError {
  if k < 1 || k > 256 {
    raise @types.LoadError::DecodeFailed("k 必须在 1..256 之间")
  }
  if img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "kmeans_segment 需要 RGB/RGBA 图像",
    )
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  if n == 0 {
    return (
      SegmentLabelImage::{ width: w, height: h, labels: [], num_regions: 0 },
      [],
    )
  }
  // 初始化聚类中心
  let centroids_r : Array[Int] = Array::make(k, 0)
  let centroids_g : Array[Int] = Array::make(k, 0)
  let centroids_b : Array[Int] = Array::make(k, 0)
  let data_int : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    data_int[i] = img.data[i].to_int()
  }
  let step = if n > k { n / k } else { 1 }
  for i in 0..<k {
    let idx = (i * step).clamp(min=0, max=n - 1)
    centroids_r[i] = data_int[idx * ch]
    centroids_g[i] = data_int[idx * ch + 1]
    centroids_b[i] = data_int[idx * ch + 2]
  }
  let labels : Array[Int] = Array::make(n, 0)
  let iters = if max_iters < 1 { 20 } else { max_iters }
  for _ in 0..<iters {
    let mut changed = false
    for i in 0..<n {
      let r = data_int[i * ch]
      let g = data_int[i * ch + 1]
      let b = data_int[i * ch + 2]
      let mut best = 0
      let mut best_dist = color_dist_sq(
        r,
        g,
        b,
        centroids_r[0],
        centroids_g[0],
        centroids_b[0],
      )
      for j in 1..<k {
        let d = color_dist_sq(
          r,
          g,
          b,
          centroids_r[j],
          centroids_g[j],
          centroids_b[j],
        )
        if d < best_dist {
          best_dist = d
          best = j
        }
      }
      if labels[i] != best {
        changed = true
        labels[i] = best
      }
    }
    if !changed {
      break
    }
    let sum_r : Array[Int] = Array::make(k, 0)
    let sum_g : Array[Int] = Array::make(k, 0)
    let sum_b : Array[Int] = Array::make(k, 0)
    let cnt : Array[Int] = Array::make(k, 0)
    for i in 0..<n {
      let label = labels[i]
      sum_r[label] += data_int[i * ch]
      sum_g[label] += data_int[i * ch + 1]
      sum_b[label] += data_int[i * ch + 2]
      cnt[label] += 1
    }
    for j in 0..<k {
      if cnt[j] > 0 {
        centroids_r[j] = sum_r[j] / cnt[j]
        centroids_g[j] = sum_g[j] / cnt[j]
        centroids_b[j] = sum_b[j] / cnt[j]
      }
    }
  }
  let regions = compute_regions(data_int, labels, w, h, ch, k)
  (SegmentLabelImage::{ width: w, height: h, labels, num_regions: k }, regions)
}

///|
/// 区域生长分割。从指定种子点出发，按颜色相似性（阈值 threshold）生长区域。
/// seeds 为种子点坐标数组 [(x, y), ...]。
/// 适用于 RGB/RGBA 图像（channels=3/4）。
pub fn region_growing_segment(
  img : @types.Image,
  seeds : Array[(Int, Int)],
  threshold? : Int = 30,
) -> (SegmentLabelImage, Array[SegmentRegion]) raise @types.LoadError {
  if img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "region_growing_segment 需要 RGB/RGBA 图像",
    )
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  let labels : Array[Int] = Array::make(n, 0)
  let regions : Array[SegmentRegion] = []
  let data_int : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    data_int[i] = img.data[i].to_int()
  }
  let mut current_label = 0
  for seed in seeds {
    let (sx, sy) = seed
    if sx < 0 || sx >= w || sy < 0 || sy >= h {
      continue
    }
    let seed_idx = sy * w + sx
    if labels[seed_idx] != 0 {
      continue // 已分配
    }
    current_label += 1
    let seed_r = data_int[seed_idx * ch]
    let seed_g = data_int[seed_idx * ch + 1]
    let seed_b = data_int[seed_idx * ch + 2]
    // BFS 区域生长
    let stack : Array[Int] = [seed_idx]
    labels[seed_idx] = current_label
    let mut area = 0
    let mut sum_r = 0
    let mut sum_g = 0
    let mut sum_b = 0
    let mut min_x = sx
    let mut max_x = sx
    let mut min_y = sy
    let mut max_y = sy
    while stack.length() > 0 {
      let idx = stack.remove(stack.length() - 1)
      let px = idx % w
      let py = idx / w
      area += 1
      sum_r += data_int[idx * ch]
      sum_g += data_int[idx * ch + 1]
      sum_b += data_int[idx * ch + 2]
      if px < min_x {
        min_x = px
      }
      if px > max_x {
        max_x = px
      }
      if py < min_y {
        min_y = py
      }
      if py > max_y {
        max_y = py
      }
      // 4 邻域
      let neighbors = [(px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1)]
      for nb in neighbors {
        let (nx, ny) = nb
        if nx >= 0 && nx < w && ny >= 0 && ny < h {
          let nidx = ny * w + nx
          if labels[nidx] == 0 {
            let nr = data_int[nidx * ch]
            let ng = data_int[nidx * ch + 1]
            let nb2 = data_int[nidx * ch + 2]
            let dist = color_dist_sq(seed_r, seed_g, seed_b, nr, ng, nb2)
            if dist <= threshold * threshold {
              labels[nidx] = current_label
              stack.push(nidx)
            }
          }
        }
      }
    }
    regions.push(SegmentRegion::{
      label: current_label,
      area,
      mean_r: if area > 0 {
        sum_r / area
      } else {
        0
      },
      mean_g: if area > 0 {
        sum_g / area
      } else {
        0
      },
      mean_b: if area > 0 {
        sum_b / area
      } else {
        0
      },
      bbox_x: min_x,
      bbox_y: min_y,
      bbox_w: max_x - min_x + 1,
      bbox_h: max_y - min_y + 1,
    })
  }
  (
    SegmentLabelImage::{
      width: w,
      height: h,
      labels,
      num_regions: current_label,
    },
    regions,
  )
}

///|
/// 泛洪填充。从种子点 (seed_x, seed_y) 出发，填充与种子点颜色差异 <= threshold 的连通区域，
/// 用 fill_color 替换。返回填充后的图像。
/// 适用于 RGB/RGBA 图像（channels=3/4）。
pub fn flood_fill(
  img : @types.Image,
  seed_x : Int,
  seed_y : Int,
  fill_color : Array[Byte],
  threshold? : Int = 0,
) -> @types.Image raise @types.LoadError {
  if img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("flood_fill 需要 RGB/RGBA 图像")
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let n = w * h
  if seed_x < 0 || seed_x >= w || seed_y < 0 || seed_y >= h {
    raise @types.LoadError::DecodeFailed("种子点越界")
  }
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  for i in 0..<(n * ch) {
    out[i] = img.data[i]
  }
  let data_int : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    data_int[i] = img.data[i].to_int()
  }
  let seed_idx = seed_y * w + seed_x
  let seed_r = data_int[seed_idx * ch]
  let seed_g = data_int[seed_idx * ch + 1]
  let seed_b = data_int[seed_idx * ch + 2]
  let visited : Array[Bool] = Array::make(n, false)
  let stack : Array[Int] = [seed_idx]
  visited[seed_idx] = true
  let fill_ch = if ch >= 3 { 3 } else { 1 }
  while stack.length() > 0 {
    let idx = stack.remove(stack.length() - 1)
    let px = idx % w
    let py = idx / w
    // 填充
    for c in 0..<fill_ch {
      if c < fill_color.length() {
        out[idx * ch + c] = fill_color[c]
      }
    }
    // 4 邻域
    let neighbors = [(px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1)]
    for nb in neighbors {
      let (nx, ny) = nb
      if nx >= 0 && nx < w && ny >= 0 && ny < h {
        let nidx = ny * w + nx
        if !visited[nidx] {
          let nr = data_int[nidx * ch]
          let ng = data_int[nidx * ch + 1]
          let nb2 = data_int[nidx * ch + 2]
          let dist = color_dist_sq(seed_r, seed_g, seed_b, nr, ng, nb2)
          if dist <= threshold * threshold {
            visited[nidx] = true
            stack.push(nidx)
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

///|
/// 将分割标签图可视化为彩色图像。每个标签分配一个不同颜色。
pub fn segment_to_color(
  seg : SegmentLabelImage,
) -> @types.Image raise @types.LoadError {
  let w = seg.width
  let h = seg.height
  let n = w * h
  let out : Array[Byte] = Array::make(n * 3, b'\x00')
  let num = seg.num_regions
  for i in 0..<n {
    let label = seg.labels[i]
    if label >= 0 && label < num {
      let hue = Float::from_int(
        label * 360 / (if num > 0 { num } else { 1 }) % 360,
      )
      let (r, g, b) = @color.hsv_to_rgb(hue, 1.0F, 1.0F)
      out[i * 3] = r.to_byte()
      out[i * 3 + 1] = g.to_byte()
      out[i * 3 + 2] = b.to_byte()
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 3,
    data: Bytes::from_array(out),
  }
}

///|
fn color_dist_sq(
  r1 : Int,
  g1 : Int,
  b1 : Int,
  r2 : Int,
  g2 : Int,
  b2 : Int,
) -> Int {
  let dr = r1 - r2
  let dg = g1 - g2
  let db = b1 - b2
  dr * dr + dg * dg + db * db
}

///|
fn compute_regions(
  data_int : Array[Int],
  labels : Array[Int],
  w : Int,
  h : Int,
  ch : Int,
  k : Int,
) -> Array[SegmentRegion] {
  let sum_r : Array[Int] = Array::make(k, 0)
  let sum_g : Array[Int] = Array::make(k, 0)
  let sum_b : Array[Int] = Array::make(k, 0)
  let cnt : Array[Int] = Array::make(k, 0)
  let min_x : Array[Int] = Array::make(k, w)
  let min_y : Array[Int] = Array::make(k, h)
  let max_x : Array[Int] = Array::make(k, 0)
  let max_y : Array[Int] = Array::make(k, 0)
  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      let label = labels[idx]
      if label >= 0 && label < k {
        sum_r[label] += data_int[idx * ch]
        sum_g[label] += data_int[idx * ch + 1]
        sum_b[label] += data_int[idx * ch + 2]
        cnt[label] += 1
        if x < min_x[label] {
          min_x[label] = x
        }
        if x > max_x[label] {
          max_x[label] = x
        }
        if y < min_y[label] {
          min_y[label] = y
        }
        if y > max_y[label] {
          max_y[label] = y
        }
      }
    }
  }
  let regions : Array[SegmentRegion] = []
  for j in 0..<k {
    let area = cnt[j]
    regions.push(SegmentRegion::{
      label: j,
      area,
      mean_r: if area > 0 {
        sum_r[j] / area
      } else {
        0
      },
      mean_g: if area > 0 {
        sum_g[j] / area
      } else {
        0
      },
      mean_b: if area > 0 {
        sum_b[j] / area
      } else {
        0
      },
      bbox_x: if area > 0 {
        min_x[j]
      } else {
        0
      },
      bbox_y: if area > 0 {
        min_y[j]
      } else {
        0
      },
      bbox_w: if area > 0 {
        max_x[j] - min_x[j] + 1
      } else {
        0
      },
      bbox_h: if area > 0 {
        max_y[j] - min_y[j] + 1
      } else {
        0
      },
    })
  }
  regions
}
