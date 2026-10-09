// OCR 专用二值化算法
// Sauvola 阈值、Niblack 阈值、OCR 自适应阈值

///|
/// 辅助函数：限制字节范围
fn _clamp_byte_ocr(v : Int) -> Byte {
  if v < 0 {
    b'\x00'
  } else if v > 255 {
    b'\xFF'
  } else {
    v.to_byte()
  }
}

///|
/// 辅助函数：计算局部窗口的均值和标准差
fn local_mean_std(
  data : Array[Int],
  width : Int,
  height : Int,
  x : Int,
  y : Int,
  radius : Int,
) -> (Double, Double) {
  let mut sum = 0.0
  let mut sum_sq = 0.0
  let mut count = 0
  for dy in -radius..<(radius + 1) {
    for dx in -radius..<(radius + 1) {
      let nx = x + dx
      let ny = y + dy
      if nx >= 0 && nx < width && ny >= 0 && ny < height {
        let v = data[ny * width + nx].to_double()
        sum += v
        sum_sq += v * v
        count += 1
      }
    }
  }
  if count == 0 {
    return (0.0, 0.0)
  }
  let mean = sum / count.to_double()
  let variance = sum_sq / count.to_double() - mean * mean
  let std = if variance < 0.0 { 0.0 } else { variance.sqrt() }
  (mean, std)
}

///|
/// Niblack 局部阈值二值化
/// T(x,y) = mean(x,y) + k * std(x,y)
/// k: 修正系数，通常 -0.2
/// window_size: 局部窗口大小（奇数）
pub fn niblack_threshold(
  img : @types.Image,
  window_size? : Int = 15,
  k? : Double = -0.2,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "niblack_threshold: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "niblack_threshold: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "niblack_threshold: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if window_size <= 0 || window_size % 2 == 0 {
    raise @types.LoadError::DecodeFailed(
      "niblack_threshold: window_size必须为正奇数",
    )
  }

  let w = img.width
  let h = img.height
  let radius = window_size / 2
  // 转换为 Int 数组
  let data : Array[Int] = Array::make(w * h, 0)
  for i in 0..<(w * h) {
    data[i] = img.data[i].to_int()
  }
  let out : Array[Byte] = Array::make(w * h, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      let (mean, std) = local_mean_std(data, w, h, x, y, radius)
      let threshold = mean + k * std
      let v = data[y * w + x].to_double()
      out[y * w + x] = if v > threshold { b'\xFF' } else { b'\x00' }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// Sauvola 局部阈值二值化（Niblack 的改进版，适合文档图像）
/// T(x,y) = mean(x,y) * (1 + k * (std(x,y)/R - 1))
/// k: 修正系数，通常 0.5
/// R: 标准差的动态范围，通常 128
/// window_size: 局部窗口大小（奇数）
pub fn sauvola_threshold(
  img : @types.Image,
  window_size? : Int = 15,
  k? : Double = 0.5,
  r? : Double = 128.0,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "sauvola_threshold: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "sauvola_threshold: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "sauvola_threshold: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if window_size <= 0 || window_size % 2 == 0 {
    raise @types.LoadError::DecodeFailed(
      "sauvola_threshold: window_size必须为正奇数",
    )
  }
  if r <= 0.0 {
    raise @types.LoadError::DecodeFailed("sauvola_threshold: r必须大于0")
  }

  let w = img.width
  let h = img.height
  let radius = window_size / 2
  // 转换为 Int 数组
  let data : Array[Int] = Array::make(w * h, 0)
  for i in 0..<(w * h) {
    data[i] = img.data[i].to_int()
  }
  let out : Array[Byte] = Array::make(w * h, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      let (mean, std) = local_mean_std(data, w, h, x, y, radius)
      let threshold = mean * (1.0 + k * (std / r - 1.0))
      let v = data[y * w + x].to_double()
      out[y * w + x] = if v > threshold { b'\xFF' } else { b'\x00' }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// OCR 专用自适应阈值（结合全局阈值和局部阈值）
/// 适用于光照不均匀的文档图像
pub fn adaptive_threshold_ocr(
  img : @types.Image,
  block_size? : Int = 15,
  c? : Int = 10,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "adaptive_threshold_ocr: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "adaptive_threshold_ocr: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "adaptive_threshold_ocr: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if block_size <= 0 || block_size % 2 == 0 {
    raise @types.LoadError::DecodeFailed(
      "adaptive_threshold_ocr: block_size必须为正奇数",
    )
  }

  let w = img.width
  let h = img.height
  let radius = block_size / 2
  // 转换为 Int 数组
  let data : Array[Int] = Array::make(w * h, 0)
  for i in 0..<(w * h) {
    data[i] = img.data[i].to_int()
  }
  let out : Array[Byte] = Array::make(w * h, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      // 计算局部均值
      let (mean, _) = local_mean_std(data, w, h, x, y, radius)
      let threshold = mean - c.to_double()
      let v = data[y * w + x].to_double()
      out[y * w + x] = if v > threshold { b'\xFF' } else { b'\x00' }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// Otsu 全局阈值二值化（自动计算最佳阈值）
pub fn otsu_threshold(
  img : @types.Image,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "otsu_threshold: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "otsu_threshold: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "otsu_threshold: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let w = img.width
  let h = img.height
  let n = w * h
  // 计算直方图
  let histogram : Array[Int] = Array::make(256, 0)
  for i in 0..<n {
    histogram[img.data[i].to_int()] += 1
  }
  // 计算 Otsu 最佳阈值
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
    let w_f = n - w_b
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
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    out[i] = if img.data[i].to_int() > threshold { b'\xFF' } else { b'\x00' }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out),
  }
}
