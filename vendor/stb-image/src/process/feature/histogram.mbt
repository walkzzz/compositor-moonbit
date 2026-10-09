// 直方图操作（纯 MoonBit）：均衡化 + 归一化

///|
/// 计算灰度直方图。返回 256 个 bin 的计数数组。
/// 彩色图像先转灰度（BT.601）再计算。
/// 优化：直接从 Bytes 读取，避免额外数组分配
pub fn histogram(img : @types.Image) -> Array[Int] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("histogram: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "histogram: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "histogram: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let hist : Array[Int] = Array::make(256, 0)
  let n = img.width * img.height
  let ch = img.channels
  let data = img.data
  for i in 0..<n {
    let base = i * ch
    let v = if ch == 1 {
      data[base].to_int()
    } else {
      let r = data[base].to_int()
      let g = data[base + 1].to_int()
      let b = data[base + 2].to_int()
      (r * 299 + g * 587 + b * 114) / 1000
    }
    hist[v] += 1
  }
  hist
}

///|
/// 直方图均衡化。基于灰度直方图计算映射 LUT，应用到所有颜色通道。
/// alpha 通道不变。
pub fn histogram_equalize(
  img : @types.Image,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "histogram_equalize: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "histogram_equalize: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "histogram_equalize: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let hist = histogram(img)
  let n = img.width * img.height
  // 计算 CDF
  let cdf : Array[Int] = Array::make(256, 0)
  let mut cum = 0
  for i in 0..<256 {
    cum += hist[i]
    cdf[i] = cum
  }
  // 找到 CDF_min（第一个非零值）
  let mut cdf_min = 0
  for i in 0..<256 {
    if cdf[i] > 0 {
      cdf_min = cdf[i]
      break
    }
  }
  // 计算映射 LUT
  let lut : Array[Byte] = Array::make(256, b'\x00')
  let denom = n - cdf_min
  if denom <= 0 {
    // 所有像素相同，返回原图
    return img
  }
  for i in 0..<256 {
    let mapped = (cdf[i] - cdf_min) * 255 / denom
    lut[i] = mapped.clamp(min=0, max=255).to_byte()
  }
  // 应用 LUT
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let data_int : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    data_int[i] = img.data[i].to_int()
  }
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      out[i * ch + c] = lut[data_int[i * ch + c]]
    }
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
/// 直方图归一化（线性拉伸）。将像素值范围线性映射到 [0, 255]。
/// alpha 通道不变。
pub fn histogram_normalize(
  img : @types.Image,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "histogram_normalize: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "histogram_normalize: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "histogram_normalize: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let n = img.width * img.height
  let data_int : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    data_int[i] = img.data[i].to_int()
  }
  // 找到颜色通道的最小值和最大值
  let mut min_val = 255
  let mut max_val = 0
  for i in 0..<n {
    for c in 0..<color_ch {
      let v = data_int[i * ch + c]
      if v < min_val {
        min_val = v
      }
      if v > max_val {
        max_val = v
      }
    }
  }
  let range = max_val - min_val
  if range == 0 {
    return img
  }
  // 应用线性拉伸
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  for i in 0..<n {
    for c in 0..<color_ch {
      let v = data_int[i * ch + c]
      let scaled = (v - min_val) * 255 / range
      out[i * ch + c] = scaled.clamp(min=0, max=255).to_byte()
    }
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
/// 直方图比较方法
pub(all) enum HistCompareMethod {
  Correlation // 相关性
  ChiSquare // 卡方
  Bhattacharyya // 巴氏距离
}

///|
/// 比较两个直方图的相似度。返回值越大表示越相似（Correlation/ChiSquare），
/// 或距离越小越相似（Bhattacharyya）。
pub fn compare_hist(
  hist1 : Array[Int],
  hist2 : Array[Int],
  compare_method : HistCompareMethod,
) -> Float raise @types.LoadError {
  // 参数验证
  if hist1.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "compare_hist: hist1数组不能为空",
    )
  }
  if hist2.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "compare_hist: hist2数组不能为空",
    )
  }
  if hist1.length() != hist2.length() {
    raise @types.LoadError::DecodeFailed(
      "compare_hist: hist1和hist2长度必须相同",
    )
  }

  let n = hist1.length()
  match compare_method {
    Correlation => {
      let mut sum1 = 0.0F
      let mut sum2 = 0.0F
      let mut sum12 = 0.0F
      let mut sum1_sq = 0.0F
      let mut sum2_sq = 0.0F
      for i in 0..<n {
        let h1 = Float::from_int(hist1[i])
        let h2 = Float::from_int(hist2[i])
        sum1 += h1
        sum2 += h2
        sum12 += h1 * h2
        sum1_sq += h1 * h1
        sum2_sq += h2 * h2
      }
      let nf = Float::from_int(n)
      let num = nf * sum12 - sum1 * sum2
      let den = ((nf * sum1_sq - sum1 * sum1) * (nf * sum2_sq - sum2 * sum2)).sqrt()
      if den == 0.0F {
        0.0F
      } else {
        num / den
      }
    }
    ChiSquare => {
      let mut chi = 0.0F
      for i in 0..<n {
        let h1 = Float::from_int(hist1[i])
        let h2 = Float::from_int(hist2[i])
        let diff = h1 - h2
        let sum = h1 + h2
        if sum > 0.0F {
          chi += diff * diff / sum
        }
      }
      chi
    }
    Bhattacharyya => {
      let mut bc = 0.0F
      let mut s1 = 0.0F
      let mut s2 = 0.0F
      for i in 0..<n {
        let h1 = Float::from_int(hist1[i])
        let h2 = Float::from_int(hist2[i])
        bc += (h1 * h2).sqrt()
        s1 += h1
        s2 += h2
      }
      if s1 > 0.0F && s2 > 0.0F {
        bc / (s1 * s2).sqrt()
      } else {
        0.0F
      }
    }
  }
}

///|
/// 直方图匹配（规定化）。将输入图像的直方图匹配到参考图像的直方图，
/// 通过构建 LUT 实现灰度值映射。彩色图像对每个通道独立匹配。
pub fn histogram_matching(
  img : @types.Image,
  reference : @types.Image,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "histogram_matching: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "histogram_matching: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "histogram_matching: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if reference.width <= 0 || reference.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "histogram_matching: 参考图像尺寸必须大于0",
    )
  }
  if reference.channels < 1 || reference.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "histogram_matching: 参考图像通道数必须在1-4之间",
    )
  }
  let ref_expected_size = reference.width *
    reference.height *
    reference.channels
  if reference.data.length() != ref_expected_size {
    raise @types.LoadError::DecodeFailed(
      "histogram_matching: 参考图像数据大小不匹配，期望 " +
      ref_expected_size.to_string() +
      "，实际 " +
      reference.data.length().to_string(),
    )
  }

  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { ch }
  let n = img.width * img.height
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  for c in 0..<color_ch {
    let hist_in : Array[Int] = Array::make(256, 0)
    let hist_ref : Array[Int] = Array::make(256, 0)
    for i in 0..<n {
      hist_in[img.data[i * ch + c].to_int()] += 1
    }
    let n_ref = reference.width * reference.height
    let ref_ch = reference.channels
    let ref_color_ch = if ref_ch >= 3 { 3 } else { ref_ch }
    if c < ref_color_ch {
      for i in 0..<n_ref {
        hist_ref[reference.data[i * ref_ch + c].to_int()] += 1
      }
    }
    let cdf_in : Array[Float] = Array::make(256, 0.0F)
    let cdf_ref : Array[Float] = Array::make(256, 0.0F)
    let mut cum_in = 0
    let mut cum_ref = 0
    for i in 0..<256 {
      cum_in += hist_in[i]
      cdf_in[i] = Float::from_int(cum_in) / Float::from_int(n)
      cum_ref += hist_ref[i]
      cdf_ref[i] = Float::from_int(cum_ref) / Float::from_int(n_ref)
    }
    let lut : Array[Byte] = Array::make(256, b'\x00')
    for i in 0..<256 {
      let target = cdf_in[i]
      let mut best_j = 0
      let mut best_diff = 1.0F
      for j in 0..<256 {
        let diff = (cdf_ref[j] - target).abs()
        if diff < best_diff {
          best_diff = diff
          best_j = j
        }
      }
      lut[i] = best_j.to_byte()
    }
    for i in 0..<n {
      out[i * ch + c] = lut[img.data[i * ch + c].to_int()]
    }
  }
  if ch == 4 {
    for i in 0..<n {
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
