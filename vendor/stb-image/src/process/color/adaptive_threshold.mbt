// 自适应阈值（纯 MoonBit）

///|
/// 自适应阈值（均值法）。以每个像素周围 block_size×block_size 区域的均值减去 C 作为局部阈值。
/// 仅处理灰度图（channels=1）或 RGB 图（channels=3/4），alpha 通道不变。
pub fn adaptive_threshold_mean(
  img : @types.Image,
  block_size : Int,
  c : Int,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "adaptive_threshold_mean: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "adaptive_threshold_mean 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "adaptive_threshold_mean: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if block_size < 3 || block_size % 2 == 0 {
    raise @types.LoadError::DecodeFailed("block_size 必须为 >=3 的奇数")
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { 1 }
  let w = img.width
  let h = img.height
  let n = w * h
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  let half = block_size / 2
  // 预计算像素 Int 数组
  let src : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    src[i] = img.data[i].to_int()
  }
  // 内部区域 count 恒为 block_size²
  let inner_count = block_size * block_size
  for c_idx in 0..<color_ch {
    // 内部区域：x in [half, w-half), y in [half, h-half)
    for y in half..<(h - half) {
      for x in half..<(w - half) {
        let mut sum = 0
        for dy in -half..<=half {
          let row = (y + dy) * w
          for dx in -half..<=half {
            sum += src[(row + x + dx) * ch + c_idx]
          }
        }
        let mean = sum / inner_count
        let threshold = mean - c
        let v = src[(y * w + x) * ch + c_idx]
        out[(y * w + x) * ch + c_idx] = if v > threshold {
          b'\xFF'
        } else {
          b'\x00'
        }
      }
    }
    // 边界区域
    for y in 0..<h {
      let y_inner = y >= half && y < h - half
      for x in 0..<w {
        if y_inner && x >= half && x < w - half {
          continue
        }
        let mut sum = 0
        let mut count = 0
        for dy in -half..<=half {
          for dx in -half..<=half {
            let ny = y + dy
            let nx = x + dx
            if ny >= 0 && ny < h && nx >= 0 && nx < w {
              sum += src[(ny * w + nx) * ch + c_idx]
              count += 1
            }
          }
        }
        let mean = if count > 0 { sum / count } else { 0 }
        let threshold = mean - c
        let v = src[(y * w + x) * ch + c_idx]
        out[(y * w + x) * ch + c_idx] = if v > threshold {
          b'\xFF'
        } else {
          b'\x00'
        }
      }
    }
  }
  if ch == 4 {
    for i in 0..<n {
      out[i * 4 + 3] = img.data[i * 4 + 3]
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
/// 自适应阈值（高斯加权法）。以每个像素周围 block_size×block_size 区域的高斯加权均值减去 C 作为局部阈值。
pub fn adaptive_threshold_gaussian(
  img : @types.Image,
  block_size : Int,
  c : Int,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "adaptive_threshold_gaussian: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "adaptive_threshold_gaussian 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "adaptive_threshold_gaussian: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if block_size < 3 || block_size % 2 == 0 {
    raise @types.LoadError::DecodeFailed("block_size 必须为 >=3 的奇数")
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { 1 }
  let w = img.width
  let h = img.height
  let n = w * h
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  let half = block_size / 2
  let sigma = Float::from_int(half) / 2.0F
  let two_sigma_sq = 2.0F * sigma * sigma
  // 预计算高斯权重（1D 扁平化）
  let weights : Array[Float] = Array::make(block_size * block_size, 0.0F)
  let mut total_weight = 0.0F
  for dy in 0..<block_size {
    for dx in 0..<block_size {
      let fy = Float::from_int(dy - half)
      let fx = Float::from_int(dx - half)
      let wt = @math.expf(-(fx * fx + fy * fy) / two_sigma_sq)
      weights[dy * block_size + dx] = wt
      total_weight += wt
    }
  }
  // 预计算像素 Float 数组
  let src : Array[Float] = Array::make(n * ch, 0.0F)
  for i in 0..<(n * ch) {
    src[i] = Float::from_int(img.data[i].to_int())
  }
  for c_idx in 0..<color_ch {
    // 内部区域：weight_sum 恒为 total_weight
    for y in half..<(h - half) {
      for x in half..<(w - half) {
        let mut sum = 0.0F
        for dy in 0..<block_size {
          let row = (y + dy - half) * w
          let wbase = dy * block_size
          for dx in 0..<block_size {
            sum += src[(row + x + dx - half) * ch + c_idx] * weights[wbase + dx]
          }
        }
        let mean = sum / total_weight
        let threshold = mean - Float::from_int(c)
        let v = src[(y * w + x) * ch + c_idx]
        out[(y * w + x) * ch + c_idx] = if v > threshold {
          b'\xFF'
        } else {
          b'\x00'
        }
      }
    }
    // 边界区域
    for y in 0..<h {
      let y_inner = y >= half && y < h - half
      for x in 0..<w {
        if y_inner && x >= half && x < w - half {
          continue
        }
        let mut sum = 0.0F
        let mut weight_sum = 0.0F
        for dy in -half..<=half {
          for dx in -half..<=half {
            let ny = y + dy
            let nx = x + dx
            if ny >= 0 && ny < h && nx >= 0 && nx < w {
              let weight = weights[(dy + half) * block_size + (dx + half)]
              sum += src[(ny * w + nx) * ch + c_idx] * weight
              weight_sum += weight
            }
          }
        }
        let mean = if weight_sum > 0.0F { sum / weight_sum } else { 0.0F }
        let threshold = mean - Float::from_int(c)
        let v = src[(y * w + x) * ch + c_idx]
        out[(y * w + x) * ch + c_idx] = if v > threshold {
          b'\xFF'
        } else {
          b'\x00'
        }
      }
    }
  }
  if ch == 4 {
    for i in 0..<n {
      out[i * 4 + 3] = img.data[i * 4 + 3]
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
/// Otsu 大津法自动阈值。自动计算最佳全局阈值并二值化。
pub fn threshold_otsu(
  img : @types.Image,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "threshold_otsu: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "threshold_otsu 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "threshold_otsu: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { 1 }
  let w = img.width
  let h = img.height
  let n = w * h
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  for c_idx in 0..<color_ch {
    let hist : Array[Int] = Array::make(256, 0)
    for i in 0..<n {
      hist[img.data[i * ch + c_idx].to_int()] += 1
    }
    let mut total = 0
    let mut sum = 0
    for t in 0..<256 {
      total += hist[t]
      sum += t * hist[t]
    }
    let mut best_t = 0
    let mut best_var = -1.0F
    let mut w0 = 0
    let mut sum0 = 0
    for t in 0..<256 {
      w0 += hist[t]
      sum0 += t * hist[t]
      if w0 == 0 || w0 == total {
        continue
      }
      let w1 = total - w0
      let sum1 = sum - sum0
      let mean0 = Float::from_int(sum0) / Float::from_int(w0)
      let mean1 = Float::from_int(sum1) / Float::from_int(w1)
      let var_between = Float::from_int(w0) *
        Float::from_int(w1) *
        (mean0 - mean1) *
        (mean0 - mean1)
      if var_between > best_var {
        best_var = var_between
        best_t = t
      }
    }
    for i in 0..<n {
      let v = img.data[i * ch + c_idx].to_int()
      out[i * ch + c_idx] = if v > best_t { b'\xFF' } else { b'\x00' }
    }
  }
  if ch == 4 {
    for i in 0..<n {
      out[i * 4 + 3] = img.data[i * 4 + 3]
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}
