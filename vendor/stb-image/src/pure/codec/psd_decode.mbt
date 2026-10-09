// 纯 MoonBit PSD 解码器
// 支持 8-bit RGB（channelCount=3）/ RGBA（channelCount=4）、无压缩（compression=0）
// 大端序字节流，按通道排列像素数据交错为 RGBRGBRGB
// 规范: Adobe Photoshop PSD File Format + stb_image.h:6126-6280 stbi__psd_load

///|
/// 解码 PSD 字节流为 Image
/// 支持 8-bit RGB（channelCount=3）/ RGBA（channelCount=4）、无压缩（compression=0）
/// Header(26 字节) + Color mode data + Image resources + Layer and mask data + Image data
/// 像素数据按通道排列（RRRGGGBBB），交错为 Image.data 格式（RGBRGBRGB）
pub fn decode_psd_pure(data : Bytes) -> @types.Image raise @types.LoadError {
  let len = data.length()
  // Header 26 字节
  if len < 26 {
    raise @types.LoadError::DecodeFailed(
      "PSD 数据过短：无法读取完整 header",
    )
  }
  // signature "8BPS" (0x38 0x42 0x50 0x53)
  if data[0].to_int() != 0x38 ||
    data[1].to_int() != 0x42 ||
    data[2].to_int() != 0x50 ||
    data[3].to_int() != 0x53 {
    raise @types.LoadError::DecodeFailed("PSD signature 错误，非 \"8BPS\"")
  }
  // version (2 字节 BE)，必须为 1
  let version = read_u16_be(data, 4)
  if version != 1 {
    raise @types.LoadError::DecodeFailed("PSD version 错误，仅支持 1")
  }
  // reserved(6 字节) 跳过
  // channelCount (2 字节 BE)
  let channel_count = read_u16_be(data, 12)
  if channel_count != 3 && channel_count != 4 {
    raise @types.LoadError::DecodeFailed(
      "不支持的 PSD channelCount，仅支持 3（RGB）和 4（RGBA）",
    )
  }
  // h (4 字节 BE)
  let h = read_u32_be(data, 14)
  // w (4 字节 BE)
  let w = read_u32_be(data, 18)
  // bitdepth (2 字节 BE)，仅支持 8
  let bitdepth = read_u16_be(data, 22)
  if bitdepth != 8 {
    raise @types.LoadError::DecodeFailed(
      "不支持的 PSD bitdepth，仅支持 8",
    )
  }
  // colorMode (2 字节 BE)，仅支持 3（RGB）
  let color_mode = read_u16_be(data, 24)
  if color_mode != 3 {
    raise @types.LoadError::DecodeFailed(
      "不支持的 PSD colorMode，仅支持 3（RGB）",
    )
  }
  // 尺寸校验
  if w == 0 || h == 0 {
    raise @types.LoadError::DecodeFailed("PSD 尺寸无效")
  }
  // 跳过 3 个 length 前缀段（color mode data / image resources / layer and mask data）
  let mut pos = 26
  for _ in 0..<3 {
    if pos + 4 > len {
      raise @types.LoadError::DecodeFailed(
        "PSD 数据过短：无法读取 4 字节 BE",
      )
    }
    let seg_len = read_u32_be(data, pos)
    pos += 4
    if pos + seg_len > len {
      raise @types.LoadError::DecodeFailed("PSD 段数据越界")
    }
    pos += seg_len
  }
  // Image data: compression (2 字节 BE)
  if pos + 2 > len {
    raise @types.LoadError::DecodeFailed(
      "PSD 数据过短：无法读取 2 字节 BE",
    )
  }
  let compression = read_u16_be(data, pos)
  pos += 2
  if compression != 0 {
    raise @types.LoadError::DecodeFailed(
      "不支持的 PSD compression，仅支持 0（无压缩）",
    )
  }
  // 像素数据：按通道排列，每通道 w*h 字节
  let pixel_count = w * h
  let pixel_bytes = channel_count * pixel_count
  if pos + pixel_bytes > len {
    raise @types.LoadError::DecodeFailed("PSD 像素数据不足")
  }
  // 交错：data[i * channel_count + c] = raw[c * w * h + i]
  let interleaved : Array[Byte] = Array::make(pixel_bytes, b'\x00')
  for c in 0..<channel_count {
    let channel_base = c * pixel_count
    for i in 0..<pixel_count {
      interleaved[i * channel_count + c] = data[pos + channel_base + i]
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: channel_count,
    data: Bytes::from_array(interleaved),
  }
}
