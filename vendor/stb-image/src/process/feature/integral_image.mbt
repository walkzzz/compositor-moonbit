// 积分图像（纯 MoonBit）

///|
/// 积分图像（Satoh 表达）。integral[y][x] = sum of img[0..y, 0..x]。
/// 支持 64 位整数和 Float 两种表达。
pub struct IntegralImage {
  width : Int // 原图宽度
  height : Int // 原图高度
  data : Array[Int64] // (width+1) * (height+1) 的积分表，首行首列为 0
}

///|
/// 计算积分图像。仅处理灰度图（channels=1）或 RGB 图（channels=3/4，取首通道）。
pub fn integral_image(
  img : @types.Image,
) -> IntegralImage raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "integral_image: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "integral_image: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "integral_image: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let w = img.width
  let h = img.height
  let ch = img.channels
  let iw = w + 1
  let ih = h + 1
  let data_int : Array[Int] = Array::make(w * h * ch, 0)
  for i in 0..<(w * h * ch) {
    data_int[i] = img.data[i].to_int()
  }
  let data : Array[Int64] = Array::make(iw * ih, 0L)
  for y in 0..<h {
    let mut row_sum = 0L
    for x in 0..<w {
      row_sum += Int64::from_int(data_int[(y * w + x) * ch])
      data[(y + 1) * iw + x + 1] = data[y * iw + x + 1] + row_sum
    }
  }
  IntegralImage::{ width: w, height: h, data }
}

///|
/// 查询积分图像中矩形区域 [x, x+w) × [y, y+h) 的像素和。
pub fn integral_sum(
  integral : IntegralImage,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> Int64 raise @types.LoadError {
  // 参数验证
  if integral.width <= 0 || integral.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "integral_sum: 积分图像尺寸必须大于0",
    )
  }
  if x < 0 || y < 0 {
    raise @types.LoadError::DecodeFailed("integral_sum: x和y必须 >= 0")
  }
  if w <= 0 || h <= 0 {
    raise @types.LoadError::DecodeFailed("integral_sum: w和h必须大于0")
  }
  if x + w > integral.width || y + h > integral.height {
    raise @types.LoadError::DecodeFailed(
      "integral_sum: 矩形区域超出图像边界",
    )
  }

  let iw = integral.width + 1
  let x2 = x + w
  let y2 = y + h
  let p00 = integral.data[y * iw + x]
  let p10 = integral.data[y * iw + x2]
  let p01 = integral.data[y2 * iw + x]
  let p11 = integral.data[y2 * iw + x2]
  p11 - p10 - p01 + p00
}

///|
/// 使用积分图像快速计算矩形区域均值。
pub fn integral_mean(
  integral : IntegralImage,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> Float raise @types.LoadError {
  // 参数验证
  if integral.width <= 0 || integral.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "integral_mean: 积分图像尺寸必须大于0",
    )
  }
  if x < 0 || y < 0 {
    raise @types.LoadError::DecodeFailed("integral_mean: x和y必须 >= 0")
  }
  if w < 0 || h < 0 {
    raise @types.LoadError::DecodeFailed("integral_mean: w和h必须 >= 0")
  }
  if w == 0 || h == 0 {
    return 0.0F
  }
  if x + w > integral.width || y + h > integral.height {
    raise @types.LoadError::DecodeFailed(
      "integral_mean: 矩形区域超出图像边界",
    )
  }

  let sum = integral_sum(integral, x, y, w, h)
  Float::from_int(sum.to_int()) / Float::from_int(w * h)
}

///|
/// 平方积分图像（用于快速计算方差）。
pub struct IntegralImageSq {
  width : Int
  height : Int
  data : Array[Int64] // sum of img^2
}

///|
/// 计算平方积分图像。
pub fn integral_image_sq(
  img : @types.Image,
) -> IntegralImageSq raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "integral_image_sq: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "integral_image_sq: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "integral_image_sq: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let w = img.width
  let h = img.height
  let ch = img.channels
  let iw = w + 1
  let ih = h + 1
  let data_int : Array[Int] = Array::make(w * h * ch, 0)
  for i in 0..<(w * h * ch) {
    data_int[i] = img.data[i].to_int()
  }
  let data : Array[Int64] = Array::make(iw * ih, 0L)
  for y in 0..<h {
    let mut row_sum = 0L
    for x in 0..<w {
      let v = Int64::from_int(data_int[(y * w + x) * ch])
      row_sum += v * v
      data[(y + 1) * iw + x + 1] = data[y * iw + x + 1] + row_sum
    }
  }
  IntegralImageSq::{ width: w, height: h, data }
}

///|
/// 使用积分图像计算矩形区域方差。
/// 需要同时提供积分图像和平方积分图像。
pub fn integral_variance(
  integral : IntegralImage,
  integral_sq : IntegralImageSq,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> Float raise @types.LoadError {
  // 参数验证
  if integral.width <= 0 || integral.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "integral_variance: 积分图像尺寸必须大于0",
    )
  }
  if integral_sq.width <= 0 || integral_sq.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "integral_variance: 平方积分图像尺寸必须大于0",
    )
  }
  if integral.width != integral_sq.width ||
    integral.height != integral_sq.height {
    raise @types.LoadError::DecodeFailed(
      "integral_variance: 积分图像和平方积分图像尺寸必须相同",
    )
  }
  if x < 0 || y < 0 {
    raise @types.LoadError::DecodeFailed("integral_variance: x和y必须 >= 0")
  }
  if w <= 0 || h <= 0 {
    raise @types.LoadError::DecodeFailed(
      "integral_variance: w和h必须大于0",
    )
  }
  if x + w > integral.width || y + h > integral.height {
    raise @types.LoadError::DecodeFailed(
      "integral_variance: 矩形区域超出图像边界",
    )
  }

  let n = Float::from_int(w * h)
  let sum = Float::from_int(integral_sum(integral, x, y, w, h).to_int())
  let sum_sq = Float::from_int(
    integral_sum_sq(integral_sq, x, y, w, h).to_int(),
  )
  let mean = sum / n
  sum_sq / n - mean * mean
}

///|
/// 查询平方积分图像中矩形区域的像素平方和。
pub fn integral_sum_sq(
  integral_sq : IntegralImageSq,
  x : Int,
  y : Int,
  w : Int,
  h : Int,
) -> Int64 raise @types.LoadError {
  // 参数验证
  if integral_sq.width <= 0 || integral_sq.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "integral_sum_sq: 平方积分图像尺寸必须大于0",
    )
  }
  if x < 0 || y < 0 {
    raise @types.LoadError::DecodeFailed("integral_sum_sq: x和y必须 >= 0")
  }
  if w <= 0 || h <= 0 {
    raise @types.LoadError::DecodeFailed("integral_sum_sq: w和h必须大于0")
  }
  if x + w > integral_sq.width || y + h > integral_sq.height {
    raise @types.LoadError::DecodeFailed(
      "integral_sum_sq: 矩形区域超出图像边界",
    )
  }

  let iw = integral_sq.width + 1
  let x2 = x + w
  let y2 = y + h
  let p00 = integral_sq.data[y * iw + x]
  let p10 = integral_sq.data[y * iw + x2]
  let p01 = integral_sq.data[y2 * iw + x]
  let p11 = integral_sq.data[y2 * iw + x2]
  p11 - p10 - p01 + p00
}
