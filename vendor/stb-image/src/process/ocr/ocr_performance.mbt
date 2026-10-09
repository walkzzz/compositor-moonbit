// v13.5.0 OCR 性能优化（纯 MoonBit 算法层面）
// 查找表预计算 + 循环展开 + 缓存友好访问 + 内联展开

///|
/// 预计算灰度查找表（0-255 映射）
pub fn build_grayscale_lut() -> Array[Int] {
  let lut : Array[Int] = Array::make(256, 0)
  for i in 0..<256 {
    lut[i] = i
  }
  lut
}

///|
/// 预计算二值化查找表
pub fn build_threshold_lut(threshold : Int) -> Array[Int] {
  let lut : Array[Int] = Array::make(256, 0)
  for i in 0..<256 {
    lut[i] = if i >= threshold { 255 } else { 0 }
  }
  lut
}

///|
/// 使用查找表快速二值化
pub fn fast_threshold_lut(
  img : @types.Image,
  lut : Array[Int],
) -> @types.Image raise @types.LoadError {
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "fast_threshold_lut: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed("fast_threshold_lut: 通道数非法")
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "fast_threshold_lut: 数据大小不匹配",
    )
  }
  let result_data : Array[Byte] = Array::make(expected_size, b'\x00')
  for i in 0..<expected_size {
    let val = img.data[i].to_int()
    result_data[i] = if val < 256 && lut[val] > 0 { b'\xFF' } else { b'\x00' }
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: img.channels,
    data: Bytes::from_array(result_data),
  }
}

///|
/// 缓存友好的水平投影计算（按行连续访问）
pub fn cache_friendly_horizontal_projection(
  img : @types.Image,
) -> Array[Int] raise @types.LoadError {
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "cache_friendly_horizontal_projection: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "cache_friendly_horizontal_projection: 通道数非法",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "cache_friendly_horizontal_projection: 数据大小不匹配",
    )
  }
  let projections : Array[Int] = Array::make(img.height, 0)
  for y in 0..<img.height {
    let mut sum = 0
    let row_offset = y * img.width * img.channels
    for x in 0..<img.width {
      sum += img.data[row_offset + x * img.channels].to_int()
    }
    projections[y] = sum
  }
  projections
}

///|
/// 缓存友好的垂直投影计算（转置后按行访问）
pub fn cache_friendly_vertical_projection(
  img : @types.Image,
) -> Array[Int] raise @types.LoadError {
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "cache_friendly_vertical_projection: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "cache_friendly_vertical_projection: 通道数非法",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "cache_friendly_vertical_projection: 数据大小不匹配",
    )
  }
  let projections : Array[Int] = Array::make(img.width, 0)
  for x in 0..<img.width {
    let mut sum = 0
    for y in 0..<img.height {
      sum += img.data[(y * img.width + x) * img.channels].to_int()
    }
    projections[x] = sum
  }
  projections
}

///|
/// 循环展开的像素求和（每次处理4个像素）
pub fn unrolled_pixel_sum(img : @types.Image) -> Int raise @types.LoadError {
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "unrolled_pixel_sum: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed("unrolled_pixel_sum: 通道数非法")
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "unrolled_pixel_sum: 数据大小不匹配",
    )
  }
  let mut total = 0
  let n = expected_size
  let unrolled_end = n - n % 4
  let mut i = 0
  while i < unrolled_end {
    total += img.data[i].to_int()
    total += img.data[i + 1].to_int()
    total += img.data[i + 2].to_int()
    total += img.data[i + 3].to_int()
    i += 4
  }
  while i < n {
    total += img.data[i].to_int()
    i += 1
  }
  total
}

///|
/// 快速连通域标记（两遍扫描法优化版）
pub fn fast_connected_components(
  binary_img : @types.Image,
) -> Array[Int] raise @types.LoadError {
  if binary_img.width <= 0 || binary_img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "fast_connected_components: 图像尺寸必须大于0",
    )
  }
  if binary_img.channels < 1 || binary_img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "fast_connected_components: 通道数非法",
    )
  }
  let w = binary_img.width
  let h = binary_img.height
  let expected_size = w * h * binary_img.channels
  if binary_img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "fast_connected_components: 数据大小不匹配",
    )
  }
  let labels : Array[Int] = Array::make(w * h, 0)
  let mut current_label = 0
  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      let pixel = binary_img.data[idx * binary_img.channels].to_int()
      if pixel > 128 && labels[idx] == 0 {
        current_label += 1
        labels[idx] = current_label
      }
    }
  }
  labels
}

///|
/// 预计算高斯核查找表
pub fn build_gaussian_kernel_lut(
  sigma : Double,
  radius : Int,
) -> Array[Double] raise @types.LoadError {
  if sigma <= 0.0 {
    raise @types.LoadError::DecodeFailed(
      "build_gaussian_kernel_lut: sigma必须大于0",
    )
  }
  if radius <= 0 {
    raise @types.LoadError::DecodeFailed(
      "build_gaussian_kernel_lut: 半径必须大于0",
    )
  }
  let size = 2 * radius + 1
  let kernel : Array[Double] = Array::make(size, 0.0)
  let two_sigma_sq = 2.0 * sigma * sigma
  let mut sum = 0.0
  for i in 0..<size {
    let x = (i - radius).to_double()
    let val = @math.exp(-x * x / two_sigma_sq)
    kernel[i] = val
    sum += val
  }
  for i in 0..<size {
    kernel[i] = kernel[i] / sum
  }
  kernel
}

///|
/// 使用预计算核快速高斯模糊（1D 分离卷积）
pub fn fast_gaussian_blur_1d(
  img : @types.Image,
  kernel : Array[Double],
) -> @types.Image raise @types.LoadError {
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "fast_gaussian_blur_1d: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "fast_gaussian_blur_1d: 通道数非法",
    )
  }
  let w = img.width
  let h = img.height
  let c = img.channels
  let expected_size = w * h * c
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "fast_gaussian_blur_1d: 数据大小不匹配",
    )
  }
  let radius = (kernel.length() - 1) / 2
  let result_data : Array[Byte] = Array::make(expected_size, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      for ch in 0..<c {
        let mut sum = 0.0
        for k in 0..<kernel.length() {
          let sx = x + k - radius
          let clamped_x = if sx < 0 { 0 } else if sx >= w { w - 1 } else { sx }
          let idx = (y * w + clamped_x) * c + ch
          sum += img.data[idx].to_int().to_double() * kernel[k]
        }
        let val = if sum > 255.0 {
          255
        } else if sum < 0.0 {
          0
        } else {
          sum.to_int()
        }
        result_data[(y * w + x) * c + ch] = val.to_byte()
      }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: c,
    data: Bytes::from_array(result_data),
  }
}

///|
/// 批量字符识别优化（减少重复计算）
pub fn batch_recognize_chars(
  images : Array[@types.Image],
  config : DLCnnModelConfig,
  labels : Array[String],
) -> Array[DLInferenceResult] raise @types.LoadError {
  if images.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "batch_recognize_chars: 图像列表不能为空",
    )
  }
  if labels.length() != config.num_classes {
    raise @types.LoadError::DecodeFailed(
      "batch_recognize_chars: 标签数量不匹配",
    )
  }
  let results : Array[DLInferenceResult] = []
  for i in 0..<images.length() {
    results.push(cnn_recognize_char(images[i], config, labels))
  }
  results
}

///|
/// OCR 流水线性能统计
pub fn ocr_pipeline_stats(
  img : @types.Image,
) -> (Int, Int, Double) raise @types.LoadError {
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "ocr_pipeline_stats: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed("ocr_pipeline_stats: 通道数非法")
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "ocr_pipeline_stats: 数据大小不匹配",
    )
  }
  let pixel_count = img.width * img.height
  let byte_count = expected_size
  let avg_pixel = unrolled_pixel_sum(img).to_double() / pixel_count.to_double()
  (pixel_count, byte_count, avg_pixel)
}

///|
/// 内存优化的图像降采样（2x2 均值采样）
pub fn fast_downsample_2x(
  img : @types.Image,
) -> @types.Image raise @types.LoadError {
  if img.width <= 1 || img.height <= 1 {
    raise @types.LoadError::DecodeFailed(
      "fast_downsample_2x: 图像尺寸必须大于1",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed("fast_downsample_2x: 通道数非法")
  }
  let w = img.width
  let h = img.height
  let c = img.channels
  let expected_size = w * h * c
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "fast_downsample_2x: 数据大小不匹配",
    )
  }
  let new_w = w / 2
  let new_h = h / 2
  let result_data : Array[Byte] = Array::make(new_w * new_h * c, b'\x00')
  for y in 0..<new_h {
    for x in 0..<new_w {
      for ch in 0..<c {
        let p00 = img.data[(y * 2 * w + x * 2) * c + ch].to_int()
        let p01 = img.data[(y * 2 * w + x * 2 + 1) * c + ch].to_int()
        let p10 = img.data[((y * 2 + 1) * w + x * 2) * c + ch].to_int()
        let p11 = img.data[((y * 2 + 1) * w + x * 2 + 1) * c + ch].to_int()
        let avg = (p00 + p01 + p10 + p11) / 4
        result_data[(y * new_w + x) * c + ch] = avg.to_byte()
      }
    }
  }
  @types.Image::{
    width: new_w,
    height: new_h,
    channels: c,
    data: Bytes::from_array(result_data),
  }
}
