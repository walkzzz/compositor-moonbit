// 图像混合与翻转（纯 MoonBit）

///|
/// Alpha 混合两张图像。
/// alpha: 0.0 = 完全显示 img1, 1.0 = 完全显示 img2
/// 要求两张图像尺寸和通道数相同。
pub fn alpha_blend(
  img1 : @types.Image,
  img2 : @types.Image,
  alpha : Float,
) -> @types.Image raise @types.LoadError {
  if img1.width != img2.width || img1.height != img2.height {
    raise @types.LoadError::DecodeFailed("alpha_blend: 图像尺寸不同")
  }
  if img1.channels != img2.channels {
    raise @types.LoadError::DecodeFailed("alpha_blend: 图像通道数不同")
  }
  let n = img1.width * img1.height * img1.channels
  let result : Array[Byte] = []
  let a = alpha.clamp(min=0.0F, max=1.0F)
  for i in 0..<n {
    let v1 = img1.data[i].to_int()
    let v2 = img2.data[i].to_int()
    let blended = (Float::from_int(v1) * (1.0F - a) + Float::from_int(v2) * a).to_int()
    result.push(blended.clamp(min=0, max=255).to_byte())
  }
  @types.Image::{
    width: img1.width,
    height: img1.height,
    channels: img1.channels,
    data: Bytes::from_array(result),
  }
}

///|
/// 使用掩码混合两张图像。
/// 掩码为单通道灰度图，白色（255）显示 img2，黑色（0）显示 img1。
/// 要求掩码与图像尺寸相同。
pub fn mask_blend(
  img1 : @types.Image,
  img2 : @types.Image,
  mask : @types.Image,
) -> @types.Image raise @types.LoadError {
  if img1.width != img2.width || img1.height != img2.height {
    raise @types.LoadError::DecodeFailed("mask_blend: 图像尺寸不同")
  }
  if img1.channels != img2.channels {
    raise @types.LoadError::DecodeFailed("mask_blend: 图像通道数不同")
  }
  if mask.channels != 1 {
    raise @types.LoadError::DecodeFailed("mask_blend: 掩码必须为单通道")
  }
  if mask.width != img1.width || mask.height != img1.height {
    raise @types.LoadError::DecodeFailed("mask_blend: 掩码尺寸不同")
  }
  let w = img1.width
  let h = img1.height
  let ch = img1.channels
  let result : Array[Byte] = []
  for y in 0..<h {
    for x in 0..<w {
      let m = Float::from_int(mask.data[y * w + x].to_int()) / 255.0F
      for c in 0..<ch {
        let idx = (y * w + x) * ch + c
        let v1 = img1.data[idx].to_int()
        let v2 = img2.data[idx].to_int()
        let blended = (Float::from_int(v1) * (1.0F - m) +
        Float::from_int(v2) * m).to_int()
        result.push(blended.clamp(min=0, max=255).to_byte())
      }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(result),
  }
}

///|
/// 水平翻转图像。
pub fn flip_horizontal(img : @types.Image) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let result : Array[Byte] = []
  for y in 0..<h {
    for x in 0..<w {
      let src_x = w - 1 - x
      for c in 0..<ch {
        result.push(img.data[(y * w + src_x) * ch + c])
      }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(result),
  }
}

///|
/// 垂直翻转图像。
pub fn flip_vertical(img : @types.Image) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let result : Array[Byte] = []
  for y in 0..<h {
    let src_y = h - 1 - y
    for x in 0..<w {
      for c in 0..<ch {
        result.push(img.data[(src_y * w + x) * ch + c])
      }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(result),
  }
}
