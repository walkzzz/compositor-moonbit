// 图像质量评估（v12.5.0）
// PSNR、SSIM、MSE、MAE

///|
/// 图像质量评估结果
pub(all) struct QualityMetrics {
  mse : Double // 均方误差
  mae : Double // 平均绝对误差
  psnr : Double // 峰值信噪比（dB）
  ssim : Double // 结构相似性
}

///|
/// 计算均方误差（MSE）
pub fn compute_mse(img1 : @types.Image, img2 : @types.Image) -> Double {
  if img1.width != img2.width || img1.height != img2.height {
    return -1.0
  }
  let w = img1.width
  let h = img1.height
  let channels = img1.channels.min(img2.channels)
  let mut sum = 0.0
  let mut count = 0
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * img1.channels
      let idx2 = (y * w + x) * img2.channels
      for c in 0..<channels {
        let diff = img1.data[idx + c].to_double() -
          img2.data[idx2 + c].to_double()
        sum += diff * diff
        count += 1
      }
    }
  }
  if count > 0 {
    sum / count.to_double()
  } else {
    0.0
  }
}

///|
/// 计算平均绝对误差（MAE）
pub fn compute_mae(img1 : @types.Image, img2 : @types.Image) -> Double {
  if img1.width != img2.width || img1.height != img2.height {
    return -1.0
  }
  let w = img1.width
  let h = img1.height
  let channels = img1.channels.min(img2.channels)
  let mut sum = 0.0
  let mut count = 0
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * img1.channels
      let idx2 = (y * w + x) * img2.channels
      for c in 0..<channels {
        let diff = (img1.data[idx + c].to_double() -
        img2.data[idx2 + c].to_double()).abs()
        sum += diff
        count += 1
      }
    }
  }
  if count > 0 {
    sum / count.to_double()
  } else {
    0.0
  }
}

///|
/// 计算峰值信噪比（PSNR）
pub fn compute_psnr(img1 : @types.Image, img2 : @types.Image) -> Double {
  let mse = compute_mse(img1, img2)
  if mse < 0.0 {
    return -1.0
  }
  if mse < 0.000001 {
    return 100.0 // 几乎完全相同
  }
  let max_pixel = 255.0
  10.0 * @math.log10(max_pixel * max_pixel / mse)
}

///|
/// 计算结构相似性（SSIM，简化版）
/// 使用全局统计量，不使用滑动窗口
pub fn compute_ssim(img1 : @types.Image, img2 : @types.Image) -> Double {
  if img1.width != img2.width || img1.height != img2.height {
    return -1.0
  }
  let w = img1.width
  let h = img1.height
  let channels = img1.channels.min(img2.channels)
  let n = (w * h * channels).to_double()
  if n == 0.0 {
    return 0.0
  }
  // 计算均值
  let mut mean1 = 0.0
  let mut mean2 = 0.0
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * img1.channels
      let idx2 = (y * w + x) * img2.channels
      for c in 0..<channels {
        mean1 += img1.data[idx + c].to_double()
        mean2 += img2.data[idx2 + c].to_double()
      }
    }
  }
  mean1 = mean1 / n
  mean2 = mean2 / n
  // 计算方差和协方差
  let mut var1 = 0.0
  let mut var2 = 0.0
  let mut covar = 0.0
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * img1.channels
      let idx2 = (y * w + x) * img2.channels
      for c in 0..<channels {
        let v1 = img1.data[idx + c].to_double() - mean1
        let v2 = img2.data[idx2 + c].to_double() - mean2
        var1 += v1 * v1
        var2 += v2 * v2
        covar += v1 * v2
      }
    }
  }
  var1 = var1 / n
  var2 = var2 / n
  covar = covar / n
  // SSIM 公式
  let c1 = 0.01 * 255.0 * (0.01 * 255.0)
  let c2 = 0.03 * 255.0 * (0.03 * 255.0)
  let numerator = (2.0 * mean1 * mean2 + c1) * (2.0 * covar + c2)
  let denominator = (mean1 * mean1 + mean2 * mean2 + c1) * (var1 + var2 + c2)
  if denominator > 0.0 {
    numerator / denominator
  } else {
    0.0
  }
}

///|
/// 计算完整的图像质量评估指标
pub fn compute_quality_metrics(
  img1 : @types.Image,
  img2 : @types.Image,
) -> QualityMetrics {
  let mse = compute_mse(img1, img2)
  let mae = compute_mae(img1, img2)
  let psnr = compute_psnr(img1, img2)
  let ssim = compute_ssim(img1, img2)
  QualityMetrics::{ mse, mae, psnr, ssim }
}

///|
/// 比较两张图像是否相同（像素级）
pub fn images_equal(img1 : @types.Image, img2 : @types.Image) -> Bool {
  if img1.width != img2.width ||
    img1.height != img2.height ||
    img1.channels != img2.channels {
    return false
  }
  let w = img1.width
  let h = img1.height
  let channels = img1.channels
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      for c in 0..<channels {
        if img1.data[idx + c] != img2.data[idx + c] {
          return false
        }
      }
    }
  }
  true
}

///|
/// 计算图像差异图
pub fn compute_diff_image(
  img1 : @types.Image,
  img2 : @types.Image,
) -> @types.Image {
  if img1.width != img2.width || img1.height != img2.height {
    return img1
  }
  let w = img1.width
  let h = img1.height
  let channels = img1.channels.min(img2.channels)
  let out_channels = if channels >= 3 { 3 } else { 1 }
  let out_data : Array[Byte] = Array::make(w * h * out_channels, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * img1.channels
      let idx2 = (y * w + x) * img2.channels
      let out_idx = (y * w + x) * out_channels
      let mut max_diff = 0
      for c in 0..<channels {
        let diff = (img1.data[idx + c].to_int() - img2.data[idx2 + c].to_int()).abs()
        if diff > max_diff {
          max_diff = diff
        }
      }
      if out_channels >= 3 {
        // 红色表示差异大
        out_data[out_idx] = max_diff.to_byte()
        out_data[out_idx + 1] = b'\x00'
        out_data[out_idx + 2] = b'\x00'
      } else {
        out_data[out_idx] = max_diff.to_byte()
      }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: out_channels,
    data: Bytes::from_array(out_data),
  }
}
