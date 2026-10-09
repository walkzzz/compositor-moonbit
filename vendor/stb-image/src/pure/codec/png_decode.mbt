// 纯 MoonBit PNG 解码（全目标可用：native/wasm/js）
// 依赖 @pure/zlib 进行 IDAT 解压缩
// 支持 color type 0/2/3/4/6, bit depth 8/16

///|
/// PNG 颜色类型对应的通道数
fn png_channels(color_type : Int) -> Int? {
  match color_type {
    0 => Some(1) // gray
    2 => Some(3) // rgb
    3 => Some(1) // palette
    4 => Some(2) // gray + alpha
    6 => Some(4) // rgba
    _ => None
  }
}

///|
/// Paeth 预测函数
fn paeth_predict(a : Int, b : Int, c : Int) -> Int {
  let p = a + b - c
  let pa = (p - a).abs()
  let pb = (p - b).abs()
  let pc = (p - c).abs()
  if pa <= pb && pa <= pc {
    a
  } else if pb <= pc {
    b
  } else {
    c
  }
}

///|
/// PNG 解码（纯 MoonBit，全目标可用）。
/// 支持 8-bit gray/RGB/RGBA/gray+alpha/palette。
/// 不支持 interlace。
/// req_channels: None=原色（保留 alpha）, 1=灰度, 2=灰度+alpha, 3=RGB, 4=RGBA
pub fn decode_png_pure(
  data : Bytes,
  req_channels? : Int? = None,
) -> @types.Image raise @types.LoadError {
  let len = data.length()
  // 验证 PNG signature
  if len < 8 || !is_png_signature(data, 0) {
    raise @types.LoadError::DecodeFailed("PNG signature 错误")
  }
  let mut pos = 8
  // 解析 chunks
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
    if chunk_len < 0 {
      raise @types.LoadError::DecodeFailed("PNG chunk 长度无效")
    }
    let chunk_key = read_u32_be(data, pos + 4)
    pos += 8
    if pos + chunk_len > len {
      raise @types.LoadError::DecodeFailed("PNG chunk 数据越界")
    }
    match chunk_key {
      0x49484452 => {
        // IHDR
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
        // PLTE
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
        // IDAT
        for i in 0..<chunk_len {
          idat_data.push(data[pos + i])
        }
      0x49454E44 =>
        // IEND
        found_iend = true
      _ => ()
    }
    pos += chunk_len + 4 // skip data + CRC
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
  if bit_depth != 8 {
    raise @types.LoadError::DecodeFailed("PNG 仅支持 8-bit bit depth")
  }
  let ch = match png_channels(color_type) {
    Some(c) => c
    None => raise @types.LoadError::DecodeFailed("PNG 无效 color type")
  }
  @types.check_dims(width, height, ch)
  // zlib inflate IDAT 数据
  let raw = @util.zlib_inflate(Bytes::from_array(idat_data))
  // unfilter scanlines
  let bpp = ch // bytes per pixel (8-bit)
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
        0 => raw_byte // None
        1 => (raw_byte + a) & 0xFF // Sub
        2 => (raw_byte + b) & 0xFF // Up
        3 => (raw_byte + (a + b) / 2) & 0xFF // Average
        4 => (raw_byte + paeth_predict(a, b, c)) & 0xFF // Paeth
        _ => raise @types.LoadError::DecodeFailed("PNG 无效 filter type")
      }
      unfiltered[y * stride + x] = val.to_byte()
    }
  }
  // 转换为 Image（保留 alpha，根据 req_channels 决定输出通道数）
  let pixel_count = width * height
  let out_ch = match req_channels {
    Some(n) => n
    None => ch // 默认保留原色（含 alpha）
  }
  if color_type == 3 && palette.length() == 0 {
    raise @types.LoadError::DecodeFailed("PNG palette 缺失")
  }
  let out_data : Array[Byte] = Array::make(pixel_count * out_ch, b'\x00')
  for i in 0..<pixel_count {
    let (r, g, b, a) = match color_type {
      3 => {
        // palette
        let idx = unfiltered[i].to_int()
        if idx >= palette.length() {
          raise @types.LoadError::DecodeFailed("PNG palette 索引越界")
        }
        let (r, g, b) = palette[idx]
        (r, g, b, 255)
      }
      0 => {
        // gray
        let v = unfiltered[i].to_int()
        (v, v, v, 255)
      }
      2 =>
        // RGB
        (
          unfiltered[i * 3].to_int(),
          unfiltered[i * 3 + 1].to_int(),
          unfiltered[i * 3 + 2].to_int(),
          255,
        )
      4 => {
        // gray + alpha
        let v = unfiltered[i * 2].to_int()
        let a = unfiltered[i * 2 + 1].to_int()
        (v, v, v, a)
      }
      _ =>
        // RGBA
        (
          unfiltered[i * 4].to_int(),
          unfiltered[i * 4 + 1].to_int(),
          unfiltered[i * 4 + 2].to_int(),
          unfiltered[i * 4 + 3].to_int(),
        )
    }
    let (or, og, ob, oa) = match out_ch {
      1 => {
        let gray = (r * 299 + g * 587 + b * 114) / 1000
        (gray, gray, gray, 255)
      }
      2 => {
        let gray = (r * 299 + g * 587 + b * 114) / 1000
        (gray, gray, gray, a)
      }
      3 => (r, g, b, 255)
      _ => (r, g, b, a)
    }
    match out_ch {
      1 => out_data[i] = or.to_byte()
      2 => {
        out_data[i * 2] = or.to_byte()
        out_data[i * 2 + 1] = oa.to_byte()
      }
      3 => {
        out_data[i * 3] = or.to_byte()
        out_data[i * 3 + 1] = og.to_byte()
        out_data[i * 3 + 2] = ob.to_byte()
      }
      _ => {
        out_data[i * 4] = or.to_byte()
        out_data[i * 4 + 1] = og.to_byte()
        out_data[i * 4 + 2] = ob.to_byte()
        out_data[i * 4 + 3] = oa.to_byte()
      }
    }
  }
  @types.Image::{
    width,
    height,
    channels: out_ch,
    data: Bytes::from_array(out_data),
  }
}
