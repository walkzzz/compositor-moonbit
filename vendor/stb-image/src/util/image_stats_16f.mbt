// 图像统计信息 16-bit/float 变体：compute_stats / mean_value
// 支持 Image16 / ImageF 两种类型

///|
fn read_u16_le_s(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
fn read_f32_le_s(data : Bytes, offset : Int) -> Float {
  let b0 = data[offset].to_int()
  let b1 = data[offset + 1].to_int()
  let b2 = data[offset + 2].to_int()
  let b3 = data[offset + 3].to_int()
  let bits = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
  Float::reinterpret_from_int(bits)
}

///|
/// float 图像统计结果
pub(all) struct ImageStatsF {
  mean : Float
  stddev : Float
  min_val : Float
  max_val : Float
} derive(Eq, @debug.Debug)

///|
/// 计算 16-bit 图像统计信息（均值、标准差、最小值、最大值）。
/// 统计所有通道的像素值，像素值范围为 [0, 65535]。
pub fn compute_stats_16(img : @types.Image16) -> ImageStats {
  let n = img.width * img.height * img.channels
  let bpp = 2
  let mut sum = 0
  let mut sum_sq = 0L
  let mut min_v = 65535
  let mut max_v = 0
  for i in 0..<n {
    let v = read_u16_le_s(img.data, i * bpp)
    sum += v
    sum_sq += v.to_int64() * v.to_int64()
    if v < min_v {
      min_v = v
    }
    if v > max_v {
      max_v = v
    }
  }
  let mean = Float::from_int(sum) / Float::from_int(n)
  let variance = Float::from_int64(sum_sq) / Float::from_int(n) - mean * mean
  let stddev = (if variance < 0.0F { 0.0F } else { variance }).sqrt()
  ImageStats::{ mean, stddev, min_val: min_v, max_val: max_v }
}

///|
/// 计算 float 图像统计信息（均值、标准差、最小值、最大值）。
/// 统计所有通道的像素值。
pub fn compute_stats_f(img : @types.ImageF) -> ImageStatsF {
  let n = img.width * img.height * img.channels
  let bpp = 4
  let mut sum = 0.0F
  let mut sum_sq = 0.0F
  let mut min_v = read_f32_le_s(img.data, 0)
  let mut max_v = min_v
  for i in 0..<n {
    let v = read_f32_le_s(img.data, i * bpp)
    sum += v
    sum_sq += v * v
    if v < min_v {
      min_v = v
    }
    if v > max_v {
      max_v = v
    }
  }
  let n_f = Float::from_int(n)
  let mean = sum / n_f
  let variance = sum_sq / n_f - mean * mean
  let stddev = (if variance < 0.0F { 0.0F } else { variance }).sqrt()
  ImageStatsF::{ mean, stddev, min_val: min_v, max_val: max_v }
}

///|
/// 计算 16-bit 图像均值（所有通道所有像素的平均值）。
pub fn mean_value_16(img : @types.Image16) -> Float {
  let n = img.width * img.height * img.channels
  let bpp = 2
  let mut sum = 0
  for i in 0..<n {
    sum += read_u16_le_s(img.data, i * bpp)
  }
  Float::from_int(sum) / Float::from_int(n)
}

///|
/// 计算 float 图像均值（所有通道所有像素的平均值）。
pub fn mean_value_f(img : @types.ImageF) -> Float {
  let n = img.width * img.height * img.channels
  let bpp = 4
  let mut sum = 0.0F
  for i in 0..<n {
    sum += read_f32_le_s(img.data, i * bpp)
  }
  sum / Float::from_int(n)
}
