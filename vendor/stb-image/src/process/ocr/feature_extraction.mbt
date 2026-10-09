// 特征提取
// HOG、LBP、投影特征、网格特征、统计特征

///|
/// HOG 特征描述子
pub(all) struct HogFeatures {
  features : Array[Double]
  cell_size : Int
  num_bins : Int
  width : Int
  height : Int
}

///|
/// LBP 特征描述子
pub(all) struct LbpFeatures {
  features : Array[Double]
  num_bins : Int
  radius : Int
  num_points : Int
}

///|
/// 投影特征
pub(all) struct ProjectionFeatures {
  horizontal : Array[Double]
  vertical : Array[Double]
  horizontal_mean : Double
  horizontal_std : Double
  vertical_mean : Double
  vertical_std : Double
}

///|
/// 网格特征
pub(all) struct GridFeatures {
  features : Array[Double]
  grid_rows : Int
  grid_cols : Int
}

///|
/// 统计特征
pub(all) struct StatisticalFeatures {
  mean : Double
  std : Double
  skewness : Double
  kurtosis : Double
  entropy : Double
  energy : Double
  contrast : Double
  homogeneity : Double
}

///|
/// 计算 HOG 特征（方向梯度直方图）
pub fn hog_features(
  img : @types.Image,
  cell_size? : Int = 8,
  num_bins? : Int = 9,
) -> HogFeatures raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "hog_features: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "hog_features: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "hog_features: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if cell_size <= 0 {
    raise @types.LoadError::DecodeFailed("hog_features: cell_size必须大于0")
  }
  if num_bins <= 0 {
    raise @types.LoadError::DecodeFailed("hog_features: num_bins必须大于0")
  }

  let w = img.width
  let h = img.height
  let data = img.data
  // 计算梯度
  let grad_x : Array[Double] = Array::make(w * h, 0.0)
  let grad_y : Array[Double] = Array::make(w * h, 0.0)
  let magnitude : Array[Double] = Array::make(w * h, 0.0)
  let orientation : Array[Double] = Array::make(w * h, 0.0)
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let gx = data[y * w + (x + 1)].to_int() - data[y * w + (x - 1)].to_int()
      let gy = data[(y + 1) * w + x].to_int() - data[(y - 1) * w + x].to_int()
      grad_x[y * w + x] = gx.to_double()
      grad_y[y * w + x] = gy.to_double()
      magnitude[y * w + x] = (gx.to_double() * gx.to_double() +
      gy.to_double() * gy.to_double()).sqrt()
      let mut angle = @math.atan2(gy.to_double(), gx.to_double()) *
        180.0 /
        3.141592653589793
      if angle < 0.0 {
        angle += 180.0
      }
      orientation[y * w + x] = angle
    }
  }
  // 计算每个 cell 的直方图
  let cells_x = w / cell_size
  let cells_y = h / cell_size
  let features : Array[Double] = []
  for cy in 0..<cells_y {
    for cx in 0..<cells_x {
      let hist : Array[Double] = Array::make(num_bins, 0.0)
      for y in 0..<cell_size {
        for x in 0..<cell_size {
          let px = cx * cell_size + x
          let py = cy * cell_size + y
          if px < w && py < h {
            let mag = magnitude[py * w + px]
            let angle = orientation[py * w + px]
            let bin = (angle / (180.0 / num_bins.to_double())).to_int()
            let bin_idx = if bin >= num_bins { num_bins - 1 } else { bin }
            hist[bin_idx] += mag
          }
        }
      }
      // L2 归一化
      let mut sum_sq = 0.0
      for i in 0..<num_bins {
        sum_sq += hist[i] * hist[i]
      }
      let norm = if sum_sq > 0.0 { sum_sq.sqrt() } else { 1.0 }
      for i in 0..<num_bins {
        features.push(hist[i] / norm)
      }
    }
  }
  HogFeatures::{
    features,
    cell_size,
    num_bins,
    width: cells_x,
    height: cells_y,
  }
}

///|
/// 计算 LBP 特征（局部二值模式）
pub fn lbp_features(
  img : @types.Image,
  radius? : Int = 1,
  num_points? : Int = 8,
  num_bins? : Int = 256,
) -> LbpFeatures raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "lbp_features: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "lbp_features: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "lbp_features: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if radius <= 0 {
    raise @types.LoadError::DecodeFailed("lbp_features: radius必须大于0")
  }
  if num_points <= 0 {
    raise @types.LoadError::DecodeFailed(
      "lbp_features: num_points必须大于0",
    )
  }
  if num_bins <= 0 {
    raise @types.LoadError::DecodeFailed("lbp_features: num_bins必须大于0")
  }

  let w = img.width
  let h = img.height
  let data = img.data
  // 计算 LBP 码
  let lbp_codes : Array[Int] = Array::make(w * h, 0)
  for y in radius..<(h - radius) {
    for x in radius..<(w - radius) {
      let center = data[y * w + x].to_int()
      let mut code = 0
      for i in 0..<num_points {
        let angle = 2.0 *
          3.141592653589793 *
          i.to_double() /
          num_points.to_double()
        let nx = (x.to_double() + radius.to_double() * @math.cos(angle)).to_int()
        let ny = (y.to_double() + radius.to_double() * @math.sin(angle)).to_int()
        if nx >= 0 && nx < w && ny >= 0 && ny < h {
          let neighbor = data[ny * w + nx].to_int()
          if neighbor >= center {
            code = code | (1 << i)
          }
        }
      }
      lbp_codes[y * w + x] = code
    }
  }
  // 计算直方图
  let hist : Array[Double] = Array::make(num_bins, 0.0)
  let mut total = 0
  for i in 0..<(w * h) {
    let code = lbp_codes[i]
    if code < num_bins {
      hist[code] += 1.0
      total += 1
    }
  }
  // 归一化
  if total > 0 {
    for i in 0..<num_bins {
      hist[i] /= total.to_double()
    }
  }
  LbpFeatures::{ features: hist, num_bins, radius, num_points }
}

///|
/// 计算投影特征
pub fn projection_features(
  img : @types.Image,
) -> ProjectionFeatures raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "projection_features: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "projection_features: 仅支持单通道二值图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "projection_features: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let w = img.width
  let h = img.height
  let data = img.data
  // 水平投影
  let horizontal : Array[Double] = Array::make(h, 0.0)
  for y in 0..<h {
    let mut count = 0
    for x in 0..<w {
      if data[y * w + x].to_int() > 128 {
        count += 1
      }
    }
    horizontal[y] = count.to_double() / w.to_double()
  }
  // 垂直投影
  let vertical : Array[Double] = Array::make(w, 0.0)
  for x in 0..<w {
    let mut count = 0
    for y in 0..<h {
      if data[y * w + x].to_int() > 128 {
        count += 1
      }
    }
    vertical[x] = count.to_double() / h.to_double()
  }
  // 计算统计量
  let h_mean = mean_array(horizontal)
  let h_std = std_array(horizontal, h_mean)
  let v_mean = mean_array(vertical)
  let v_std = std_array(vertical, v_mean)
  ProjectionFeatures::{
    horizontal,
    vertical,
    horizontal_mean: h_mean,
    horizontal_std: h_std,
    vertical_mean: v_mean,
    vertical_std: v_std,
  }
}

///|
/// 计算网格特征（将图像分成网格，每个格子计算像素密度）
pub fn grid_features(
  img : @types.Image,
  grid_rows? : Int = 4,
  grid_cols? : Int = 4,
) -> GridFeatures raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "grid_features: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "grid_features: 仅支持单通道二值图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "grid_features: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if grid_rows <= 0 {
    raise @types.LoadError::DecodeFailed(
      "grid_features: grid_rows必须大于0",
    )
  }
  if grid_cols <= 0 {
    raise @types.LoadError::DecodeFailed(
      "grid_features: grid_cols必须大于0",
    )
  }

  let w = img.width
  let h = img.height
  let data = img.data
  let cell_w = w / grid_cols
  let cell_h = h / grid_rows
  let features : Array[Double] = []
  for r in 0..<grid_rows {
    for c in 0..<grid_cols {
      let mut count = 0
      let mut total = 0
      for y in 0..<cell_h {
        for x in 0..<cell_w {
          let px = c * cell_w + x
          let py = r * cell_h + y
          if px < w && py < h {
            total += 1
            if data[py * w + px].to_int() > 128 {
              count += 1
            }
          }
        }
      }
      let density = if total > 0 {
        count.to_double() / total.to_double()
      } else {
        0.0
      }
      features.push(density)
    }
  }
  GridFeatures::{ features, grid_rows, grid_cols }
}

///|
/// 计算统计特征
pub fn statistical_features(
  img : @types.Image,
) -> StatisticalFeatures raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "statistical_features: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "statistical_features: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "statistical_features: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let w = img.width
  let h = img.height
  let n = w * h
  let data = img.data
  // 计算直方图
  let hist : Array[Double] = Array::make(256, 0.0)
  for i in 0..<n {
    hist[data[i].to_int()] += 1.0
  }
  // 归一化
  for i in 0..<256 {
    hist[i] /= n.to_double()
  }
  // 均值
  let mut mean = 0.0
  for i in 0..<256 {
    mean += i.to_double() * hist[i]
  }
  // 方差/标准差
  let mut variance = 0.0
  for i in 0..<256 {
    let diff = i.to_double() - mean
    variance += diff * diff * hist[i]
  }
  let std = if variance > 0.0 { variance.sqrt() } else { 0.0 }
  // 偏度
  let mut skewness = 0.0
  if std > 0.0 {
    for i in 0..<256 {
      let diff = (i.to_double() - mean) / std
      skewness += diff * diff * diff * hist[i]
    }
  }
  // 峰度
  let mut kurtosis = 0.0
  if std > 0.0 {
    for i in 0..<256 {
      let diff = (i.to_double() - mean) / std
      kurtosis += diff * diff * diff * diff * hist[i]
    }
    kurtosis -= 3.0 // 超额峰度
  }
  // 熵
  let mut entropy = 0.0
  for i in 0..<256 {
    if hist[i] > 0.0 {
      entropy -= hist[i] * @math.log2(hist[i])
    }
  }
  // 能量
  let mut energy = 0.0
  for i in 0..<256 {
    energy += hist[i] * hist[i]
  }
  // 对比度（简化版）
  let mut contrast = 0.0
  for i in 0..<256 {
    contrast += (i.to_double() - mean) * (i.to_double() - mean) * hist[i]
  }
  // 同质性（简化版）
  let mut homogeneity = 0.0
  for i in 0..<256 {
    homogeneity += hist[i] / (1.0 + (i.to_double() - mean).abs())
  }
  StatisticalFeatures::{
    mean,
    std,
    skewness,
    kurtosis,
    entropy,
    energy,
    contrast,
    homogeneity,
  }
}

///|
/// 组合特征（将多种特征拼接成一个向量）
pub fn combined_features(
  img : @types.Image,
) -> Array[Double] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "combined_features: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "combined_features: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "combined_features: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let hog = hog_features(img)
  let lbp = lbp_features(img)
  let proj = projection_features(img)
  let grid = grid_features(img)
  let stats = statistical_features(img)
  let combined : Array[Double] = []
  // HOG 特征
  for f in hog.features {
    combined.push(f)
  }
  // LBP 特征（降采样，只取前64维）
  let lbp_dim = if lbp.features.length() > 64 {
    64
  } else {
    lbp.features.length()
  }
  for i in 0..<lbp_dim {
    combined.push(lbp.features[i])
  }
  // 投影特征统计量
  combined.push(proj.horizontal_mean)
  combined.push(proj.horizontal_std)
  combined.push(proj.vertical_mean)
  combined.push(proj.vertical_std)
  // 网格特征
  for f in grid.features {
    combined.push(f)
  }
  // 统计特征
  combined.push(stats.mean / 255.0)
  combined.push(stats.std / 128.0)
  combined.push(stats.skewness)
  combined.push(stats.kurtosis)
  combined.push(stats.entropy / 8.0)
  combined.push(stats.energy)
  combined.push(stats.contrast / 65025.0)
  combined.push(stats.homogeneity)
  combined
}

///|
/// 辅助函数：计算数组均值
fn mean_array(arr : Array[Double]) -> Double {
  if arr.length() == 0 {
    return 0.0
  }
  let mut sum = 0.0
  for v in arr {
    sum += v
  }
  sum / arr.length().to_double()
}

///|
/// 辅助函数：计算数组标准差
fn std_array(arr : Array[Double], mean : Double) -> Double {
  if arr.length() == 0 {
    return 0.0
  }
  let mut sum_sq = 0.0
  for v in arr {
    let diff = v - mean
    sum_sq += diff * diff
  }
  let variance = sum_sq / arr.length().to_double()
  if variance > 0.0 {
    variance.sqrt()
  } else {
    0.0
  }
}
