// 计算摄影增强（v12.15.0）
// 低光增强、去运动模糊、色彩增强、自适应直方图均衡化

///|
/// 低光增强配置
pub(all) struct LowLightConfig {
  method_type : String // "gamma" / "log" / "retinex"
  gamma : Double // Gamma 校正参数
  strength : Double // 增强强度
}

///|
/// 创建默认低光增强配置
pub fn low_light_default_config() -> LowLightConfig {
  LowLightConfig::{ method_type: "gamma", gamma: 0.5, strength: 1.0 }
}

///|
/// Gamma 校正低光增强
fn gamma_enhance(img : @types.Image, gamma : Double) -> @types.Image {
  let w = img.width
  let h = img.height
  let channels = img.channels
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  // 预计算 Gamma 查找表
  let lut : Array[Byte] = []
  for i in 0..<256 {
    let normalized = i.to_double() / 255.0
    let enhanced = @math.pow(normalized, gamma)
    let val = (enhanced * 255.0).to_int().min(255).max(0)
    lut.push(val.to_byte())
  }
  for i in 0..<(w * h * channels) {
    out_data[i] = lut[img.data[i].to_int()]
  }
  @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 对数变换低光增强
fn log_enhance(img : @types.Image, strength : Double) -> @types.Image {
  let w = img.width
  let h = img.height
  let channels = img.channels
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  let c = 255.0 / @math.ln(1.0 + 255.0)
  for i in 0..<(w * h * channels) {
    let val = img.data[i].to_double()
    let enhanced = c * @math.ln(1.0 + val) * strength
    out_data[i] = enhanced.min(255.0).max(0.0).to_int().to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 简化版 Retinex 低光增强（单尺度 Retinex）
fn retinex_enhance(img : @types.Image, sigma? : Double = 50.0) -> @types.Image {
  let _ = sigma
  let w = img.width
  let h = img.height
  let channels = img.channels
  // 简化版：使用高斯模糊作为光照估计
  // 这里用简单的均值模糊代替（避免依赖外部高斯模糊）
  let kernel_size = 15
  let half = kernel_size / 2
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      for c in 0..<channels {
        // 计算局部均值（光照估计）
        let mut sum = 0.0
        let mut count = 0
        for ky in -half..<=half {
          for kx in -half..<=half {
            let ny = y + ky
            let nx = x + kx
            if ny >= 0 && ny < h && nx >= 0 && nx < w {
              let nidx = (ny * w + nx) * channels
              sum += img.data[nidx + c].to_double()
              count += 1
            }
          }
        }
        let illumination = if count > 0 { sum / count.to_double() } else { 0.0 }
        // Retinex: R = log(I) - log(L) = log(I/L)
        let original = img.data[idx + c].to_double() + 1.0
        let light = illumination + 1.0
        let ratio = original / light
        let reflectance = @math.ln(ratio)
        // 映射回 0-255
        let enhanced = (reflectance + 3.0) / 6.0 * 255.0
        out_data[idx + c] = enhanced.min(255.0).max(0.0).to_int().to_byte()
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
/// 低光增强（统一接口）
pub fn low_light_enhance(
  img : @types.Image,
  config? : LowLightConfig,
) -> @types.Image {
  let cfg = match config {
    Some(v) => v
    None => low_light_default_config()
  }
  match cfg.method_type {
    "gamma" => gamma_enhance(img, cfg.gamma)
    "log" => log_enhance(img, cfg.strength)
    "retinex" => retinex_enhance(img, sigma=50.0)
    _ => gamma_enhance(img, cfg.gamma)
  }
}

///|
/// 去运动模糊（简化版维纳滤波）
pub fn deblur_motion(
  img : @types.Image,
  kernel_size? : Int = 15,
  angle? : Double = 0.0,
) -> @types.Image {
  let ks = kernel_size
  let _ = angle
  let w = img.width
  let h = img.height
  let channels = img.channels
  // 简化版：使用非锐化掩模（Unsharp Mask）作为去模糊近似
  let amount = 1.5
  let threshold = 0
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  let blur_radius = ks / 2
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      for c in 0..<channels {
        // 计算局部均值（模糊版本）
        let mut sum = 0.0
        let mut count = 0
        for ky in -blur_radius..<=blur_radius {
          for kx in -blur_radius..<=blur_radius {
            let ny = y + ky
            let nx = x + kx
            if ny >= 0 && ny < h && nx >= 0 && nx < w {
              let nidx = (ny * w + nx) * channels
              sum += img.data[nidx + c].to_double()
              count += 1
            }
          }
        }
        let blurred = if count > 0 { sum / count.to_double() } else { 0.0 }
        let original = img.data[idx + c].to_double()
        // 非锐化掩模：sharpened = original + amount * (original - blurred)
        let diff = original - blurred
        let sharpened = if diff.abs() > threshold.to_double() {
          original + amount * diff
        } else {
          original
        }
        out_data[idx + c] = sharpened.min(255.0).max(0.0).to_int().to_byte()
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
/// 色彩增强（饱和度和对比度增强）
pub fn color_enhance(
  img : @types.Image,
  saturation? : Double = 1.3,
  contrast? : Double = 1.1,
) -> @types.Image {
  let sat = saturation
  let con = contrast
  let w = img.width
  let h = img.height
  let channels = img.channels
  if channels < 3 {
    return img
  }
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      let r = img.data[idx].to_double()
      let g = img.data[idx + 1].to_double()
      let b = img.data[idx + 2].to_double()
      // 计算灰度值
      let gray = 0.299 * r + 0.587 * g + 0.114 * b
      // 饱和度增强
      let new_r = gray + (r - gray) * sat
      let new_g = gray + (g - gray) * sat
      let new_b = gray + (b - gray) * sat
      // 对比度增强
      let final_r = (new_r - 128.0) * con + 128.0
      let final_g = (new_g - 128.0) * con + 128.0
      let final_b = (new_b - 128.0) * con + 128.0
      out_data[idx] = final_r.min(255.0).max(0.0).to_int().to_byte()
      out_data[idx + 1] = final_g.min(255.0).max(0.0).to_int().to_byte()
      out_data[idx + 2] = final_b.min(255.0).max(0.0).to_int().to_byte()
      // 复制其他通道
      for c in 3..<channels {
        out_data[idx + c] = img.data[idx + c]
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
/// 自适应直方图均衡化（CLAHE 简化版）
pub fn clahe_enhance(
  img : @types.Image,
  clip_limit? : Double = 2.0,
  tile_size? : Int = 8,
) -> @types.Image {
  let clip = clip_limit
  let _ = tile_size
  let w = img.width
  let h = img.height
  let channels = img.channels
  // 简化版：全局直方图均衡化
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  for c in 0..<channels {
    // 计算直方图
    let histogram : Array[Int] = []
    for _ in 0..<256 {
      histogram.push(0)
    }
    for y in 0..<h {
      for x in 0..<w {
        let idx = (y * w + x) * channels
        histogram[img.data[idx + c].to_int()] += 1
      }
    }
    // 裁剪直方图
    let total_pixels = (w * h).to_double()
    let max_count = (clip * total_pixels / 256.0).to_int()
    let mut excess = 0
    for i in 0..<256 {
      if histogram[i] > max_count {
        excess += histogram[i] - max_count
        histogram[i] = max_count
      }
    }
    // 重新分配超额像素
    let redistribute = excess / 256
    for i in 0..<256 {
      histogram[i] += redistribute
    }
    // 计算累积分布函数（CDF）
    let cdf : Array[Int] = []
    let mut cumsum = 0
    for i in 0..<256 {
      cumsum += histogram[i]
      cdf.push(cumsum)
    }
    // 查找表
    let lut : Array[Byte] = []
    let cdf_min = cdf[0]
    let denominator = (w * h - cdf_min).max(1)
    for i in 0..<256 {
      let val = ((cdf[i] - cdf_min).to_double() /
        denominator.to_double() *
        255.0)
        .to_int()
        .min(255)
        .max(0)
      lut.push(val.to_byte())
    }
    // 应用查找表
    for y in 0..<h {
      for x in 0..<w {
        let idx = (y * w + x) * channels
        out_data[idx + c] = lut[img.data[idx + c].to_int()]
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
/// 白平衡校正（灰度世界算法）
pub fn white_balance(img : @types.Image) -> @types.Image {
  let w = img.width
  let h = img.height
  let channels = img.channels
  if channels < 3 {
    return img
  }
  // 计算各通道平均值
  let mut sum_r = 0.0
  let mut sum_g = 0.0
  let mut sum_b = 0.0
  let total = (w * h).to_double()
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      sum_r += img.data[idx].to_double()
      sum_g += img.data[idx + 1].to_double()
      sum_b += img.data[idx + 2].to_double()
    }
  }
  let avg_r = sum_r / total
  let avg_g = sum_g / total
  let avg_b = sum_b / total
  let avg_gray = (avg_r + avg_g + avg_b) / 3.0
  // 计算增益
  let gain_r = avg_gray / avg_r.max(1.0)
  let gain_g = avg_gray / avg_g.max(1.0)
  let gain_b = avg_gray / avg_b.max(1.0)
  // 应用增益
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      out_data[idx] = (img.data[idx].to_double() * gain_r)
        .min(255.0)
        .max(0.0)
        .to_int()
        .to_byte()
      out_data[idx + 1] = (img.data[idx + 1].to_double() * gain_g)
        .min(255.0)
        .max(0.0)
        .to_int()
        .to_byte()
      out_data[idx + 2] = (img.data[idx + 2].to_double() * gain_b)
        .min(255.0)
        .max(0.0)
        .to_int()
        .to_byte()
      for c in 3..<channels {
        out_data[idx + c] = img.data[idx + c]
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
/// 批量计算摄影增强
pub fn batch_photo_enhance(
  images : Array[@types.Image],
  method_type : String,
) -> Array[@types.Image] {
  let result : Array[@types.Image] = []
  for img in images {
    let enhanced = match method_type {
      "low_light" => low_light_enhance(img)
      "deblur" => deblur_motion(img, kernel_size=15, angle=0.0)
      "color" => color_enhance(img, saturation=1.3, contrast=1.1)
      "clahe" => clahe_enhance(img, clip_limit=2.0, tile_size=8)
      "white_balance" => white_balance(img)
      _ => img
    }
    result.push(enhanced)
  }
  result
}
