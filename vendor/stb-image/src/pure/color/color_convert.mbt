// 纯 MoonBit 色彩模型转换（全目标可用：native/wasm/js）
// 仅依赖 @types，不依赖 @core/FFI
// 移植自 src/process/color/color_convert.mbt:1-162 的 5 个 8-bit Image 色彩转换函数

///|
/// 转为灰度图（channels=1，纯 MoonBit，全目标可用）
/// 使用 ITU-R BT.601 亮度公式: Y = 0.299R + 0.587G + 0.114B
pub fn to_grayscale_pure(img : @types.Image) -> @types.Image {
  if img.channels == 1 {
    return img
  }
  let pixel_count = img.width * img.height
  let ch = img.channels
  let data_int : Array[Int] = Array::make(pixel_count * ch, 0)
  for i in 0..<(pixel_count * ch) {
    data_int[i] = img.data[i].to_int()
  }
  let out : Array[Byte] = Array::make(pixel_count, b'\x00')
  for i in 0..<pixel_count {
    let r = data_int[i * ch]
    let g = data_int[i * ch + 1]
    let b = data_int[i * ch + 2]
    let gray = (r * 299 + g * 587 + b * 114) / 1000
    out[i] = gray.to_byte()
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// 去除 alpha 通道（RGBA → RGB，channels=3，纯 MoonBit，全目标可用）
pub fn to_rgb_pure(img : @types.Image) -> @types.Image {
  if img.channels == 3 {
    return img
  }
  if img.channels < 3 {
    return img
  }
  let pixel_count = img.width * img.height
  let out : Array[Byte] = Array::make(pixel_count * 3, b'\x00')
  for i in 0..<pixel_count {
    out[i * 3] = img.data[i * img.channels]
    out[i * 3 + 1] = img.data[i * img.channels + 1]
    out[i * 3 + 2] = img.data[i * img.channels + 2]
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: 3,
    data: Bytes::from_array(out),
  }
}

///|
/// 添加 alpha 通道（RGB → RGBA，channels=4，alpha=255，纯 MoonBit，全目标可用）
pub fn to_rgba_pure(img : @types.Image) -> @types.Image {
  if img.channels == 4 {
    return img
  }
  let pixel_count = img.width * img.height
  let out : Array[Byte] = Array::make(pixel_count * 4, b'\x00')
  for i in 0..<pixel_count {
    let src_ch = img.channels
    out[i * 4] = img.data[i * src_ch]
    out[i * 4 + 1] = if src_ch >= 2 {
      img.data[i * src_ch + 1]
    } else {
      b'\x00'
    }
    out[i * 4 + 2] = if src_ch >= 3 {
      img.data[i * src_ch + 2]
    } else {
      b'\x00'
    }
    out[i * 4 + 3] = b'\xFF'
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: 4,
    data: Bytes::from_array(out),
  }
}

///|
/// 按 stb_image 语义转换通道数（纯 MoonBit，全目标可用）
/// - 1: 灰度（BT.601 亮度公式）
/// - 2: 灰度 + alpha（alpha=255 若源无 alpha）
/// - 3: RGB（丢弃 alpha，灰度展开为 R=G=B）
/// - 4: RGBA（alpha=255 若源无 alpha，灰度展开为 R=G=B）
pub fn convert_channels_pure(
  img : @types.Image,
  req_channels : Int,
) -> @types.Image raise @types.LoadError {
  if req_channels == img.channels {
    return img
  }
  let pixel_count = img.width * img.height
  let src_ch = img.channels
  match req_channels {
    1 => to_grayscale_pure(img)
    2 => {
      let out : Array[Byte] = Array::make(pixel_count * 2, b'\x00')
      for i in 0..<pixel_count {
        let gray = if src_ch >= 3 {
          let r = img.data[i * src_ch].to_int()
          let g = img.data[i * src_ch + 1].to_int()
          let b = img.data[i * src_ch + 2].to_int()
          (r * 299 + g * 587 + b * 114) / 1000
        } else {
          img.data[i * src_ch].to_int()
        }
        let alpha = if src_ch == 2 || src_ch == 4 {
          img.data[i * src_ch + src_ch - 1].to_int()
        } else {
          255
        }
        out[i * 2] = gray.to_byte()
        out[i * 2 + 1] = alpha.to_byte()
      }
      @types.Image::{
        width: img.width,
        height: img.height,
        channels: 2,
        data: Bytes::from_array(out),
      }
    }
    3 =>
      if src_ch == 1 {
        let out : Array[Byte] = Array::make(pixel_count * 3, b'\x00')
        for i in 0..<pixel_count {
          let v = img.data[i]
          out[i * 3] = v
          out[i * 3 + 1] = v
          out[i * 3 + 2] = v
        }
        @types.Image::{
          width: img.width,
          height: img.height,
          channels: 3,
          data: Bytes::from_array(out),
        }
      } else {
        to_rgb_pure(img)
      }
    4 => to_rgba_pure(img)
    _ => raise @types.LoadError::DecodeFailed("不支持的 req_channels 值")
  }
}

///|
/// 预乘 alpha（RGBA → RGBA premultiplied，纯 MoonBit，全目标可用）
/// 要求 channels=4
pub fn premultiply_alpha_pure(
  img : @types.Image,
) -> @types.Image raise @types.LoadError {
  if img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "premultiply_alpha_pure 需要 channels=4 (RGBA)",
    )
  }
  let pixel_count = img.width * img.height
  let data_int : Array[Int] = Array::make(pixel_count * 4, 0)
  for i in 0..<(pixel_count * 4) {
    data_int[i] = img.data[i].to_int()
  }
  let out : Array[Byte] = Array::make(pixel_count * 4, b'\x00')
  for i in 0..<pixel_count {
    let r = data_int[i * 4]
    let g = data_int[i * 4 + 1]
    let b = data_int[i * 4 + 2]
    let a = data_int[i * 4 + 3]
    out[i * 4] = (r * a / 255).to_byte()
    out[i * 4 + 1] = (g * a / 255).to_byte()
    out[i * 4 + 2] = (b * a / 255).to_byte()
    out[i * 4 + 3] = a.to_byte()
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: 4,
    data: Bytes::from_array(out),
  }
}

///|
/// 反预乘 alpha（RGBA premA → RGBA unpremultiplied，纯 MoonBit，全目标可用）
/// 要求 channels=4
pub fn unpremultiply_alpha_pure(
  img : @types.Image,
) -> @types.Image raise @types.LoadError {
  if img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "unpremultiply_alpha_pure 需要 channels=4 (RGBA)",
    )
  }
  let pixel_count = img.width * img.height
  let data_int : Array[Int] = Array::make(pixel_count * 4, 0)
  for i in 0..<(pixel_count * 4) {
    data_int[i] = img.data[i].to_int()
  }
  let out : Array[Byte] = Array::make(pixel_count * 4, b'\x00')
  for i in 0..<pixel_count {
    let r = data_int[i * 4]
    let g = data_int[i * 4 + 1]
    let b = data_int[i * 4 + 2]
    let a = data_int[i * 4 + 3]
    if a == 0 {
      out[i * 4] = b'\x00'
      out[i * 4 + 1] = b'\x00'
      out[i * 4 + 2] = b'\x00'
      out[i * 4 + 3] = b'\x00'
    } else {
      out[i * 4] = (r * 255 / a).to_byte()
      out[i * 4 + 1] = (g * 255 / a).to_byte()
      out[i * 4 + 2] = (b * 255 / a).to_byte()
      out[i * 4 + 3] = a.to_byte()
    }
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: 4,
    data: Bytes::from_array(out),
  }
}
