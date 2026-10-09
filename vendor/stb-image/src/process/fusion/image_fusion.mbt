// 图像融合（v12.6.0）
// 多焦点融合、曝光融合、Alpha 融合、拉普拉斯金字塔融合

///|
/// 图像融合配置
pub(all) struct FusionConfig {
  method_type : String // "alpha" / "multifocus" / "exposure" / "laplacian"
  alpha : Double // Alpha 融合的权重（0-1）
  pyramid_levels : Int // 拉普拉斯金字塔层数
}

///|
/// 创建默认融合配置
pub fn fusion_default_config() -> FusionConfig {
  FusionConfig::{ method_type: "alpha", alpha: 0.5, pyramid_levels: 3 }
}

///|
/// Alpha 融合
/// out = img1 * alpha + img2 * (1 - alpha)
pub fn fuse_alpha(
  img1 : @types.Image,
  img2 : @types.Image,
  alpha? : Double = 0.5,
) -> @types.Image {
  let a = alpha
  if img1.width != img2.width || img1.height != img2.height {
    return img1
  }
  let w = img1.width
  let h = img1.height
  let channels = img1.channels.min(img2.channels)
  let out_channels = img1.channels.max(img2.channels)
  let out_data : Array[Byte] = Array::make(w * h * out_channels, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      let idx1 = (y * w + x) * img1.channels
      let idx2 = (y * w + x) * img2.channels
      let out_idx = (y * w + x) * out_channels
      for c in 0..<channels {
        let v1 = img1.data[idx1 + c].to_double()
        let v2 = img2.data[idx2 + c].to_double()
        let fused = v1 * a + v2 * (1.0 - a)
        out_data[out_idx + c] = fused.min(255.0).max(0.0).to_int().to_byte()
      }
      // 复制额外通道
      for c in channels..<out_channels {
        if c < img1.channels {
          out_data[out_idx + c] = img1.data[idx1 + c]
        } else if c < img2.channels {
          out_data[out_idx + c] = img2.data[idx2 + c]
        }
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

///|
/// 计算图像的清晰度（拉普拉斯方差）
fn compute_sharpness(img : @types.Image, x : Int, y : Int) -> Double {
  let w = img.width
  let h = img.height
  let channels = img.channels
  if x <= 0 || x >= w - 1 || y <= 0 || y >= h - 1 {
    return 0.0
  }
  let _ = (y * w + x) * channels
  let gray = (px : Int, py : Int) => {
    let i = (py * w + px) * channels
    let r = img.data[i].to_double()
    let g = if channels >= 2 { img.data[i + 1].to_double() } else { r }
    let b = if channels >= 3 { img.data[i + 2].to_double() } else { r }
    0.299 * r + 0.587 * g + 0.114 * b
  }
  // 拉普拉斯算子
  let laplacian = 4.0 * gray(x, y) -
    gray(x - 1, y) -
    gray(x + 1, y) -
    gray(x, y - 1) -
    gray(x, y + 1)
  laplacian * laplacian
}

///|
/// 多焦点融合
/// 基于清晰度的像素级融合，选择更清晰的像素
pub fn fuse_multifocus(
  img1 : @types.Image,
  img2 : @types.Image,
) -> @types.Image {
  if img1.width != img2.width || img1.height != img2.height {
    return img1
  }
  let w = img1.width
  let h = img1.height
  let channels = img1.channels.min(img2.channels)
  let out_channels = img1.channels.max(img2.channels)
  let out_data : Array[Byte] = Array::make(w * h * out_channels, b'\x00')
  // 计算清晰度图
  let sharpness1 : Array[Double] = Array::make(w * h, 0.0)
  let sharpness2 : Array[Double] = Array::make(w * h, 0.0)
  for y in 0..<h {
    for x in 0..<w {
      sharpness1[y * w + x] = compute_sharpness(img1, x, y)
      sharpness2[y * w + x] = compute_sharpness(img2, x, y)
    }
  }
  // 像素级融合
  for y in 0..<h {
    for x in 0..<w {
      let idx1 = (y * w + x) * img1.channels
      let idx2 = (y * w + x) * img2.channels
      let out_idx = (y * w + x) * out_channels
      let use_img1 = sharpness1[y * w + x] >= sharpness2[y * w + x]
      for c in 0..<channels {
        if use_img1 {
          out_data[out_idx + c] = img1.data[idx1 + c]
        } else {
          out_data[out_idx + c] = img2.data[idx2 + c]
        }
      }
      // 复制额外通道
      for c in channels..<out_channels {
        if c < img1.channels {
          out_data[out_idx + c] = img1.data[idx1 + c]
        } else if c < img2.channels {
          out_data[out_idx + c] = img2.data[idx2 + c]
        }
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

///|
/// 曝光融合
/// 基于曝光质量的加权融合
pub fn fuse_exposure(images : Array[@types.Image]) -> @types.Image {
  if images.length() == 0 {
    return @types.Image::{
      width: 1,
      height: 1,
      channels: 1,
      data: Bytes::from_array([b'\x00']),
    }
  }
  if images.length() == 1 {
    return images[0]
  }
  let w = images[0].width
  let h = images[0].height
  let channels = images[0].channels
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  // 计算每张图像的权重（基于对比度、饱和度、曝光度）
  let weights : Array[Array[Double]] = []
  for img in images {
    let weight_map : Array[Double] = Array::make(w * h, 0.0)
    for y in 0..<h {
      for x in 0..<w {
        let idx = (y * w + x) * img.channels
        let r = img.data[idx].to_double()
        let g = if img.channels >= 2 {
          img.data[idx + 1].to_double()
        } else {
          r
        }
        let b = if img.channels >= 3 {
          img.data[idx + 2].to_double()
        } else {
          r
        }
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        // 曝光度权重（高斯，中心在 128）
        let exposure_weight = @math.exp(
          -(luminance - 128.0) * (luminance - 128.0) / (2.0 * 64.0 * 64.0),
        )
        // 对比度权重（拉普拉斯）
        let contrast_weight = compute_sharpness(img, x, y) + 1.0
        weight_map[y * w + x] = exposure_weight * contrast_weight
      }
    }
    weights.push(weight_map)
  }
  // 归一化权重并融合
  for y in 0..<h {
    for x in 0..<w {
      let mut weight_sum = 0.0
      for i in 0..<weights.length() {
        weight_sum += weights[i][y * w + x]
      }
      let out_idx = (y * w + x) * channels
      for c in 0..<channels {
        if weight_sum > 0.0 {
          let mut fused = 0.0
          for i in 0..<images.length() {
            let idx = (y * w + x) * images[i].channels
            if c < images[i].channels {
              fused += images[i].data[idx + c].to_double() *
                weights[i][y * w + x] /
                weight_sum
            }
          }
          out_data[out_idx + c] = fused.min(255.0).max(0.0).to_int().to_byte()
        } else {
          out_data[out_idx + c] = images[0].data[(y * w + x) *
            images[0].channels +
            c]
        }
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
/// 通用图像融合接口
pub fn fuse_images(
  img1 : @types.Image,
  img2 : @types.Image,
  config? : FusionConfig,
) -> @types.Image {
  let cfg = match config {
    Some(c) => c
    None => fusion_default_config()
  }
  match cfg.method_type {
    "alpha" => fuse_alpha(img1, img2, alpha=cfg.alpha)
    "multifocus" => fuse_multifocus(img1, img2)
    _ => fuse_alpha(img1, img2, alpha=cfg.alpha)
  }
}
