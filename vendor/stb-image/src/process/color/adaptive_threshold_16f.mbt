// 阈值处理 16-bit/float 变体
// 支持 Image16 / ImageF 两种类型
// 输出均为二值图像（16-bit: 0/65535，float: 0.0/1.0）

// 复用 color_16f.mbt 中的 read_u16_le_c / write_u16_le_c / write_f32_le
// 复用 tonemap.mbt 中的 read_float_le

///|
/// 16-bit 自适应阈值（均值法）。block_size 必须为 >=3 的奇数。
/// 输出二值图像（0 或 65535），alpha 通道不变。
pub fn adaptive_threshold_mean_16(
  img : @types.Image16,
  block_size : Int,
  c : Int,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "adaptive_threshold_mean_16: 图像尺寸必须大于0",
    )
  }
  if block_size < 3 || block_size % 2 == 0 {
    raise @types.LoadError::DecodeFailed("block_size 必须为 >=3 的奇数")
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "adaptive_threshold_mean_16 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "adaptive_threshold_mean_16: 数据大小不匹配，期望 " +
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
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let half = block_size / 2
  let src : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    src[i] = read_u16_le_c(img.data, i * 2)
  }
  let inner_count = block_size * block_size
  for c_idx in 0..<color_ch {
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
        if v > threshold {
          write_u16_le_c(out, (y * w + x) * bpp + c_idx * 2, 65535)
        }
      }
    }
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
        if v > threshold {
          write_u16_le_c(out, (y * w + x) * bpp + c_idx * 2, 65535)
        }
      }
    }
  }
  if ch == 4 {
    for i in 0..<n {
      let alpha_off = i * bpp + 6
      out[alpha_off] = img.data[alpha_off]
      out[alpha_off + 1] = img.data[alpha_off + 1]
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// float 自适应阈值（均值法）。c 为浮点偏移量。
/// 输出二值图像（0.0 或 1.0），alpha 通道不变。
pub fn adaptive_threshold_mean_f(
  img : @types.ImageF,
  block_size : Int,
  c : Float,
) -> @types.ImageF raise @types.LoadError {
  if block_size < 3 || block_size % 2 == 0 {
    raise @types.LoadError::DecodeFailed("block_size 必须为 >=3 的奇数")
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "adaptive_threshold_mean_f 仅支持 channels=1/3/4",
    )
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { 1 }
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let half = block_size / 2
  let src : Array[Float] = Array::make(n * ch, 0.0F)
  for i in 0..<(n * ch) {
    src[i] = read_float_le(img.data, i * 4)
  }
  let inner_count = Float::from_int(block_size * block_size)
  for c_idx in 0..<color_ch {
    for y in half..<(h - half) {
      for x in half..<(w - half) {
        let mut sum = 0.0F
        for dy in -half..<=half {
          let row = (y + dy) * w
          for dx in -half..<=half {
            sum += src[(row + x + dx) * ch + c_idx]
          }
        }
        let mean = sum / inner_count
        let threshold = mean - c
        let v = src[(y * w + x) * ch + c_idx]
        if v > threshold {
          write_f32_le(out, (y * w + x) * bpp + c_idx * 4, 1.0F)
        }
      }
    }
    for y in 0..<h {
      let y_inner = y >= half && y < h - half
      for x in 0..<w {
        if y_inner && x >= half && x < w - half {
          continue
        }
        let mut sum = 0.0F
        let mut count = 0.0F
        for dy in -half..<=half {
          for dx in -half..<=half {
            let ny = y + dy
            let nx = x + dx
            if ny >= 0 && ny < h && nx >= 0 && nx < w {
              sum += src[(ny * w + nx) * ch + c_idx]
              count += 1.0F
            }
          }
        }
        let mean = if count > 0.0F { sum / count } else { 0.0F }
        let threshold = mean - c
        let v = src[(y * w + x) * ch + c_idx]
        if v > threshold {
          write_f32_le(out, (y * w + x) * bpp + c_idx * 4, 1.0F)
        }
      }
    }
  }
  if ch == 4 {
    for i in 0..<n {
      let alpha_off = i * bpp + 12
      for b in 0..<4 {
        out[alpha_off + b] = img.data[alpha_off + b]
      }
    }
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 16-bit 自适应阈值（高斯加权法）。
pub fn adaptive_threshold_gaussian_16(
  img : @types.Image16,
  block_size : Int,
  c : Int,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "adaptive_threshold_gaussian_16: 图像尺寸必须大于0",
    )
  }
  if block_size < 3 || block_size % 2 == 0 {
    raise @types.LoadError::DecodeFailed("block_size 必须为 >=3 的奇数")
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "adaptive_threshold_gaussian_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "adaptive_threshold_gaussian_16 仅支持 channels=1/3/4",
    )
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { 1 }
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let half = block_size / 2
  let sigma = Float::from_int(half) / 2.0F
  let two_sigma_sq = 2.0F * sigma * sigma
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
  let src : Array[Float] = Array::make(n * ch, 0.0F)
  for i in 0..<(n * ch) {
    src[i] = Float::from_int(read_u16_le_c(img.data, i * 2))
  }
  for c_idx in 0..<color_ch {
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
        if v > threshold {
          write_u16_le_c(out, (y * w + x) * bpp + c_idx * 2, 65535)
        }
      }
    }
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
        if v > threshold {
          write_u16_le_c(out, (y * w + x) * bpp + c_idx * 2, 65535)
        }
      }
    }
  }
  if ch == 4 {
    for i in 0..<n {
      let alpha_off = i * bpp + 6
      out[alpha_off] = img.data[alpha_off]
      out[alpha_off + 1] = img.data[alpha_off + 1]
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// float 自适应阈值（高斯加权法）。
pub fn adaptive_threshold_gaussian_f(
  img : @types.ImageF,
  block_size : Int,
  c : Float,
) -> @types.ImageF raise @types.LoadError {
  if block_size < 3 || block_size % 2 == 0 {
    raise @types.LoadError::DecodeFailed("block_size 必须为 >=3 的奇数")
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "adaptive_threshold_gaussian_f 仅支持 channels=1/3/4",
    )
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { 1 }
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  let half = block_size / 2
  let sigma = Float::from_int(half) / 2.0F
  let two_sigma_sq = 2.0F * sigma * sigma
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
  let src : Array[Float] = Array::make(n * ch, 0.0F)
  for i in 0..<(n * ch) {
    src[i] = read_float_le(img.data, i * 4)
  }
  for c_idx in 0..<color_ch {
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
        let threshold = mean - c
        let v = src[(y * w + x) * ch + c_idx]
        if v > threshold {
          write_f32_le(out, (y * w + x) * bpp + c_idx * 4, 1.0F)
        }
      }
    }
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
        let threshold = mean - c
        let v = src[(y * w + x) * ch + c_idx]
        if v > threshold {
          write_f32_le(out, (y * w + x) * bpp + c_idx * 4, 1.0F)
        }
      }
    }
  }
  if ch == 4 {
    for i in 0..<n {
      let alpha_off = i * bpp + 12
      for b in 0..<4 {
        out[alpha_off + b] = img.data[alpha_off + b]
      }
    }
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 16-bit Otsu 大津法自动阈值。使用 65536-bin 直方图。
/// 输出二值图像（0 或 65535）。
pub fn threshold_otsu_16(
  img : @types.Image16,
) -> @types.Image16 raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "threshold_otsu_16: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "threshold_otsu_16 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "threshold_otsu_16: 数据大小不匹配，期望 " +
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
  let bpp = ch * 2
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for c_idx in 0..<color_ch {
    let hist : Array[Int] = Array::make(65536, 0)
    for i in 0..<n {
      hist[read_u16_le_c(img.data, i * bpp + c_idx * 2)] += 1
    }
    let mut total = 0
    let mut sum = 0
    for t in 0..<65536 {
      total += hist[t]
      sum += t * hist[t]
    }
    let mut best_t = 0
    let mut best_var = -1.0F
    let mut w0 = 0
    let mut sum0 = 0
    for t in 0..<65536 {
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
      let v = read_u16_le_c(img.data, i * bpp + c_idx * 2)
      if v > best_t {
        write_u16_le_c(out, i * bpp + c_idx * 2, 65535)
      }
    }
  }
  if ch == 4 {
    for i in 0..<n {
      let alpha_off = i * bpp + 6
      out[alpha_off] = img.data[alpha_off]
      out[alpha_off + 1] = img.data[alpha_off + 1]
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// float Otsu 大津法自动阈值。将值归一化到 0-255 后使用 256-bin 直方图。
/// 输出二值图像（0.0 或 1.0）。
pub fn threshold_otsu_f(
  img : @types.ImageF,
) -> @types.ImageF raise @types.LoadError {
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "threshold_otsu_f 仅支持 channels=1/3/4",
    )
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { 1 }
  let w = img.width
  let h = img.height
  let n = w * h
  let bpp = ch * 4
  let out : Array[Byte] = Array::make(n * bpp, b'\x00')
  for c_idx in 0..<color_ch {
    let hist : Array[Int] = Array::make(256, 0)
    let src : Array[Float] = Array::make(n, 0.0F)
    for i in 0..<n {
      let v = read_float_le(img.data, i * bpp + c_idx * 4)
      src[i] = v
      let bin = if v < 0.0F {
        0
      } else if v >= 1.0F {
        255
      } else {
        (v * 255.0F + 0.5F).to_int()
      }
      hist[bin] += 1
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
    let threshold_f = Float::from_int(best_t) / 255.0F
    for i in 0..<n {
      if src[i] > threshold_f {
        write_f32_le(out, i * bpp + c_idx * 4, 1.0F)
      }
    }
  }
  if ch == 4 {
    for i in 0..<n {
      let alpha_off = i * bpp + 12
      for b in 0..<4 {
        out[alpha_off + b] = img.data[alpha_off + b]
      }
    }
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}
