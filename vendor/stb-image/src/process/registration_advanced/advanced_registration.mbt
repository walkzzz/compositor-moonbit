// 高级图像配准算法（v30.0.0）
// 特征点匹配、变换估计、多模态配准、配准质量评估

///|
/// 配准算法类型
pub(all) enum RegistrationAlgorithm {
  PhaseCorrelation
  FeatureBased
  IntensityBased
  MutualInformation
  NormalizedCrossCorrelation
  SumOfSquaredDifferences
  OpticalFlow
  Demons
  Bspline
  Unknown
} derive(Eq)

///|
/// 变换类型
pub(all) enum TransformType {
  Translation
  Rigid
  Similarity
  Affine
  Perspective
  Polynomial
  ThinPlateSpline
  Bspline
  Unknown
} derive(Eq)

///|
/// 配准结果
pub(all) struct RegistrationResultAdvanced {
  registered_image : @types.Image
  algorithm : RegistrationAlgorithm
  transform_type : TransformType
  transform_matrix : Array[Double]
  translation_x : Double
  translation_y : Double
  rotation_angle : Double
  scale_x : Double
  scale_y : Double
  correlation : Double
  mutual_information : Double
  rmse : Double
  processing_time_ms : Double
  num_feature_points : Int
  num_inliers : Int
}

///|
/// 配准配置
pub(all) struct RegistrationConfigAdvanced {
  algorithm : RegistrationAlgorithm
  transform_type : TransformType
  max_iterations : Int
  convergence_threshold : Double
  pyramid_levels : Int
  search_radius : Int
  use_multiresolution : Bool
  use_robust_estimation : Bool
}

///|
/// 特征点
pub(all) struct FeaturePoint {
  x : Double
  y : Double
  response : Double
  orientation : Double
  scale : Double
  descriptor : Array[Double]
}

///|
/// 特征匹配对
pub(all) struct FeatureMatch {
  point1 : FeaturePoint
  point2 : FeaturePoint
  distance : Double
  is_inlier : Bool
}

///|
/// 变换矩阵
pub(all) struct TransformMatrix {
  matrix : Array[Double]
  transform_type : TransformType
  width : Int
  height : Int
}

///|
/// 创建默认配准配置
pub fn create_default_registration_config_advanced() -> RegistrationConfigAdvanced {
  RegistrationConfigAdvanced::{
    algorithm: RegistrationAlgorithm::PhaseCorrelation,
    transform_type: TransformType::Translation,
    max_iterations: 100,
    convergence_threshold: 0.001,
    pyramid_levels: 3,
    search_radius: 32,
    use_multiresolution: true,
    use_robust_estimation: true,
  }
}

///|
/// 相位相关配准（平移估计）
pub fn phase_correlation_registration(
  img1 : @types.Image,
  img2 : @types.Image,
) -> RegistrationResultAdvanced {
  let w = img1.width
  let h = img1.height
  let total = w * h

  // 简化的相位相关：计算互相关
  let mut max_corr = 0.0
  let mut best_dx = 0
  let mut best_dy = 0

  // 搜索范围
  let search_range = 32
  for dy in -search_range..<(search_range + 1) {
    for dx in -search_range..<(search_range + 1) {
      let mut corr = 0.0
      let mut count = 0
      for y in 0..<h {
        for x in 0..<w {
          let nx = x + dx
          let ny = y + dy
          if nx >= 0 && nx < w && ny >= 0 && ny < h {
            let p1 = img1.data[y * w + x].to_double()
            let p2 = img2.data[ny * w + nx].to_double()
            corr += p1 * p2
            count += 1
          }
        }
      }
      if count > 0 {
        corr /= count.to_double()
      }
      if corr > max_corr {
        max_corr = corr
        best_dx = dx
        best_dy = dy
      }
    }
  }

  // 应用平移变换
  let registered = apply_translation(img2, best_dx, best_dy)

  // 计算 RMSE
  let mut rmse = 0.0
  for i in 0..<total {
    let diff = img1.data[i].to_double() - registered.data[i].to_double()
    rmse += diff * diff
  }
  rmse = (rmse / total.to_double()).sqrt()

  RegistrationResultAdvanced::{
    registered_image: registered,
    algorithm: RegistrationAlgorithm::PhaseCorrelation,
    transform_type: TransformType::Translation,
    transform_matrix: [
      1.0,
      0.0,
      best_dx.to_double(),
      0.0,
      1.0,
      best_dy.to_double(),
      0.0,
      0.0,
      1.0,
    ],
    translation_x: best_dx.to_double(),
    translation_y: best_dy.to_double(),
    rotation_angle: 0.0,
    scale_x: 1.0,
    scale_y: 1.0,
    correlation: max_corr / 255.0,
    mutual_information: 0.0,
    rmse,
    processing_time_ms: 0.0,
    num_feature_points: 0,
    num_inliers: 0,
  }
}

///|
/// 应用平移变换
pub fn apply_translation(
  img : @types.Image,
  dx : Int,
  dy : Int,
) -> @types.Image {
  let w = img.width
  let h = img.height
  let _ = w * h
  let out : Array[Byte] = []

  for y in 0..<h {
    for x in 0..<w {
      let src_x = x - dx
      let src_y = y - dy
      if src_x >= 0 && src_x < w && src_y >= 0 && src_y < h {
        out.push(img.data[src_y * w + src_x])
      } else {
        out.push(b'\x00')
      }
    }
  }

  @types.Image::{
    width: w,
    height: h,
    channels: img.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 归一化互相关（NCC）
pub fn normalized_cross_correlation(
  img1 : @types.Image,
  img2 : @types.Image,
) -> Double {
  let w = img1.width
  let h = img1.height
  let total = w * h

  // 计算均值
  let mut mean1 = 0.0
  let mut mean2 = 0.0
  for i in 0..<total {
    mean1 += img1.data[i].to_double()
    mean2 += img2.data[i].to_double()
  }
  mean1 /= total.to_double()
  mean2 /= total.to_double()

  // 计算 NCC
  let mut numerator = 0.0
  let mut denom1 = 0.0
  let mut denom2 = 0.0
  for i in 0..<total {
    let p1 = img1.data[i].to_double() - mean1
    let p2 = img2.data[i].to_double() - mean2
    numerator += p1 * p2
    denom1 += p1 * p1
    denom2 += p2 * p2
  }

  if denom1 > 0.0 && denom2 > 0.0 {
    numerator / (denom1.sqrt() * denom2.sqrt())
  } else {
    0.0
  }
}

///|
/// 互信息（Mutual Information）
pub fn calculate_mutual_information(
  img1 : @types.Image,
  img2 : @types.Image,
) -> Double {
  let w = img1.width
  let h = img1.height
  let total = w * h
  let bins = 64

  // 联合直方图
  let joint_hist : Array[Int] = []
  for _ in 0..<(bins * bins) {
    joint_hist.push(0)
  }

  for i in 0..<total {
    let b1 = img1.data[i].to_int() * bins / 256
    let b2 = img2.data[i].to_int() * bins / 256
    joint_hist[b1 * bins + b2] += 1
  }

  // 计算互信息
  let mut mi = 0.0
  for i in 0..<bins {
    for j in 0..<bins {
      let pxy = joint_hist[i * bins + j].to_double() / total.to_double()
      if pxy > 0.0 {
        // 计算边缘概率
        let mut px = 0.0
        let mut py = 0.0
        for k in 0..<bins {
          px += joint_hist[i * bins + k].to_double() / total.to_double()
          py += joint_hist[k * bins + j].to_double() / total.to_double()
        }
        if px > 0.0 && py > 0.0 {
          mi += pxy * (pxy / (px * py)) * 0.1 // 简化的 log
        }
      }
    }
  }

  mi
}

///|
/// Harris 角点检测（简化版）
pub fn detect_harris_corners(
  img : @types.Image,
  threshold : Double,
) -> Array[FeaturePoint] {
  let w = img.width
  let h = img.height
  let points : Array[FeaturePoint] = []

  // 计算梯度
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let gx = img.data[idx + 1].to_double() - img.data[idx - 1].to_double()
      let gy = img.data[idx + w].to_double() - img.data[idx - w].to_double()

      // Harris 响应（简化版）
      let response = gx * gx * gy * gy -
        gx * gy * (gx * gy) * 0.04 -
        (gx * gx + gy * gy) * (gx * gx + gy * gy) * 0.04

      if response > threshold {
        points.push(FeaturePoint::{
          x: x.to_double(),
          y: y.to_double(),
          response,
          orientation: 0.0,
          scale: 1.0,
          descriptor: [],
        })
      }
    }
  }

  points
}

///|
/// 特征点匹配（简化版：基于距离）
pub fn match_feature_points(
  points1 : Array[FeaturePoint],
  points2 : Array[FeaturePoint],
  max_distance : Double,
) -> Array[FeatureMatch] {
  let matches : Array[FeatureMatch] = []

  for p1 in points1 {
    let mut best_match : FeaturePoint = p1
    let mut best_dist = max_distance
    for p2 in points2 {
      let dx = p1.x - p2.x
      let dy = p1.y - p2.y
      let dist = (dx * dx + dy * dy).sqrt()
      if dist < best_dist {
        best_dist = dist
        best_match = p2
      }
    }
    if best_dist < max_distance {
      matches.push(FeatureMatch::{
        point1: p1,
        point2: best_match,
        distance: best_dist,
        is_inlier: true,
      })
    }
  }

  matches
}

///|
/// 估计仿射变换（简化版：基于匹配对）
pub fn estimate_affine_transform(
  matches : Array[FeatureMatch],
) -> TransformMatrix {
  // 简化：使用前3个匹配对估计仿射变换
  if matches.length() >= 3 {
    let m1 = matches[0]
    let m2 = matches[1]
    let m3 = matches[2]

    // 简化的仿射矩阵
    let a = (m2.point2.x - m1.point2.x) / (m2.point1.x - m1.point1.x + 0.001)
    let b = (m3.point2.y - m1.point2.y) / (m3.point1.y - m1.point1.y + 0.001)
    let tx = m1.point2.x - a * m1.point1.x
    let ty = m1.point2.y - b * m1.point1.y

    TransformMatrix::{
      matrix: [a, 0.0, tx, 0.0, b, ty, 0.0, 0.0, 1.0],
      transform_type: TransformType::Affine,
      width: 3,
      height: 3,
    }
  } else {
    TransformMatrix::{
      matrix: [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
      transform_type: TransformType::Unknown,
      width: 3,
      height: 3,
    }
  }
}

///|
/// 应用仿射变换
pub fn apply_affine_transform(
  img : @types.Image,
  matrix : TransformMatrix,
) -> @types.Image {
  let w = img.width
  let h = img.height
  let _ = w * h
  let out : Array[Byte] = []

  let a = matrix.matrix[0]
  let b = matrix.matrix[1]
  let tx = matrix.matrix[2]
  let c = matrix.matrix[3]
  let d = matrix.matrix[4]
  let ty = matrix.matrix[5]

  for y in 0..<h {
    for x in 0..<w {
      // 逆变换
      let src_x = (d * (x.to_double() - tx) - b * (y.to_double() - ty)) /
        (a * d - b * c + 0.001)
      let src_y = (-c * (x.to_double() - tx) + a * (y.to_double() - ty)) /
        (a * d - b * c + 0.001)

      let sx = src_x.to_int()
      let sy = src_y.to_int()

      if sx >= 0 && sx < w && sy >= 0 && sy < h {
        out.push(img.data[sy * w + sx])
      } else {
        out.push(b'\x00')
      }
    }
  }

  @types.Image::{
    width: w,
    height: h,
    channels: img.channels,
    data: Bytes::from_array(out),
  }
}

///|
/// 基于特征的配准
pub fn feature_based_registration(
  img1 : @types.Image,
  img2 : @types.Image,
  config : RegistrationConfigAdvanced,
) -> RegistrationResultAdvanced {
  ignore(config)
  // 检测特征点
  let points1 = detect_harris_corners(img1, 100000.0)
  let points2 = detect_harris_corners(img2, 100000.0)

  // 匹配特征点
  let matches = match_feature_points(points1, points2, 100.0)

  // 估计变换
  let transform = estimate_affine_transform(matches)

  // 应用变换
  let registered = apply_affine_transform(img2, transform)

  // 计算质量指标
  let correlation = normalized_cross_correlation(img1, registered)
  let mi = calculate_mutual_information(img1, registered)

  // 计算 RMSE
  let w = img1.width
  let h = img1.height
  let total = w * h
  let mut rmse = 0.0
  for i in 0..<total {
    let diff = img1.data[i].to_double() - registered.data[i].to_double()
    rmse += diff * diff
  }
  rmse = (rmse / total.to_double()).sqrt()

  RegistrationResultAdvanced::{
    registered_image: registered,
    algorithm: RegistrationAlgorithm::FeatureBased,
    transform_type: TransformType::Affine,
    transform_matrix: transform.matrix,
    translation_x: transform.matrix[2],
    translation_y: transform.matrix[5],
    rotation_angle: 0.0,
    scale_x: transform.matrix[0],
    scale_y: transform.matrix[4],
    correlation,
    mutual_information: mi,
    rmse,
    processing_time_ms: 0.0,
    num_feature_points: points1.length() + points2.length(),
    num_inliers: matches.length(),
  }
}

///|
/// 图像配准（主入口）
pub fn register_images_advanced(
  img1 : @types.Image,
  img2 : @types.Image,
  config : RegistrationConfigAdvanced,
) -> RegistrationResultAdvanced {
  if config.algorithm == RegistrationAlgorithm::PhaseCorrelation {
    phase_correlation_registration(img1, img2)
  } else if config.algorithm == RegistrationAlgorithm::FeatureBased {
    feature_based_registration(img1, img2, config)
  } else {
    phase_correlation_registration(img1, img2)
  }
}

///|
/// 生成配准报告
pub fn registration_report_to_string_advanced(
  result : RegistrationResultAdvanced,
) -> String {
  let mut report = "## 高级图像配准报告\n\n"
  report = report + "### 配准信息\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report +
    "| 算法 | " +
    (if result.algorithm == RegistrationAlgorithm::PhaseCorrelation {
      "相位相关"
    } else if result.algorithm == RegistrationAlgorithm::FeatureBased {
      "基于特征"
    } else if result.algorithm == RegistrationAlgorithm::IntensityBased {
      "基于强度"
    } else if result.algorithm == RegistrationAlgorithm::MutualInformation {
      "互信息"
    } else if result.algorithm ==
      RegistrationAlgorithm::NormalizedCrossCorrelation {
      "归一化互相关"
    } else {
      "未知"
    }) +
    " |\n"
  report = report +
    "| 变换类型 | " +
    (if result.transform_type == TransformType::Translation {
      "平移"
    } else if result.transform_type == TransformType::Rigid {
      "刚性"
    } else if result.transform_type == TransformType::Similarity {
      "相似"
    } else if result.transform_type == TransformType::Affine {
      "仿射"
    } else if result.transform_type == TransformType::Perspective {
      "透视"
    } else {
      "未知"
    }) +
    " |\n"
  report = report +
    "| 平移 X | " +
    result.translation_x.to_string() +
    " 像素 |\n"
  report = report +
    "| 平移 Y | " +
    result.translation_y.to_string() +
    " 像素 |\n"
  report = report +
    "| 旋转角度 | " +
    result.rotation_angle.to_string() +
    " 度 |\n"
  report = report + "| 缩放 X | " + result.scale_x.to_string() + " |\n"
  report = report + "| 缩放 Y | " + result.scale_y.to_string() + " |\n"
  report = report +
    "| 相关系数 | " +
    result.correlation.to_string() +
    " |\n"
  report = report +
    "| 互信息 | " +
    result.mutual_information.to_string() +
    " |\n"
  report = report + "| RMSE | " + result.rmse.to_string() + " |\n"
  report = report +
    "| 特征点数 | " +
    result.num_feature_points.to_string() +
    " |\n"
  report = report + "| 内点数 | " + result.num_inliers.to_string() + " |\n"

  report
}
