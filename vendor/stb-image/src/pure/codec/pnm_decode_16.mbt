// 纯 MoonBit PNM 16-bit 解码器
// 支持 P5（PGM 16-bit 灰度）和 P6（PPM 16-bit RGB）
// maxval ≥ 256 时为 16-bit（big-endian uint16 per sample）

///|
/// 解码 PNM 字节流为 Image16
/// 支持 P5（PGM 16-bit 灰度，channels=1）和 P6（PPM 16-bit RGB，channels=3）
/// maxval ≥ 256 时为 16-bit（big-endian），maxval < 256 时上采样为 16-bit
pub fn decode_pnm_16_pure(
  data : Bytes,
) -> @types.Image16 raise @types.LoadError {
  let len = data.length()
  if len < 2 {
    raise @types.LoadError::DecodeFailed("PNM 数据过短")
  }
  let magic0 = data[0].to_int()
  let magic1 = data[1].to_int()
  if !(magic0 == 0x50 && (magic1 == 0x35 || magic1 == 0x36)) {
    raise @types.LoadError::DecodeFailed(
      "不支持的 PNM magic，仅支持 P5 和 P6",
    )
  }
  let channels = if magic1 == 0x36 { 3 } else { 1 }
  let pos = Ref(2)
  pnm_skip_ws_and_comments(data, pos, len)
  let width = pnm_read_ascii_int(data, pos, len)
  pnm_skip_ws_and_comments(data, pos, len)
  let height = pnm_read_ascii_int(data, pos, len)
  pnm_skip_ws_and_comments(data, pos, len)
  let maxval = pnm_read_ascii_int(data, pos, len)
  if maxval <= 0 {
    raise @types.LoadError::DecodeFailed("PNM maxval 无效")
  }
  if width <= 0 || height <= 0 {
    raise @types.LoadError::DecodeFailed("PNM 尺寸无效")
  }
  if pos.val >= len {
    raise @types.LoadError::DecodeFailed(
      "PNM 像素数据起始 whitespace 缺失",
    )
  }
  let sep = data[pos.val].to_int()
  if !pnm_is_whitespace(sep) {
    raise @types.LoadError::DecodeFailed("PNM maxval 后分隔符无效")
  }
  pos.val += 1
  @types.check_dims(width, height, channels)
  let pixel_count = width * height
  let is_16bit = maxval >= 256
  let out_data : Array[Byte] = Array::make(pixel_count * channels * 2, b'\x00')
  if is_16bit {
    let pixel_bytes = pixel_count * channels * 2
    if pos.val + pixel_bytes > len {
      raise @types.LoadError::DecodeFailed("PNM 16-bit 像素数据不足")
    }
    // big-endian → little-endian
    for i in 0..<(pixel_count * channels) {
      let hi = data[pos.val + i * 2].to_int()
      let lo = data[pos.val + i * 2 + 1].to_int()
      out_data[i * 2] = lo.to_byte()
      out_data[i * 2 + 1] = hi.to_byte()
    }
  } else {
    let pixel_bytes = pixel_count * channels
    if pos.val + pixel_bytes > len {
      raise @types.LoadError::DecodeFailed("PNM 像素数据不足")
    }
    // 8-bit → upscale: v * 257
    for i in 0..<pixel_bytes {
      let v = data[pos.val + i].to_int() * 257
      out_data[i * 2] = (v & 0xFF).to_byte()
      out_data[i * 2 + 1] = ((v >> 8) & 0xFF).to_byte()
    }
  }
  @types.Image16::{ width, height, channels, data: Bytes::from_array(out_data) }
}
