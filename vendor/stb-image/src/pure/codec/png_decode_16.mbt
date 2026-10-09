// 纯 MoonBit PNG 16-bit 解码（全目标可用：native/wasm/js）
// 支持 8-bit PNG 上采样为 16-bit，以及原生 16-bit PNG
// 输出 Image16（little-endian uint16 per sample）

///|
/// PNG 16-bit 解码（纯 MoonBit，全目标可用）。
/// 支持 bit depth 8（上采样为 16-bit）和 16（原生）。
/// color type 0/2/3/4/6，不支持 interlace。
/// req_channels: 0/None=原色, 1=灰度, 2=灰度+alpha, 3=RGB, 4=RGBA
pub fn decode_png_16_pure(
  data : Bytes,
  req_channels? : Int? = None,
) -> @types.Image16 raise @types.LoadError {
  match req_channels {
    Some(n) =>
      if n < 1 || n > 4 {
        raise @types.LoadError::DecodeFailed("req_channels 必须为 1-4")
      }
    None => ()
  }
  let len = data.length()
  if len < 8 || !is_png_signature(data, 0) {
    raise @types.LoadError::DecodeFailed("PNG signature 错误")
  }
  let mut pos = 8
  let mut width = 0
  let mut height = 0
  let mut bit_depth = 0
  let mut color_type = 0
  let mut interlace = 0
  let palette : Array[(Int, Int, Int)] = []
  let idat_data : Array[Byte] = []
  let mut found_ihdr = false
  let mut found_iend = false
  while pos < len && !found_iend {
    if pos + 8 > len {
      raise @types.LoadError::DecodeFailed("PNG chunk 头部过短")
    }
    let chunk_len = read_u32_be(data, pos)
    let chunk_key = read_u32_be(data, pos + 4)
    pos += 8
    if pos + chunk_len > len {
      raise @types.LoadError::DecodeFailed("PNG chunk 数据越界")
    }
    match chunk_key {
      0x49484452 => {
        if chunk_len < 13 {
          raise @types.LoadError::DecodeFailed("PNG IHDR 过短")
        }
        width = read_u32_be(data, pos)
        height = read_u32_be(data, pos + 4)
        bit_depth = data[pos + 8].to_int()
        color_type = data[pos + 9].to_int()
        interlace = data[pos + 12].to_int()
        found_ihdr = true
      }
      0x504C5445 => {
        let num_colors = chunk_len / 3
        for i in 0..<num_colors {
          palette.push(
            (
              data[pos + i * 3].to_int(),
              data[pos + i * 3 + 1].to_int(),
              data[pos + i * 3 + 2].to_int(),
            ),
          )
        }
      }
      0x49444154 =>
        for i in 0..<chunk_len {
          idat_data.push(data[pos + i])
        }
      0x49454E44 => found_iend = true
      _ => ()
    }
    pos += chunk_len + 4
  }
  if !found_ihdr {
    raise @types.LoadError::DecodeFailed("PNG 无 IHDR chunk")
  }
  if width <= 0 || height <= 0 {
    raise @types.LoadError::DecodeFailed("PNG 尺寸无效")
  }
  if interlace != 0 {
    raise @types.LoadError::DecodeFailed("PNG interlace 不支持")
  }
  if bit_depth != 8 && bit_depth != 16 {
    raise @types.LoadError::DecodeFailed(
      "PNG 16-bit 解码仅支持 bit depth 8 或 16",
    )
  }
  let ch = match png_channels(color_type) {
    Some(c) => c
    None => raise @types.LoadError::DecodeFailed("PNG 无效 color type")
  }
  let raw = @util.zlib_inflate(Bytes::from_array(idat_data))
  // bytes per pixel for filtering
  let bpp = ch * (bit_depth / 8)
  let stride = width * bpp
  let unfiltered : Array[Byte] = Array::make(height * stride, b'\x00')
  let mut raw_pos = 0
  for y in 0..<height {
    if raw_pos >= raw.length() {
      raise @types.LoadError::DecodeFailed("PNG 解压数据过短")
    }
    let filter_type = raw[raw_pos].to_int()
    raw_pos += 1
    for x in 0..<stride {
      if raw_pos >= raw.length() {
        raise @types.LoadError::DecodeFailed("PNG 解压数据过短")
      }
      let raw_byte = raw[raw_pos].to_int()
      raw_pos += 1
      let a = if x >= bpp {
        unfiltered[y * stride + x - bpp].to_int()
      } else {
        0
      }
      let b = if y > 0 { unfiltered[(y - 1) * stride + x].to_int() } else { 0 }
      let c = if x >= bpp && y > 0 {
        unfiltered[(y - 1) * stride + x - bpp].to_int()
      } else {
        0
      }
      let val = match filter_type {
        0 => raw_byte
        1 => (raw_byte + a) & 0xFF
        2 => (raw_byte + b) & 0xFF
        3 => (raw_byte + (a + b) / 2) & 0xFF
        4 => (raw_byte + paeth_predict(a, b, c)) & 0xFF
        _ => raise @types.LoadError::DecodeFailed("PNG 无效 filter type")
      }
      unfiltered[y * stride + x] = val.to_byte()
    }
  }
  // 转换为 16-bit samples (little-endian)
  let pixel_count = width * height
  let out_ch = match req_channels {
    Some(n) => n
    None => ch
  }
  // 先提取原生 16-bit samples
  let samples16 : Array[Int] = Array::make(pixel_count * ch, 0)
  if bit_depth == 16 {
    // big-endian → native int
    for i in 0..<(pixel_count * ch) {
      let hi = unfiltered[i * 2].to_int()
      let lo = unfiltered[i * 2 + 1].to_int()
      samples16[i] = hi * 256 + lo
    }
  } else {
    // 8-bit → upscale: v * 257
    for i in 0..<(pixel_count * ch) {
      samples16[i] = unfiltered[i].to_int() * 257
    }
  }
  // 通道转换
  let out_data : Array[Byte] = Array::make(pixel_count * out_ch * 2, b'\x00')
  for i in 0..<pixel_count {
    let (r16, g16, b16, a16) = if ch == 1 {
      let v = samples16[i]
      (v, v, v, 65535)
    } else if ch == 2 {
      let v = samples16[i * 2]
      let a = samples16[i * 2 + 1]
      (v, v, v, a)
    } else if ch == 3 {
      (samples16[i * 3], samples16[i * 3 + 1], samples16[i * 3 + 2], 65535)
    } else {
      (
        samples16[i * 4],
        samples16[i * 4 + 1],
        samples16[i * 4 + 2],
        samples16[i * 4 + 3],
      )
    }
    let (or16, og16, ob16, oa16) = match out_ch {
      1 => {
        let gray = (r16 * 299 + g16 * 587 + b16 * 114) / 1000
        (gray, gray, gray, 65535)
      }
      2 => {
        let gray = (r16 * 299 + g16 * 587 + b16 * 114) / 1000
        (gray, gray, gray, a16)
      }
      3 => (r16, g16, b16, 65535)
      _ => (r16, g16, b16, a16)
    }
    // little-endian uint16
    out_data[i * out_ch * 2] = (or16 & 0xFF).to_byte()
    out_data[i * out_ch * 2 + 1] = ((or16 >> 8) & 0xFF).to_byte()
    if out_ch >= 2 {
      out_data[i * out_ch * 2 + 2] = (og16 & 0xFF).to_byte()
      out_data[i * out_ch * 2 + 3] = ((og16 >> 8) & 0xFF).to_byte()
    }
    if out_ch >= 3 {
      out_data[i * out_ch * 2 + 4] = (ob16 & 0xFF).to_byte()
      out_data[i * out_ch * 2 + 5] = ((ob16 >> 8) & 0xFF).to_byte()
    }
    if out_ch >= 4 {
      out_data[i * out_ch * 2 + 6] = (oa16 & 0xFF).to_byte()
      out_data[i * out_ch * 2 + 7] = ((oa16 >> 8) & 0xFF).to_byte()
    }
  }
  @types.Image16::{
    width,
    height,
    channels: out_ch,
    data: Bytes::from_array(out_data),
  }
}
