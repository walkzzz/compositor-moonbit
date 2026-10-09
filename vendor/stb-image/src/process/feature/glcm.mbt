// GLCM 灰度共生矩阵纹理分析（纯 MoonBit）

///|
/// GLCM 纹理特征
pub struct GlcmFeatures {
  contrast : Float // 对比度
  correlation : Float // 相关性
  energy : Float // 能量（ASM 的平方根）
  homogeneity : Float // 同质性
  entropy : Float // 熵
  asm_value : Float // 角二阶矩
  dissimilarity : Float // 不相似性
}

///|
/// 计算灰度共生矩阵（GLCM）。
/// 适用于灰度图（channels=1）或 RGB/RGBA 图（channels=3/4，自动转灰度）。
/// dx, dy 为偏移量（如 (1,0) 为水平 0°，(0,1) 为垂直 90°）。
/// levels 为量化级别数（默认 256，可降采样以加速）。
pub fn compute_glcm(
  img : @types.Image,
  dx : Int,
  dy : Int,
  levels? : Int = 256,
) -> Array[Array[Int]] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "compute_glcm: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "compute_glcm: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "compute_glcm: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if dx == 0 && dy == 0 {
    raise @types.LoadError::DecodeFailed(
      "compute_glcm: dx和dy不能同时为0",
    )
  }
  if levels < 2 || levels > 256 {
    raise @types.LoadError::DecodeFailed("levels 必须在 2..256 之间")
  }
  let w = img.width
  let h = img.height
  let n = w * h
  if n == 0 {
    return []
  }
  // 转灰度并量化
  let gray : Array[Int] = Array::make(n, 0)
  let ch = img.channels
  let data_int : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    data_int[i] = img.data[i].to_int()
  }
  let scale = if levels < 256 { 256 / levels } else { 1 }
  for i in 0..<n {
    let v = if ch == 1 {
      data_int[i]
    } else {
      let r = data_int[i * ch]
      let g = data_int[i * ch + 1]
      let b = data_int[i * ch + 2]
      (r * 299 + g * 587 + b * 114) / 1000
    }
    gray[i] = if scale > 1 { v / scale } else { v }
    if gray[i] >= levels {
      gray[i] = levels - 1
    }
  }
  // 构建 GLCM
  let glcm : Array[Array[Int]] = Array::make(levels, [])
  for i in 0..<levels {
    glcm[i] = Array::make(levels, 0)
  }
  for y in 0..<h {
    for x in 0..<w {
      let nx = x + dx
      let ny = y + dy
      if nx >= 0 && nx < w && ny >= 0 && ny < h {
        let v1 = gray[y * w + x]
        let v2 = gray[ny * w + nx]
        glcm[v1][v2] += 1
      }
    }
  }
  glcm
}

///|
/// 从 GLCM 计算纹理特征。
pub fn glcm_features(glcm : Array[Array[Int]]) -> GlcmFeatures {
  let levels = glcm.length()
  if levels == 0 {
    return GlcmFeatures::{
      contrast: 0.0F,
      correlation: 0.0F,
      energy: 0.0F,
      homogeneity: 0.0F,
      entropy: 0.0F,
      asm_value: 0.0F,
      dissimilarity: 0.0F,
    }
  }
  // 归一化
  let mut total = 0.0F
  for i in 0..<levels {
    for j in 0..<levels {
      total += Float::from_int(glcm[i][j])
    }
  }
  if total == 0.0F {
    return GlcmFeatures::{
      contrast: 0.0F,
      correlation: 0.0F,
      energy: 0.0F,
      homogeneity: 0.0F,
      entropy: 0.0F,
      asm_value: 0.0F,
      dissimilarity: 0.0F,
    }
  }
  // 计算均值和标准差
  let mut mean_i = 0.0F
  let mut mean_j = 0.0F
  for i in 0..<levels {
    for j in 0..<levels {
      let p = Float::from_int(glcm[i][j]) / total
      mean_i += Float::from_int(i) * p
      mean_j += Float::from_int(j) * p
    }
  }
  let mut var_i = 0.0F
  let mut var_j = 0.0F
  for i in 0..<levels {
    for j in 0..<levels {
      let p = Float::from_int(glcm[i][j]) / total
      var_i += p * (Float::from_int(i) - mean_i) * (Float::from_int(i) - mean_i)
      var_j += p * (Float::from_int(j) - mean_j) * (Float::from_int(j) - mean_j)
    }
  }
  let std_i = var_i.sqrt()
  let std_j = var_j.sqrt()
  // 计算特征
  let mut contrast = 0.0F
  let mut correlation = 0.0F
  let mut asm_val = 0.0F
  let mut homogeneity = 0.0F
  let mut entropy = 0.0F
  let mut dissimilarity = 0.0F
  for i in 0..<levels {
    for j in 0..<levels {
      let p = Float::from_int(glcm[i][j]) / total
      if p > 0.0F {
        let diff = Float::from_int(i - j)
        let abs_diff = diff.abs()
        contrast += p * diff * diff
        dissimilarity += p * abs_diff
        asm_val += p * p
        homogeneity += p / (1.0F + diff * diff)
        entropy += -p * Float::from_double(@math.log2(p.to_double()))
        if std_i > 0.0F && std_j > 0.0F {
          correlation += p *
            (Float::from_int(i) - mean_i) *
            (Float::from_int(j) - mean_j) /
            (std_i * std_j)
        }
      }
    }
  }
  GlcmFeatures::{
    contrast,
    correlation,
    energy: asm_val.sqrt(),
    homogeneity,
    entropy,
    asm_value: asm_val,
    dissimilarity,
  }
}

///|
/// 计算多方向 GLCM 特征（0°, 45°, 90°, 135°）。
/// 返回 4 个方向的纹理特征数组。
pub fn glcm_features_multi_direction(
  img : @types.Image,
  levels? : Int = 256,
) -> Array[GlcmFeatures] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "glcm_features_multi_direction: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "glcm_features_multi_direction: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "glcm_features_multi_direction: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if levels < 2 || levels > 256 {
    raise @types.LoadError::DecodeFailed(
      "glcm_features_multi_direction: levels必须在2..256之间",
    )
  }

  let directions = [(1, 0), (1, 1), (0, 1), (-1, 1)]
  let result : Array[GlcmFeatures] = []
  for dir in directions {
    let (dx, dy) = dir
    let glcm = compute_glcm(img, dx, dy, levels~)
    result.push(glcm_features(glcm))
  }
  result
}
