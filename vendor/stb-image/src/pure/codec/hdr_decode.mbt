// 纯 MoonBit HDR 解码（全目标可用：native/wasm/js）
// RGBE 格式解析，支持 RLE 和未压缩扫描线
// 仅依赖 @types，不依赖 @core/FFI

///|
/// 将 RGBE 4 字节转换为 3 个 float 值
fn rgbe_to_float(
  r : Byte,
  g : Byte,
  b : Byte,
  e : Byte,
) -> (Float, Float, Float) {
  let e_int = e.to_int()
  if e_int == 0 {
    return (0.0F, 0.0F, 0.0F)
  }
  let exp = @math.powf(2.0F, Float::from_int(e_int - 128)) / 256.0F
  (
    Float::from_int(r.to_int()) * exp,
    Float::from_int(g.to_int()) * exp,
    Float::from_int(b.to_int()) * exp,
  )
}

///|
/// 将 float 3 通道转换为 RGBE 4 字节
fn float_to_rgbe(r : Float, g : Float, b : Float) -> (Byte, Byte, Byte, Byte) {
  let max_v = if r > g { r } else { g }
  let max_v = if max_v > b { max_v } else { b }
  if max_v < 0.0000000001F {
    return (b'\x00', b'\x00', b'\x00', b'\x00')
  }
  let log_max = @math.lnf(max_v) / @math.lnf(2.0F)
  let exp = log_max.to_int() + 128
  let exp = if exp < 0 { 0 } else if exp > 255 { 255 } else { exp }
  let scale = @math.powf(2.0F, Float::from_int(exp - 128 - 8))
  let ri = (r * scale + 0.5F).to_int().clamp(min=0, max=255)
  let gi = (g * scale + 0.5F).to_int().clamp(min=0, max=255)
  let bi = (b * scale + 0.5F).to_int().clamp(min=0, max=255)
  (ri.to_byte(), gi.to_byte(), bi.to_byte(), exp.to_byte())
}

///|
/// 解析 HDR 头部，返回 (width, height, data_start_offset)
fn parse_hdr_header(data : Bytes) -> (Int, Int, Int)? {
  let len = data.length()
  // 检查 magic "#?"
  if len < 2 || data[0].to_int() != 0x23 || data[1].to_int() != 0x3F {
    return None
  }
  // 跳过 magic 行和注释行
  let mut pos = 2
  // 跳过到第一个换行
  while pos < len && data[pos].to_int() != 0x0A {
    pos += 1
  }
  pos += 1
  // 跳过 header 行（非尺寸行），尺寸行以 '-' 或 '+' 开头
  while pos < len {
    let b = data[pos].to_int()
    if b == 0x2D || b == 0x2B {
      // '-' 或 '+'，尺寸行开始
      break
    }
    // 跳过当前行到行尾
    while pos < len && data[pos].to_int() != 0x0A {
      pos += 1
    }
    pos += 1
  }
  // 解析尺寸行: "-Y HEIGHT +X WIDTH\n" 或 "+X WIDTH -Y HEIGHT\n"
  let mut sign = 1
  let mut current_val = 0
  let mut has_digit = false
  let vals : Array[Int] = []
  let signs : Array[Int] = []
  while pos < len && data[pos].to_int() != 0x0A {
    let b = data[pos].to_int()
    if b == 0x2D {
      // '-'
      sign = -1
    } else if b == 0x2B {
      // '+'
      sign = 1
    } else if b >= 0x30 && b <= 0x39 {
      // digit
      current_val = current_val * 10 + (b - 0x30)
      has_digit = true
    } else if has_digit {
      vals.push(current_val * sign)
      signs.push(sign)
      current_val = 0
      has_digit = false
      sign = 1
    }
    pos += 1
  }
  if has_digit {
    vals.push(current_val * sign)
    signs.push(sign)
  }
  pos += 1
  // vals 应该有 2 个值，一个是 Y（height），一个是 X（width）
  if vals.length() < 2 {
    return None
  }
  let (width, height) = if signs[0] < 0 && signs[1] > 0 {
    (vals[1].abs(), vals[0].abs())
  } else if signs[0] > 0 && signs[1] < 0 {
    (vals[0].abs(), vals[1].abs())
  } else {
    (vals[0].abs(), vals[1].abs())
  }
  if width <= 0 || height <= 0 {
    return None
  }
  Some((width, height, pos))
}

///|
/// RLE 解码单个通道扫描线
fn rle_decode_scanline_channel(
  data : Bytes,
  pos : Int,
  len : Int,
  scanline_len : Int,
) -> (Array[Byte], Int)? {
  let out : Array[Byte] = []
  let mut p = pos
  while out.length() < scanline_len {
    if p >= len {
      return None
    }
    let code = data[p].to_int()
    p += 1
    if code > 128 {
      // RLE: 重复
      let count = code - 128
      if p >= len {
        return None
      }
      let val = data[p]
      p += 1
      for _ in 0..<count {
        out.push(val)
      }
    } else {
      // 非 RLE: 逐个读取
      let count = code
      if p + count > len {
        return None
      }
      for i in 0..<count {
        out.push(data[p + i])
      }
      p += count
    }
  }
  if out.length() != scanline_len {
    return None
  }
  Some((out, p))
}

///|
/// HDR 解码（纯 MoonBit，全目标可用）。
/// 返回 ImageF（32-bit float 像素数据）。
pub fn decode_hdr_pure(data : Bytes) -> @types.ImageF raise @types.LoadError {
  let (width, height, data_start) = match parse_hdr_header(data) {
    Some(v) => v
    None => raise @types.LoadError::DecodeFailed("invalid HDR header")
  }
  let len = data.length()
  @types.check_dims(width, height, 3)
  let pixel_count = width * height
  // RGBE 数据：每像素 4 字节
  let rgbe : Array[Byte] = Array::make(pixel_count * 4, b'\x00')
  let mut pos = data_start
  // 检查是否为 RLE 编码
  let is_rle = pos + 4 <= len &&
    data[pos].to_int() == 2 &&
    data[pos + 1].to_int() == 2 &&
    data[pos + 2].to_int() * 256 + data[pos + 3].to_int() == width
  if is_rle {
    // RLE 解码：每行 4 通道分别 RLE 编码
    for y in 0..<height {
      // 检查行头 [2, 2, hi, lo]
      if pos + 4 > len || data[pos].to_int() != 2 || data[pos + 1].to_int() != 2 {
        raise @types.LoadError::DecodeFailed("invalid RLE scanline header")
      }
      let scanline_w = data[pos + 2].to_int() * 256 + data[pos + 3].to_int()
      pos += 4
      if scanline_w != width {
        raise @types.LoadError::DecodeFailed("scanline width mismatch")
      }
      // 4 通道分别解码
      for c in 0..<4 {
        let (channel_data, new_pos) = match
          rle_decode_scanline_channel(data, pos, len, width) {
          Some(v) => v
          None => raise @types.LoadError::DecodeFailed("RLE decode failed")
        }
        pos = new_pos
        for x in 0..<width {
          rgbe[(y * width + x) * 4 + c] = channel_data[x]
        }
      }
    }
  } else {
    // 未压缩：逐像素读取 RGBE
    if pos + pixel_count * 4 > len {
      raise @types.LoadError::DecodeFailed("insufficient uncompressed HDR data")
    }
    for i in 0..<(pixel_count * 4) {
      rgbe[i] = data[pos + i]
    }
  }
  // RGBE → float
  let float_data : Array[Byte] = Array::make(pixel_count * 3 * 4, b'\x00')
  for i in 0..<pixel_count {
    let (r, g, b) = rgbe_to_float(
      rgbe[i * 4],
      rgbe[i * 4 + 1],
      rgbe[i * 4 + 2],
      rgbe[i * 4 + 3],
    )
    // 写入 little-endian float
    let r_bytes = r.to_le_bytes()
    let g_bytes = g.to_le_bytes()
    let b_bytes = b.to_le_bytes()
    float_data[i * 12] = r_bytes[0]
    float_data[i * 12 + 1] = r_bytes[1]
    float_data[i * 12 + 2] = r_bytes[2]
    float_data[i * 12 + 3] = r_bytes[3]
    float_data[i * 12 + 4] = g_bytes[0]
    float_data[i * 12 + 5] = g_bytes[1]
    float_data[i * 12 + 6] = g_bytes[2]
    float_data[i * 12 + 7] = g_bytes[3]
    float_data[i * 12 + 8] = b_bytes[0]
    float_data[i * 12 + 9] = b_bytes[1]
    float_data[i * 12 + 10] = b_bytes[2]
    float_data[i * 12 + 11] = b_bytes[3]
  }
  @types.ImageF::{
    width,
    height,
    channels: 3,
    data: Bytes::from_array(float_data),
  }
}
