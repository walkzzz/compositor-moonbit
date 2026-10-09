// 文档图像增强
// 文档增强、阴影去除、背景归一化

///|
/// 辅助函数：限制字节范围
fn clamp_byte_doc(v : Int) -> Byte {
  if v < 0 {
    b'\x00'
  } else if v > 255 {
    b'\xFF'
  } else {
    v.to_byte()
  }
}

///|
/// 文档图像增强（去噪+对比度+锐化）
/// 适用于扫描文档和照片文档的预处理
pub fn document_enhance(
  img : @types.Image,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "document_enhance: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "document_enhance: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "document_enhance: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let mut result = img
  // 1. 转灰度（如果是彩色图像）
  if result.channels != 1 {
    result = to_grayscale_doc(result)
  }
  // 2. 对比度增强（拉伸直方图）
  result = contrast_stretch_doc(result)
  // 3. 轻度去噪（中值滤波）
  result = median_denoise_doc(result, 3)
  // 4. 锐化（增强文字边缘）
  result = sharpen_doc(result, 0.5)
  result
}

///|
/// 转灰度（文档专用，BT.601）
fn to_grayscale_doc(img : @types.Image) -> @types.Image {
  if img.channels == 1 {
    return img
  }
  let n = img.width * img.height
  let ch = img.channels
  let out : Array[Byte] = Array::make(n, b'\x00')
  let data = img.data
  for i in 0..<n {
    let base = i * ch
    let r = data[base].to_int()
    let g = data[base + 1].to_int()
    let b = data[base + 2].to_int()
    let gray = (r * 299 + g * 587 + b * 114) / 1000
    out[i] = gray.to_byte()
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// 对比度拉伸（文档专用）
fn contrast_stretch_doc(img : @types.Image) -> @types.Image {
  let n = img.width * img.height
  let data = img.data
  // 计算最小和最大值（忽略 1% 极值）
  let histogram : Array[Int] = Array::make(256, 0)
  for i in 0..<n {
    histogram[data[i].to_int()] += 1
  }
  let cutoff = n / 100
  let mut count = 0
  let mut min_val = 0
  for i in 0..<256 {
    count += histogram[i]
    if count >= cutoff {
      min_val = i
      break
    }
  }
  count = 0
  let mut max_val = 255
  for i in 0..<256 {
    count += histogram[255 - i]
    if count >= cutoff {
      max_val = 255 - i
      break
    }
  }
  // 应用拉伸
  let range = if max_val > min_val { max_val - min_val } else { 1 }
  let out : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    let v = data[i].to_int()
    let stretched = (v - min_val) * 255 / range
    out[i] = clamp_byte_doc(stretched)
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// 中值去噪（文档专用，3x3 窗口）
fn median_denoise_doc(img : @types.Image, size : Int) -> @types.Image {
  let w = img.width
  let h = img.height
  let radius = size / 2
  let data = img.data
  let out : Array[Byte] = Array::make(w * h, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      let values : Array[Int] = []
      for dy in -radius..<(radius + 1) {
        for dx in -radius..<(radius + 1) {
          let nx = x + dx
          let ny = y + dy
          if nx >= 0 && nx < w && ny >= 0 && ny < h {
            values.push(data[ny * w + nx].to_int())
          }
        }
      }
      // 简单排序取中值
      for i in 0..<values.length() {
        for j in (i + 1)..<values.length() {
          if values[j] < values[i] {
            let tmp = values[i]
            values[i] = values[j]
            values[j] = tmp
          }
        }
      }
      let median = values[values.length() / 2]
      out[y * w + x] = median.to_byte()
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
/// 锐化（文档专用，USM 简化版）
fn sharpen_doc(img : @types.Image, amount : Double) -> @types.Image {
  let w = img.width
  let h = img.height
  let data = img.data
  let out : Array[Byte] = Array::make(w * h, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      let center = data[y * w + x].to_int().to_double()
      // 计算邻域均值
      let mut sum = 0.0
      let mut count = 0
      for dy in -1..<2 {
        for dx in -1..<2 {
          let nx = x + dx
          let ny = y + dy
          if nx >= 0 && nx < w && ny >= 0 && ny < h {
            sum += data[ny * w + nx].to_int().to_double()
            count += 1
          }
        }
      }
      let mean = sum / count.to_double()
      // USM: result = center + amount * (center - mean)
      let sharpened = center + amount * (center - mean)
      out[y * w + x] = clamp_byte_doc(sharpened.to_int())
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
/// 阴影去除（基于大核高斯模糊的背景估计）
/// 通过估计背景光照并去除，实现阴影去除
pub fn shadow_removal(
  img : @types.Image,
  kernel_size? : Int = 51,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "shadow_removal: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "shadow_removal: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "shadow_removal: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if kernel_size <= 0 || kernel_size % 2 == 0 {
    raise @types.LoadError::DecodeFailed(
      "shadow_removal: 核大小必须为正奇数",
    )
  }
  let w = img.width
  let h = img.height
  let data = img.data
  // 估计背景（大核均值模糊）
  let radius = kernel_size / 2
  let background : Array[Int] = Array::make(w * h, 0)
  for y in 0..<h {
    for x in 0..<w {
      let mut sum = 0
      let mut count = 0
      for dy in -radius..<(radius + 1) {
        for dx in -radius..<(radius + 1) {
          let nx = x + dx
          let ny = y + dy
          if nx >= 0 && nx < w && ny >= 0 && ny < h {
            sum += data[ny * w + nx].to_int()
            count += 1
          }
        }
      }
      background[y * w + x] = sum / count
    }
  }
  // 去除阴影：result = (original / background) * 255
  let out : Array[Byte] = Array::make(w * h, b'\x00')
  for i in 0..<(w * h) {
    let orig = data[i].to_int()
    let bg = background[i]
    let result = if bg > 0 { orig * 255 / bg } else { 255 }
    out[i] = clamp_byte_doc(result)
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// 背景归一化（将背景统一为白色）
/// 适用于背景不均匀的文档图像
pub fn background_normalization(
  img : @types.Image,
  kernel_size? : Int = 31,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "background_normalization: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "background_normalization: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "background_normalization: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if kernel_size <= 0 || kernel_size % 2 == 0 {
    raise @types.LoadError::DecodeFailed(
      "background_normalization: 核大小必须为正奇数",
    )
  }
  let w = img.width
  let h = img.height
  let data = img.data
  // 估计背景（大核中值模糊）
  let radius = kernel_size / 2
  let background : Array[Int] = Array::make(w * h, 0)
  for y in 0..<h {
    for x in 0..<w {
      let values : Array[Int] = []
      for dy in -radius..<(radius + 1) {
        for dx in -radius..<(radius + 1) {
          let nx = x + dx
          let ny = y + dy
          if nx >= 0 && nx < w && ny >= 0 && ny < h {
            values.push(data[ny * w + nx].to_int())
          }
        }
      }
      // 取最大值作为背景估计（文字是暗的，背景是亮的）
      let mut max_val = 0
      for v in values {
        if v > max_val {
          max_val = v
        }
      }
      background[y * w + x] = max_val
    }
  }
  // 归一化：result = original * (255 / background)
  let out : Array[Byte] = Array::make(w * h, b'\x00')
  for i in 0..<(w * h) {
    let orig = data[i].to_int()
    let bg = background[i]
    let result = if bg > 0 { orig * 255 / bg } else { 255 }
    out[i] = clamp_byte_doc(result)
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out),
  }
}
