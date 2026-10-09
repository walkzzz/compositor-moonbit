// 纯 MoonBit PNM 解码器
// 支持 P5（PGM 二进制灰度，channels=1）和 P6（PPM 二进制 RGB，channels=3）
// 仅支持 8-bit（maxval < 256），不支持 16-bit（maxval ≥ 256）
// 规范: https://netpbm.sourceforge.net/doc/pgm.html / ppm.html

///|
fn pnm_is_whitespace(b : Int) -> Bool {
  b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D
}

///|
fn pnm_skip_ws_and_comments(data : Bytes, pos : Ref[Int], len : Int) -> Unit {
  while pos.val < len {
    let b = data[pos.val].to_int()
    if pnm_is_whitespace(b) {
      pos.val += 1
    } else if b == 0x23 {
      // '#' 注释行，跳过至行尾（LF）
      while pos.val < len && data[pos.val].to_int() != 0x0A {
        pos.val += 1
      }
      // 跳过 LF 本身
      if pos.val < len {
        pos.val += 1
      }
    } else {
      break
    }
  }
}

///|
fn pnm_read_ascii_int(
  data : Bytes,
  pos : Ref[Int],
  len : Int,
) -> Int raise @types.LoadError {
  let start = pos.val
  while pos.val < len {
    let b = data[pos.val].to_int()
    if b >= 0x30 && b <= 0x39 {
      pos.val += 1
    } else {
      break
    }
  }
  if pos.val == start {
    raise @types.LoadError::DecodeFailed("PNM header 数字解析失败")
  }
  let mut result = 0
  for i in start..<pos.val {
    result = result * 10 + (data[i].to_int() - 0x30)
  }
  result
}

///|
/// 解码 PNM 字节流为 Image
/// 支持 P5（PGM 二进制灰度，channels=1）和 P6（PPM 二进制 RGB，channels=3）
/// 仅支持 8-bit（maxval < 256），不支持 16-bit（maxval ≥ 256）
/// Header: magic(2 字节) + whitespace + width(ASCII) + whitespace + height(ASCII) + whitespace + maxval(ASCII) + 单 whitespace + 像素
/// 注释行（# 开头至行尾）可出现在 magic 后 header 任意位置
pub fn decode_pnm_pure(data : Bytes) -> @types.Image raise @types.LoadError {
  let len = data.length()
  if len < 2 {
    raise @types.LoadError::DecodeFailed("PNM 数据过短")
  }
  let magic0 = data[0].to_int()
  let magic1 = data[1].to_int()
  // 仅支持 P5 和 P6
  if !(magic0 == 0x50 && (magic1 == 0x35 || magic1 == 0x36)) {
    raise @types.LoadError::DecodeFailed(
      "不支持的 PNM magic，仅支持 P5 和 P6",
    )
  }
  let channels = if magic1 == 0x36 { 3 } else { 1 }
  let pos = Ref(2)
  // 读取 width
  pnm_skip_ws_and_comments(data, pos, len)
  let width = pnm_read_ascii_int(data, pos, len)
  // 读取 height
  pnm_skip_ws_and_comments(data, pos, len)
  let height = pnm_read_ascii_int(data, pos, len)
  // 读取 maxval
  pnm_skip_ws_and_comments(data, pos, len)
  let maxval = pnm_read_ascii_int(data, pos, len)
  // 仅支持 8-bit（maxval < 256）
  if maxval >= 256 {
    raise @types.LoadError::DecodeFailed(
      "不支持的 PNM maxval，仅支持 8-bit（maxval < 256）",
    )
  }
  if maxval <= 0 {
    raise @types.LoadError::DecodeFailed("PNM maxval 无效")
  }
  // 尺寸校验
  if width <= 0 || height <= 0 {
    raise @types.LoadError::DecodeFailed("PNM 尺寸无效")
  }
  // maxval 后恰好 1 个 whitespace
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
  // 像素数据
  @types.check_dims(width, height, channels)
  let pixel_count = width * height
  let pixel_bytes = pixel_count * channels
  if pos.val + pixel_bytes > len {
    raise @types.LoadError::DecodeFailed("PNM 像素数据不足")
  }
  let pixels : Array[Byte] = Array::make(pixel_bytes, b'\x00')
  for i in 0..<pixel_bytes {
    pixels[i] = data[pos.val + i]
  }
  @types.Image::{ width, height, channels, data: Bytes::from_array(pixels) }
}
