// HDR 高动态范围（v11.7.0）
// 多曝光融合 + 色调映射（Reinhard / Gamma / Sigmoid）

///|
/// HDR 配置
pub(all) struct HdrConfig {
  fusion_method : String // "average" / "weighted" / "mertens"
  tone_mapping : String // "reinhard" / "gamma" / "sigmoid"
  gamma : Double // Gamma 校正值
  reinhard_key : Double // Reinhard 色调映射关键值
  sigmoid_strength : Double // Sigmoid 强度
}

///|
/// 创建默认 HDR 配置
pub fn hdr_default_config() -> HdrConfig {
  HdrConfig::{
    fusion_method: "weighted",
    tone_mapping: "reinhard",
    gamma: 1.0 / 2.2,
    reinhard_key: 0.18,
    sigmoid_strength: 5.0,
  }
}

///|
/// 多曝光融合（平均法）
/// 将多张不同曝光的图像取平均
pub fn hdr_fusion_average(
  images : Array[@types.Image],
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if images.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "hdr_fusion_average: 图像数组不能为空",
    )
  }
  let w = images[0].width
  let h = images[0].height
  let channels = images[0].channels

  // 验证第一张图像
  if w <= 0 || h <= 0 {
    raise @types.LoadError::DecodeFailed(
      "hdr_fusion_average: 图像尺寸必须大于0",
    )
  }
  if channels < 1 || channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "hdr_fusion_average: 通道数必须在1-4之间",
    )
  }

  // 验证所有图像尺寸一致且数据大小正确
  let expected_size = w * h * channels
  for img_idx in 0..<images.length() {
    let img = images[img_idx]
    if img.width != w || img.height != h || img.channels != channels {
      raise @types.LoadError::DecodeFailed(
        "hdr_fusion_average: 第 " +
        img_idx.to_string() +
        " 张图像尺寸/通道不一致",
      )
    }
    if img.data.length() != expected_size {
      raise @types.LoadError::DecodeFailed(
        "hdr_fusion_average: 第 " +
        img_idx.to_string() +
        " 张图像数据大小不匹配",
      )
    }
  }
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  let n = images.length().to_double()
  for i in 0..<(w * h) {
    for c in 0..<channels {
      let mut sum = 0.0
      for img in images {
        sum += img.data[i * channels + c].to_double()
      }
      let avg = sum / n
      out_data[i * channels + c] = avg.min(255.0).max(0.0).to_int().to_byte()
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 多曝光融合（加权法）
/// 根据图像亮度计算权重，亮部和暗部权重低，中间调权重高
pub fn hdr_fusion_weighted(
  images : Array[@types.Image],
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if images.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "hdr_fusion_weighted: 图像数组不能为空",
    )
  }
  let w = images[0].width
  let h = images[0].height
  let channels = images[0].channels

  // 验证第一张图像
  if w <= 0 || h <= 0 {
    raise @types.LoadError::DecodeFailed(
      "hdr_fusion_weighted: 图像尺寸必须大于0",
    )
  }
  if channels < 1 || channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "hdr_fusion_weighted: 通道数必须在1-4之间",
    )
  }

  // 验证所有图像尺寸一致且数据大小正确
  let expected_size = w * h * channels
  for img_idx in 0..<images.length() {
    let img = images[img_idx]
    if img.width != w || img.height != h || img.channels != channels {
      raise @types.LoadError::DecodeFailed(
        "hdr_fusion_weighted: 第 " +
        img_idx.to_string() +
        " 张图像尺寸/通道不一致",
      )
    }
    if img.data.length() != expected_size {
      raise @types.LoadError::DecodeFailed(
        "hdr_fusion_weighted: 第 " +
        img_idx.to_string() +
        " 张图像数据大小不匹配",
      )
    }
  }
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  // 计算每张图像的权重（基于亮度，中间调权重高）
  let weights : Array[Array[Double]] = []
  for img in images {
    let img_weight : Array[Double] = []
    for i in 0..<(w * h) {
      let idx = i * channels
      let r = img.data[idx].to_double()
      let g = if channels >= 2 { img.data[idx + 1].to_double() } else { r }
      let b = if channels >= 3 { img.data[idx + 2].to_double() } else { r }
      let luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
      // 高斯权重：在 0.5 处最大，向两端递减
      let weight = @math.exp(-(luminance - 0.5) * (luminance - 0.5) / 0.08)
      img_weight.push(weight)
    }
    weights.push(img_weight)
  }
  // 加权融合
  for i in 0..<(w * h) {
    let mut weight_sum = 0.0
    for img_idx in 0..<images.length() {
      weight_sum += weights[img_idx][i]
    }
    for c in 0..<channels {
      if weight_sum > 0.0 {
        let mut sum = 0.0
        for img_idx in 0..<images.length() {
          let weight = weights[img_idx][i] / weight_sum
          sum += images[img_idx].data[i * channels + c].to_double() * weight
        }
        out_data[i * channels + c] = sum.min(255.0).max(0.0).to_int().to_byte()
      } else {
        out_data[i * channels + c] = images[0].data[i * channels + c]
      }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// Reinhard 色调映射
/// L_ mapped = L / (1 + L) （全局色调映射）
pub fn tone_mapping_reinhard(
  img : @types.Image,
  key? : Double = 0.18,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "tone_mapping_reinhard: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "tone_mapping_reinhard: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "tone_mapping_reinhard: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if key <= 0.0 {
    raise @types.LoadError::DecodeFailed(
      "tone_mapping_reinhard: key必须大于0",
    )
  }

  let k = key
  let w = img.width
  let h = img.height
  let channels = img.channels
  let data = img.data
  // 计算对数平均亮度
  let mut log_sum = 0.0
  let delta = 0.0001
  for i in 0..<(w * h) {
    let idx = i * channels
    let r = data[idx].to_double() / 255.0
    let g = if channels >= 2 { data[idx + 1].to_double() / 255.0 } else { r }
    let b = if channels >= 3 { data[idx + 2].to_double() / 255.0 } else { r }
    let luminance = 0.299 * r + 0.587 * g + 0.114 * b
    log_sum += @math.ln(luminance + delta)
  }
  let log_avg = @math.exp(log_sum / (w * h).to_double())
  // 应用 Reinhard 色调映射
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  for i in 0..<(w * h) {
    let idx = i * channels
    for c in 0..<channels {
      let val = data[idx + c].to_double() / 255.0
      // 缩放
      let scaled = val * k / (log_avg + delta)
      // Reinhard 映射
      let mapped = scaled / (1.0 + scaled)
      out_data[idx + c] = (mapped * 255.0)
        .min(255.0)
        .max(0.0)
        .to_int()
        .to_byte()
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// Gamma 校正色调映射
/// out = in ^ gamma
pub fn tone_mapping_gamma(
  img : @types.Image,
  gamma? : Double = 1.0 / 2.2,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "tone_mapping_gamma: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "tone_mapping_gamma: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "tone_mapping_gamma: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if gamma <= 0.0 {
    raise @types.LoadError::DecodeFailed(
      "tone_mapping_gamma: gamma必须大于0",
    )
  }

  let g = gamma
  let w = img.width
  let h = img.height
  let channels = img.channels
  let data = img.data
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  for i in 0..<(w * h) {
    let idx = i * channels
    for c in 0..<channels {
      let val = data[idx + c].to_double() / 255.0
      let mapped = @math.pow(val, g)
      out_data[idx + c] = (mapped * 255.0)
        .min(255.0)
        .max(0.0)
        .to_int()
        .to_byte()
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// Sigmoid 色调映射
/// out = 1 / (1 + exp(-strength * (in - 0.5)))
pub fn tone_mapping_sigmoid(
  img : @types.Image,
  strength? : Double = 5.0,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "tone_mapping_sigmoid: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "tone_mapping_sigmoid: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "tone_mapping_sigmoid: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if strength <= 0.0 {
    raise @types.LoadError::DecodeFailed(
      "tone_mapping_sigmoid: strength必须大于0",
    )
  }

  let s = strength
  let w = img.width
  let h = img.height
  let channels = img.channels
  let data = img.data
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  for i in 0..<(w * h) {
    let idx = i * channels
    for c in 0..<channels {
      let val = data[idx + c].to_double() / 255.0
      let mapped = 1.0 / (1.0 + @math.exp(-s * (val - 0.5)))
      out_data[idx + c] = (mapped * 255.0)
        .min(255.0)
        .max(0.0)
        .to_int()
        .to_byte()
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 完整 HDR 流水线（多曝光融合 + 色调映射）
pub fn hdr_process(
  images : Array[@types.Image],
  config? : HdrConfig,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if images.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "hdr_process: 图像数组不能为空",
    )
  }

  let cfg = match config {
    Some(c) => c
    None => hdr_default_config()
  }

  // 配置验证
  if cfg.gamma <= 0.0 {
    raise @types.LoadError::DecodeFailed("hdr_process: gamma必须大于0")
  }
  if cfg.reinhard_key <= 0.0 {
    raise @types.LoadError::DecodeFailed(
      "hdr_process: reinhard_key必须大于0",
    )
  }
  if cfg.sigmoid_strength <= 0.0 {
    raise @types.LoadError::DecodeFailed(
      "hdr_process: sigmoid_strength必须大于0",
    )
  }
  // 1. 多曝光融合
  let fused = match cfg.fusion_method {
    "average" => hdr_fusion_average(images)
    _ => hdr_fusion_weighted(images)
  }
  // 2. 色调映射
  let tonemapped = match cfg.tone_mapping {
    "gamma" => tone_mapping_gamma(fused, gamma=cfg.gamma)
    "sigmoid" => tone_mapping_sigmoid(fused, strength=cfg.sigmoid_strength)
    _ => tone_mapping_reinhard(fused, key=cfg.reinhard_key)
  }
  tonemapped
}
