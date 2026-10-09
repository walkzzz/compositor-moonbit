// 图像统计信息（纯 MoonBit）：mean / stddev / min_max

///|
/// 图像统计结果
pub(all) struct ImageStats {
  mean : Float
  stddev : Float
  min_val : Int
  max_val : Int
} derive(Eq, @debug.Debug)

///|
/// 计算图像统计信息（均值、标准差、最小值、最大值）。
/// 统计所有通道的像素值。
pub fn compute_stats(img : @types.Image) -> ImageStats {
  let n = img.width * img.height * img.channels
  let mut sum = 0
  let mut sum_sq = 0
  let mut min_v = 255
  let mut max_v = 0
  for i in 0..<n {
    let v = img.data[i].to_int()
    sum += v
    sum_sq += v * v
    if v < min_v {
      min_v = v
    }
    if v > max_v {
      max_v = v
    }
  }
  let mean = Float::from_int(sum) / Float::from_int(n)
  let variance = Float::from_int(sum_sq) / Float::from_int(n) - mean * mean
  let stddev = (if variance < 0.0F { 0.0F } else { variance }).sqrt()
  ImageStats::{ mean, stddev, min_val: min_v, max_val: max_v }
}

///|
/// 计算图像均值（所有通道所有像素的平均值）。
pub fn mean_value(img : @types.Image) -> Float {
  let n = img.width * img.height * img.channels
  let mut sum = 0
  for i in 0..<n {
    sum += img.data[i].to_int()
  }
  Float::from_int(sum) / Float::from_int(n)
}

///|
/// 计算图像方差（所有通道所有像素）。
pub fn variance_value(img : @types.Image) -> Float {
  let stats = compute_stats(img)
  stats.stddev * stats.stddev
}

///|
/// 计算图像熵（所有通道所有像素，基于直方图）。
pub fn entropy_value(img : @types.Image) -> Float {
  let n = img.width * img.height * img.channels
  if n == 0 {
    return 0.0F
  }
  // 计算直方图
  let histogram : Array[Int] = Array::make(256, 0)
  for i in 0..<n {
    let v = img.data[i].to_int()
    histogram[v] += 1
  }
  // 计算熵
  let mut entropy = 0.0F
  let n_f = Float::from_int(n)
  for v in 0..<256 {
    if histogram[v] > 0 {
      let p = Float::from_int(histogram[v]) / n_f
      entropy = entropy - p * Float::from_double(@math.log2(p.to_double()))
    }
  }
  entropy
}

///|
/// 计算图像中位数（所有通道所有像素，基于直方图近似）。
pub fn median_value(img : @types.Image) -> Int {
  let n = img.width * img.height * img.channels
  if n == 0 {
    return 0
  }
  // 计算直方图
  let histogram : Array[Int] = Array::make(256, 0)
  for i in 0..<n {
    let v = img.data[i].to_int()
    histogram[v] += 1
  }
  // 计算中位数
  let mut cumulative = 0
  let half = n / 2
  for v in 0..<256 {
    cumulative += histogram[v]
    if cumulative >= half {
      return v
    }
  }
  255
}

///|
/// 计算图像对比度（基于标准差）。
pub fn contrast_value(img : @types.Image) -> Float {
  let stats = compute_stats(img)
  stats.stddev
}

///|
/// 计算图像亮度（基于均值）。
pub fn brightness_value(img : @types.Image) -> Float {
  let stats = compute_stats(img)
  stats.mean
}
