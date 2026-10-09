// 色彩量化 16-bit/float 变体
// K-means 量化 + Median Cut

///|
fn read_u16_q(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() | (data[offset + 1].to_int() << 8)
}

///|
fn write_u16_q(data : Array[Byte], offset : Int, v : Int) -> Unit {
  data[offset] = (v & 0xFF).to_byte()
  data[offset + 1] = ((v >> 8) & 0xFF).to_byte()
}

///|
fn read_f32_q(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
fn write_f32_q(data : Array[Byte], offset : Int, v : Float) -> Unit {
  let bits = v.reinterpret_as_int()
  data[offset] = (bits & 0xFF).to_byte()
  data[offset + 1] = ((bits >> 8) & 0xFF).to_byte()
  data[offset + 2] = ((bits >> 16) & 0xFF).to_byte()
  data[offset + 3] = ((bits >> 24) & 0xFF).to_byte()
}

///|
fn dist_sq_f(
  r1 : Float,
  g1 : Float,
  b1 : Float,
  r2 : Float,
  g2 : Float,
  b2 : Float,
) -> Float {
  let dr = r1 - r2
  let dg = g1 - g2
  let db = b1 - b2
  dr * dr + dg * dg + db * db
}

// ========== K-means 量化 16-bit ==========

///|
/// K-means 色彩量化 16-bit 版本。
pub fn kmeans_quantize_16(
  img : @types.Image16,
  k : Int,
  max_iters : Int,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width < 0 || img.height < 0 {
    raise @types.LoadError::DecodeFailed(
      "kmeans_quantize_16: 图像尺寸不能为负",
    )
  }
  if k < 1 || k > 256 {
    raise @types.LoadError::DecodeFailed("k 必须在 1..256 之间")
  }
  if img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "kmeans_quantize_16 需要 RGB/RGBA 图像",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "kmeans_quantize_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let ch = img.channels
  let n = img.width * img.height
  if n == 0 {
    return img
  }
  let centroids_r : Array[Int] = Array::make(k, 0)
  let centroids_g : Array[Int] = Array::make(k, 0)
  let centroids_b : Array[Int] = Array::make(k, 0)
  let data_int : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    data_int[i] = read_u16_q(img.data, i * 2)
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
      let mut best_dist = (r - centroids_r[0]) * (r - centroids_r[0]) +
        (g - centroids_g[0]) * (g - centroids_g[0]) +
        (b - centroids_b[0]) * (b - centroids_b[0])
      for j in 1..<k {
        let d = (r - centroids_r[j]) * (r - centroids_r[j]) +
          (g - centroids_g[j]) * (g - centroids_g[j]) +
          (b - centroids_b[j]) * (b - centroids_b[j])
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
  let out : Array[Byte] = Array::make(n * ch * 2, b'\x00')
  for i in 0..<n {
    let label = labels[i]
    write_u16_q(out, i * ch * 2, centroids_r[label])
    write_u16_q(out, (i * ch + 1) * 2, centroids_g[label])
    write_u16_q(out, (i * ch + 2) * 2, centroids_b[label])
    if ch == 4 {
      let v = read_u16_q(img.data, (i * ch + 3) * 2)
      write_u16_q(out, (i * ch + 3) * 2, v)
    }
  }
  @types.Image16::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== K-means 量化 float ==========

///|
/// K-means 色彩量化 float 版本。
pub fn kmeans_quantize_f(
  img : @types.ImageF,
  k : Int,
  max_iters : Int,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width < 0 || img.height < 0 {
    raise @types.LoadError::DecodeFailed(
      "kmeans_quantize_f: 图像尺寸不能为负",
    )
  }
  if k < 1 || k > 256 {
    raise @types.LoadError::DecodeFailed("k 必须在 1..256 之间")
  }
  if img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "kmeans_quantize_f 需要 RGB/RGBA 图像",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "kmeans_quantize_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let ch = img.channels
  let n = img.width * img.height
  if n == 0 {
    return img
  }
  let centroids_r : Array[Float] = Array::make(k, 0.0F)
  let centroids_g : Array[Float] = Array::make(k, 0.0F)
  let centroids_b : Array[Float] = Array::make(k, 0.0F)
  let data_f : Array[Float] = Array::make(n * ch, 0.0F)
  for i in 0..<(n * ch) {
    data_f[i] = read_f32_q(img.data, i * 4)
  }
  let step = if n > k { n / k } else { 1 }
  for i in 0..<k {
    let idx = (i * step).clamp(min=0, max=n - 1)
    centroids_r[i] = data_f[idx * ch]
    centroids_g[i] = data_f[idx * ch + 1]
    centroids_b[i] = data_f[idx * ch + 2]
  }
  let labels : Array[Int] = Array::make(n, 0)
  let iters = if max_iters < 1 { 20 } else { max_iters }
  for _ in 0..<iters {
    let mut changed = false
    for i in 0..<n {
      let r = data_f[i * ch]
      let g = data_f[i * ch + 1]
      let b = data_f[i * ch + 2]
      let mut best = 0
      let mut best_dist = dist_sq_f(
        r,
        g,
        b,
        centroids_r[0],
        centroids_g[0],
        centroids_b[0],
      )
      for j in 1..<k {
        let d = dist_sq_f(
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
    let sum_r : Array[Float] = Array::make(k, 0.0F)
    let sum_g : Array[Float] = Array::make(k, 0.0F)
    let sum_b : Array[Float] = Array::make(k, 0.0F)
    let cnt : Array[Int] = Array::make(k, 0)
    for i in 0..<n {
      let label = labels[i]
      sum_r[label] += data_f[i * ch]
      sum_g[label] += data_f[i * ch + 1]
      sum_b[label] += data_f[i * ch + 2]
      cnt[label] += 1
    }
    for j in 0..<k {
      if cnt[j] > 0 {
        centroids_r[j] = sum_r[j] / Float::from_int(cnt[j])
        centroids_g[j] = sum_g[j] / Float::from_int(cnt[j])
        centroids_b[j] = sum_b[j] / Float::from_int(cnt[j])
      }
    }
  }
  let out : Array[Byte] = Array::make(n * ch * 4, b'\x00')
  for i in 0..<n {
    let label = labels[i]
    write_f32_q(out, i * ch * 4, centroids_r[label])
    write_f32_q(out, (i * ch + 1) * 4, centroids_g[label])
    write_f32_q(out, (i * ch + 2) * 4, centroids_b[label])
    if ch == 4 {
      let v = read_f32_q(img.data, (i * ch + 3) * 4)
      write_f32_q(out, (i * ch + 3) * 4, v)
    }
  }
  @types.ImageF::{
    width: img.width,
    height: img.height,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== Floyd-Steinberg 抖动 16-bit ==========

///|
/// Floyd-Steinberg 误差扩散抖动量化 16-bit 版本。
pub fn floyd_steinberg_16(
  img : @types.Image16,
  levels : Int,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "floyd_steinberg_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "floyd_steinberg_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "floyd_steinberg_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if levels < 2 {
    raise @types.LoadError::DecodeFailed("floyd_steinberg_16: levels必须>=2")
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let w = img.width
  let h = img.height
  let n = w * h
  let buf : Array[Int] = Array::make(n * color_ch, 0)
  for i in 0..<n {
    for c in 0..<color_ch {
      buf[i * color_ch + c] = read_u16_q(img.data, (i * ch + c) * 2)
    }
  }
  let step = 65535 / (levels - 1)
  let half_step = step / 2
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<color_ch {
        let idx = (y * w + x) * color_ch + c
        let old_val = if buf[idx] < 0 {
          0
        } else if buf[idx] > 65535 {
          65535
        } else {
          buf[idx]
        }
        let new_val = (old_val + half_step) / step * step
        let new_val_clamped = if new_val < 0 {
          0
        } else if new_val > 65535 {
          65535
        } else {
          new_val
        }
        buf[idx] = new_val_clamped
        let err = old_val - new_val_clamped
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
  let out : Array[Byte] = Array::make(n * ch * 2, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let v = if buf[i * color_ch + c] < 0 {
        0
      } else if buf[i * color_ch + c] > 65535 {
        65535
      } else {
        buf[i * color_ch + c]
      }
      write_u16_q(out, (i * ch + c) * 2, v)
    }
    if ch == 4 {
      let v = read_u16_q(img.data, (i * ch + 3) * 2)
      write_u16_q(out, (i * ch + 3) * 2, v)
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== Floyd-Steinberg 抖动 float ==========

///|
/// Floyd-Steinberg 误差扩散抖动量化 float 版本。
pub fn floyd_steinberg_f(
  img : @types.ImageF,
  levels : Int,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "floyd_steinberg_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "floyd_steinberg_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "floyd_steinberg_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if levels < 2 {
    return img
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let w = img.width
  let h = img.height
  let n = w * h
  let buf : Array[Float] = Array::make(n * color_ch, 0.0F)
  for i in 0..<n {
    for c in 0..<color_ch {
      buf[i * color_ch + c] = read_f32_q(img.data, (i * ch + c) * 4)
    }
  }
  let step = 1.0F / Float::from_int(levels - 1)
  let half_step = step / 2.0F
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<color_ch {
        let idx = (y * w + x) * color_ch + c
        let old_val = if buf[idx] < 0.0F {
          0.0F
        } else if buf[idx] > 1.0F {
          1.0F
        } else {
          buf[idx]
        }
        let new_val = Float::from_int(((old_val + half_step) / step).to_int()) *
          step
        let new_val_clamped = if new_val < 0.0F {
          0.0F
        } else if new_val > 1.0F {
          1.0F
        } else {
          new_val
        }
        buf[idx] = new_val_clamped
        let err = old_val - new_val_clamped
        if x + 1 < w {
          buf[(y * w + x + 1) * color_ch + c] += err * 7.0F / 16.0F
        }
        if y + 1 < h {
          if x > 0 {
            buf[((y + 1) * w + x - 1) * color_ch + c] += err * 3.0F / 16.0F
          }
          buf[((y + 1) * w + x) * color_ch + c] += err * 5.0F / 16.0F
          if x + 1 < w {
            buf[((y + 1) * w + x + 1) * color_ch + c] += err / 16.0F
          }
        }
      }
    }
  }
  let out : Array[Byte] = Array::make(n * ch * 4, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let v = if buf[i * color_ch + c] < 0.0F {
        0.0F
      } else if buf[i * color_ch + c] > 1.0F {
        1.0F
      } else {
        buf[i * color_ch + c]
      }
      write_f32_q(out, (i * ch + c) * 4, v)
    }
    if ch == 4 {
      let v = read_f32_q(img.data, (i * ch + 3) * 4)
      write_f32_q(out, (i * ch + 3) * 4, v)
    }
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

// ========== Median Cut 辅助函数 16-bit ==========

///|
fn channel_value_mc16(pixel : (Int, Int, Int), ch : Int) -> Int {
  match ch {
    0 => pixel.0
    1 => pixel.1
    _ => pixel.2
  }
}

///|
fn bucket_max_range_mc16(
  pixels : Array[(Int, Int, Int)],
  bucket : Array[Int],
) -> (Int, Int) {
  let mut min_r = 65535
  let mut max_r = 0
  let mut min_g = 65535
  let mut max_g = 0
  let mut min_b = 65535
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
fn bucket_average_mc16(
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

// ========== Median Cut 16-bit ==========

///|
/// Median Cut 色彩量化 16-bit 版本。
pub fn median_cut_16(
  img : @types.Image16,
  num_colors : Int,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "median_cut_16: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "median_cut_16: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "median_cut_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if num_colors < 2 {
    raise @types.LoadError::DecodeFailed("median_cut_16: num_colors必须>=2")
  }
  let w = img.width
  let h = img.height
  let n = w * h
  let ch = img.channels
  let pixels : Array[(Int, Int, Int)] = Array::make(n, (0, 0, 0))
  for i in 0..<n {
    let r = read_u16_q(img.data, i * ch * 2)
    let g = if ch >= 2 { read_u16_q(img.data, (i * ch + 1) * 2) } else { r }
    let b = if ch >= 3 { read_u16_q(img.data, (i * ch + 2) * 2) } else { r }
    pixels[i] = (r, g, b)
  }
  let initial_bucket : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    initial_bucket[i] = i
  }
  let buckets : Array[Array[Int]] = [initial_bucket]
  let mut num_buckets = 1
  while num_buckets < num_colors {
    let mut best_bucket_idx = -1
    let mut best_range = 0
    for bi in 0..<buckets.length() {
      if buckets[bi].length() < 2 {
        continue
      }
      let (range, _ch) = bucket_max_range_mc16(pixels, buckets[bi])
      if range > best_range {
        best_range = range
        best_bucket_idx = bi
      }
    }
    if best_bucket_idx < 0 {
      break
    }
    let bucket = buckets[best_bucket_idx]
    let (_, split_ch) = bucket_max_range_mc16(pixels, bucket)
    let sorted = bucket.copy()
    sorted.sort_by(fn(a, b) {
      let va = channel_value_mc16(pixels[a], split_ch)
      let vb = channel_value_mc16(pixels[b], split_ch)
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
  let palette : Array[(Int, Int, Int)] = Array::make(
    buckets.length(),
    (0, 0, 0),
  )
  for bi in 0..<buckets.length() {
    palette[bi] = bucket_average_mc16(pixels, buckets[bi])
  }
  let out : Array[Byte] = Array::make(n * 3 * 2, b'\x00')
  for i in 0..<n {
    let (r, g, b) = pixels[i]
    let mut best_idx = 0
    let mut best_dist = 999999999
    for pi in 0..<palette.length() {
      let (pr, pg, pb) = palette[pi]
      let dist = (r - pr) * (r - pr) + (g - pg) * (g - pg) + (b - pb) * (b - pb)
      if dist < best_dist {
        best_dist = dist
        best_idx = pi
      }
    }
    let (pr, pg, pb) = palette[best_idx]
    write_u16_q(out, i * 6, pr)
    write_u16_q(out, i * 6 + 2, pg)
    write_u16_q(out, i * 6 + 4, pb)
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: 3,
    data: Bytes::from_array(out),
  }
}

// ========== Median Cut 辅助函数 float ==========

///|
fn channel_value_mcf(pixel : (Float, Float, Float), ch : Int) -> Float {
  match ch {
    0 => pixel.0
    1 => pixel.1
    _ => pixel.2
  }
}

///|
fn bucket_max_range_mcf(
  pixels : Array[(Float, Float, Float)],
  bucket : Array[Int],
) -> (Float, Int) {
  let mut min_r = 1.0F
  let mut max_r = 0.0F
  let mut min_g = 1.0F
  let mut max_g = 0.0F
  let mut min_b = 1.0F
  let mut max_b = 0.0F
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
fn bucket_average_mcf(
  pixels : Array[(Float, Float, Float)],
  bucket : Array[Int],
) -> (Float, Float, Float) {
  let mut sum_r = 0.0F
  let mut sum_g = 0.0F
  let mut sum_b = 0.0F
  for i in 0..<bucket.length() {
    let (r, g, b) = pixels[bucket[i]]
    sum_r += r
    sum_g += g
    sum_b += b
  }
  let len = Float::from_int(bucket.length())
  if len == 0.0F {
    (0.0F, 0.0F, 0.0F)
  } else {
    (sum_r / len, sum_g / len, sum_b / len)
  }
}

// ========== Median Cut float ==========

///|
/// Median Cut 色彩量化 float 版本。
pub fn median_cut_f(
  img : @types.ImageF,
  num_colors : Int,
) -> @types.ImageF raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "median_cut_f: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "median_cut_f: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "median_cut_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if num_colors < 2 {
    return img
  }
  let w = img.width
  let h = img.height
  let n = w * h
  let ch = img.channels
  let pixels : Array[(Float, Float, Float)] = Array::make(n, (0.0F, 0.0F, 0.0F))
  for i in 0..<n {
    let r = read_f32_q(img.data, i * ch * 4)
    let g = if ch >= 2 { read_f32_q(img.data, (i * ch + 1) * 4) } else { r }
    let b = if ch >= 3 { read_f32_q(img.data, (i * ch + 2) * 4) } else { r }
    pixels[i] = (r, g, b)
  }
  let initial_bucket : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    initial_bucket[i] = i
  }
  let buckets : Array[Array[Int]] = [initial_bucket]
  let mut num_buckets = 1
  while num_buckets < num_colors {
    let mut best_bucket_idx = -1
    let mut best_range = 0.0F
    for bi in 0..<buckets.length() {
      if buckets[bi].length() < 2 {
        continue
      }
      let (range, _ch) = bucket_max_range_mcf(pixels, buckets[bi])
      if range > best_range {
        best_range = range
        best_bucket_idx = bi
      }
    }
    if best_bucket_idx < 0 {
      break
    }
    let bucket = buckets[best_bucket_idx]
    let (_, split_ch) = bucket_max_range_mcf(pixels, bucket)
    let sorted = bucket.copy()
    sorted.sort_by(fn(a, b) {
      let va = channel_value_mcf(pixels[a], split_ch)
      let vb = channel_value_mcf(pixels[b], split_ch)
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
  let palette : Array[(Float, Float, Float)] = Array::make(
    buckets.length(),
    (0.0F, 0.0F, 0.0F),
  )
  for bi in 0..<buckets.length() {
    palette[bi] = bucket_average_mcf(pixels, buckets[bi])
  }
  let out : Array[Byte] = Array::make(n * 3 * 4, b'\x00')
  for i in 0..<n {
    let (r, g, b) = pixels[i]
    let mut best_idx = 0
    let mut best_dist = 999.0F
    for pi in 0..<palette.length() {
      let (pr, pg, pb) = palette[pi]
      let dist = (r - pr) * (r - pr) + (g - pg) * (g - pg) + (b - pb) * (b - pb)
      if dist < best_dist {
        best_dist = dist
        best_idx = pi
      }
    }
    let (pr, pg, pb) = palette[best_idx]
    write_f32_q(out, i * 12, pr)
    write_f32_q(out, i * 12 + 4, pg)
    write_f32_q(out, i * 12 + 8, pb)
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: 3,
    data: Bytes::from_array(out),
  }
}
