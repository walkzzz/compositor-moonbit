// 色彩量化（纯 MoonBit）：Floyd-Steinberg 抖动 + Median Cut + K-means 量化

///|
/// Floyd-Steinberg 误差扩散抖动量化。
/// levels 为每通道量化级别数（如 levels=2 → 0/255，levels=4 → 0/85/170/255）。
/// 仅处理颜色通道，alpha 不变。
pub fn floyd_steinberg(
  img : @types.Image,
  levels : Int,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "floyd_steinberg: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "floyd_steinberg: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "floyd_steinberg: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if levels < 2 {
    raise @types.LoadError::DecodeFailed("floyd_steinberg: levels必须>=2")
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let w = img.width
  let h = img.height
  let n = w * h
  // 可变像素缓冲
  let buf : Array[Int] = Array::make(n * color_ch, 0)
  for i in 0..<n {
    for c in 0..<color_ch {
      buf[i * color_ch + c] = img.data[i * ch + c].to_int()
    }
  }
  let step = 255 / (levels - 1)
  let half_step = step / 2
  // Floyd-Steinberg 抖动
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<color_ch {
        let idx = (y * w + x) * color_ch + c
        let old_val = buf[idx].clamp(min=0, max=255)
        let new_val = ((old_val + half_step) / step * step).clamp(
          min=0,
          max=255,
        )
        buf[idx] = new_val
        let err = old_val - new_val
        // 误差扩散：右 7/16, 左下 3/16, 下 5/16, 右下 1/16
        if x + 1 < w {
          buf[(y * w + x + 1) * color_ch + c] += err * 7 / 16
        }
        if y + 1 < h {
          if x > 0 {
            buf[((y + 1) * w + x - 1) * color_ch + c] += err * 3 / 16
          }
          buf[((y + 1) * w + x) * color_ch + c] += err * 5 / 16
          if x + 1 < w {
            buf[((y + 1) * w + x + 1) * color_ch + c] += err / 16
          }
        }
      }
    }
  }
  // 输出
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      out[i * ch + c] = buf[i * color_ch + c].clamp(min=0, max=255).to_byte()
    }
    if ch == 4 {
      out[i * ch + 3] = img.data[i * ch + 3]
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
/// Median Cut 色彩量化。将图像量化为最多 num_colors 种颜色。
/// 返回量化后的 RGB 图像（channels=3）。
/// 算法：递归地沿最大方差通道在中位数处分割颜色空间。
pub fn median_cut(
  img : @types.Image,
  num_colors : Int,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "median_cut: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "median_cut: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "median_cut: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if num_colors < 2 {
    return to_rgb(img)
  }
  let w = img.width
  let h = img.height
  let n = w * h
  // 收集所有 RGB 像素
  let pixels : Array[(Int, Int, Int)] = Array::make(n, (0, 0, 0))
  let ch = img.channels
  let data_int : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    data_int[i] = img.data[i].to_int()
  }
  for i in 0..<n {
    let r = data_int[i * ch]
    let g = if ch >= 2 { data_int[i * ch + 1] } else { r }
    let b = if ch >= 3 { data_int[i * ch + 2] } else { r }
    pixels[i] = (r, g, b)
  }
  // 初始 bucket 包含所有像素索引
  let initial_bucket : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    initial_bucket[i] = i
  }
  // 递归分割
  let buckets : Array[Array[Int]] = [initial_bucket]
  let mut num_buckets = 1
  while num_buckets < num_colors {
    // 找到范围最大的 bucket
    let mut best_bucket_idx = -1
    let mut best_range = 0
    for bi in 0..<buckets.length() {
      if buckets[bi].length() < 2 {
        continue
      }
      let (range, _ch) = bucket_max_range(pixels, buckets[bi])
      if range > best_range {
        best_range = range
        best_bucket_idx = bi
      }
    }
    if best_bucket_idx < 0 {
      break
    }
    // 分割最佳 bucket
    let bucket = buckets[best_bucket_idx]
    let (_, split_ch) = bucket_max_range(pixels, bucket)
    // 按分割通道排序
    let sorted = bucket.copy()
    sorted.sort_by(fn(a, b) {
      let va = channel_value(pixels[a], split_ch)
      let vb = channel_value(pixels[b], split_ch)
      va.compare(vb)
    })
    let mid = sorted.length() / 2
    let left : Array[Int] = Array::make(mid, 0)
    let right : Array[Int] = Array::make(sorted.length() - mid, 0)
    for i in 0..<mid {
      left[i] = sorted[i]
    }
    for i in mid..<sorted.length() {
      right[i - mid] = sorted[i]
    }
    buckets[best_bucket_idx] = left
    buckets.push(right)
    num_buckets += 1
  }
  // 计算每个 bucket 的平均色作为调色板
  let palette : Array[(Int, Int, Int)] = Array::make(
    buckets.length(),
    (0, 0, 0),
  )
  for bi in 0..<buckets.length() {
    palette[bi] = bucket_average(pixels, buckets[bi])
  }
  // 映射每个像素到最近的调色板颜色
  let out : Array[Byte] = Array::make(n * 3, b'\x00')
  for i in 0..<n {
    let (r, g, b) = pixels[i]
    let mut best_idx = 0
    let mut best_dist = 999999
    for pi in 0..<palette.length() {
      let (pr, pg, pb) = palette[pi]
      let dist = (r - pr) * (r - pr) + (g - pg) * (g - pg) + (b - pb) * (b - pb)
      if dist < best_dist {
        best_dist = dist
        best_idx = pi
      }
    }
    let (pr, pg, pb) = palette[best_idx]
    out[i * 3] = pr.to_byte()
    out[i * 3 + 1] = pg.to_byte()
    out[i * 3 + 2] = pb.to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 3,
    data: Bytes::from_array(out),
  }
}

///|
/// K-means 色彩量化。将图像颜色聚为 k 类，每类用聚类中心替代。
/// 适用于 RGB/RGBA 图像（channels=3/4），alpha 通道不变。
/// max_iters 控制最大迭代次数（默认 20）。
pub fn kmeans_quantize(
  img : @types.Image,
  k : Int,
  max_iters : Int,
) -> @types.Image raise @types.LoadError {
  if k < 1 || k > 256 {
    raise @types.LoadError::DecodeFailed("k 必须在 1..256 之间")
  }
  if img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "kmeans_quantize 需要 RGB/RGBA 图像",
    )
  }
  let ch = img.channels
  let n = img.width * img.height
  if n == 0 {
    return img
  }
  // 初始化聚类中心：均匀采样
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
  // 迭代
  let labels : Array[Int] = Array::make(n, 0)
  let iters = if max_iters < 1 { 20 } else { max_iters }
  for _ in 0..<iters {
    // 分配每个像素到最近的聚类
    let mut changed = false
    for i in 0..<n {
      let r = data_int[i * ch]
      let g = data_int[i * ch + 1]
      let b = data_int[i * ch + 2]
      let mut best = 0
      let mut best_dist = dist_sq(
        r,
        g,
        b,
        centroids_r[0],
        centroids_g[0],
        centroids_b[0],
      )
      for j in 1..<k {
        let d = dist_sq(r, g, b, centroids_r[j], centroids_g[j], centroids_b[j])
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

    // 更新聚类中心
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
  // 生成输出
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  for i in 0..<n {
    let label = labels[i]
    out[i * ch] = centroids_r[label].to_byte()
    out[i * ch + 1] = centroids_g[label].to_byte()
    out[i * ch + 2] = centroids_b[label].to_byte()
    if ch == 4 {
      out[i * ch + 3] = img.data[i * ch + 3]
    }
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
fn channel_value(pixel : (Int, Int, Int), ch : Int) -> Int {
  match ch {
    0 => pixel.0
    1 => pixel.1
    _ => pixel.2
  }
}

///|
fn bucket_max_range(
  pixels : Array[(Int, Int, Int)],
  bucket : Array[Int],
) -> (Int, Int) {
  let mut min_r = 255
  let mut max_r = 0
  let mut min_g = 255
  let mut max_g = 0
  let mut min_b = 255
  let mut max_b = 0
  for i in 0..<bucket.length() {
    let (r, g, b) = pixels[bucket[i]]
    if r < min_r {
      min_r = r
    }
    if r > max_r {
      max_r = r
    }
    if g < min_g {
      min_g = g
    }
    if g > max_g {
      max_g = g
    }
    if b < min_b {
      min_b = b
    }
    if b > max_b {
      max_b = b
    }
  }
  let range_r = max_r - min_r
  let range_g = max_g - min_g
  let range_b = max_b - min_b
  if range_r >= range_g && range_r >= range_b {
    (range_r, 0)
  } else if range_g >= range_b {
    (range_g, 1)
  } else {
    (range_b, 2)
  }
}

///|
fn bucket_average(
  pixels : Array[(Int, Int, Int)],
  bucket : Array[Int],
) -> (Int, Int, Int) {
  let mut sum_r = 0
  let mut sum_g = 0
  let mut sum_b = 0
  for i in 0..<bucket.length() {
    let (r, g, b) = pixels[bucket[i]]
    sum_r += r
    sum_g += g
    sum_b += b
  }
  let len = bucket.length()
  if len == 0 {
    (0, 0, 0)
  } else {
    (sum_r / len, sum_g / len, sum_b / len)
  }
}

///|
fn dist_sq(r1 : Int, g1 : Int, b1 : Int, r2 : Int, g2 : Int, b2 : Int) -> Int {
  let dr = r1 - r2
  let dg = g1 - g2
  let db = b1 - b2
  dr * dr + dg * dg + db * db
}
