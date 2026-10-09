// 纯 MoonBit 图像信息查询（全目标可用：native/wasm/js）
// 仅依赖 @types，不依赖 @core/FFI
// 通过解析各格式头部获取 width/height/channels，不加载像素数据

///|
fn info_read_u32_be(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() * 16777216 +
  data[offset + 1].to_int() * 65536 +
  data[offset + 2].to_int() * 256 +
  data[offset + 3].to_int()
}

///|
fn info_read_u32_le(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() +
  data[offset + 1].to_int() * 256 +
  data[offset + 2].to_int() * 65536 +
  data[offset + 3].to_int() * 16777216
}

///|
fn info_read_u16_be(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() * 256 + data[offset + 1].to_int()
}

///|
fn info_read_u16_le(data : Bytes, offset : Int) -> Int {
  data[offset].to_int() + data[offset + 1].to_int() * 256
}

///|
/// 从 BMP 头部读取信息
fn info_bmp(data : Bytes) -> @types.ImageInfo? {
  if data.length() < 30 {
    return None
  }
  let width = info_read_u32_le(data, 18)
  let height = info_read_u32_le(data, 22)
  let bpp = info_read_u16_le(data, 28)
  let channels = bpp / 8
  if width <= 0 || height <= 0 || channels <= 0 {
    return None
  }
  Some(@types.ImageInfo::{ width, height: height.abs(), channels })
}

///|
/// 从 QOI 头部读取信息
fn info_qoi(data : Bytes) -> @types.ImageInfo? {
  if data.length() < 14 {
    return None
  }
  let width = info_read_u32_be(data, 4)
  let height = info_read_u32_be(data, 8)
  let channels = data[12].to_int()
  if width <= 0 || height <= 0 || channels <= 0 {
    return None
  }
  Some(@types.ImageInfo::{ width, height, channels })
}

///|
/// 从 PSD 头部读取信息
fn info_psd(data : Bytes) -> @types.ImageInfo? {
  if data.length() < 16 {
    return None
  }
  let channels = info_read_u16_be(data, 4)
  let height = info_read_u32_be(data, 6)
  let width = info_read_u32_be(data, 10)
  if width <= 0 || height <= 0 || channels <= 0 {
    return None
  }
  Some(@types.ImageInfo::{ width, height, channels })
}

///|
/// 从 GIF 头部读取信息
fn info_gif(data : Bytes) -> @types.ImageInfo? {
  if data.length() < 10 {
    return None
  }
  let width = info_read_u16_le(data, 6)
  let height = info_read_u16_le(data, 8)
  if width <= 0 || height <= 0 {
    return None
  }
  Some(@types.ImageInfo::{ width, height, channels: 3 })
}

///|
/// 从 PNG 头部读取信息（IHDR chunk）
fn info_png(data : Bytes) -> @types.ImageInfo? {
  // PNG signature: 8 bytes
  // IHDR: length(4) + "IHDR"(4) + width(4) + height(4) + bit_depth(1) + color_type(1) + ...
  // width at offset 16, height at offset 20
  if data.length() < 26 {
    return None
  }
  // 验证 PNG signature
  if data[0].to_int() != 0x89 ||
    data[1].to_int() != 0x50 ||
    data[2].to_int() != 0x4E ||
    data[3].to_int() != 0x47 {
    return None
  }
  let width = info_read_u32_be(data, 16)
  let height = info_read_u32_be(data, 20)
  let bit_depth = data[24].to_int()
  let color_type = data[25].to_int()
  let channels = match color_type {
    0 => 1 // gray
    2 => 3 // rgb
    3 => 1 // palette (indexed)
    4 => 2 // gray + alpha
    6 => 4 // rgba
    _ => return None
  }
  if width <= 0 || height <= 0 || bit_depth <= 0 {
    return None
  }
  Some(@types.ImageInfo::{ width, height, channels })
}

///|
/// 从 JPEG 头部读取信息（解析 SOF marker）
fn info_jpeg(data : Bytes) -> @types.ImageInfo? {
  let len = data.length()
  if len < 4 || data[0].to_int() != 0xFF || data[1].to_int() != 0xD8 {
    return None
  }
  // 扫描 markers 寻找 SOF (0xFF 0xC0-0xCF, 排除 C4/C8/CC)
  let mut pos = 2
  while pos + 1 < len {
    if data[pos].to_int() != 0xFF {
      pos += 1
      continue
    }
    let marker = data[pos + 1].to_int()
    // SOF markers: C0, C1, C2, C3, C5, C6, C7, C9, CA, CB, CD, CE, CF
    // 排除 C4 (DHT), C8 (JPG), CC (DAC)
    if marker >= 0xC0 &&
      marker <= 0xCF &&
      marker != 0xC4 &&
      marker != 0xC8 &&
      marker != 0xCC {
      // SOF: length(2) + precision(1) + height(2) + width(2) + channels(1)
      if pos + 9 >= len {
        return None
      }
      let height = info_read_u16_be(data, pos + 5)
      let width = info_read_u16_be(data, pos + 7)
      let channels = data[pos + 9].to_int()
      if width <= 0 || height <= 0 || channels <= 0 {
        return None
      }
      return Some(@types.ImageInfo::{ width, height, channels })
    }
    // 跳过其他 marker
    if pos + 3 >= len {
      return None
    }
    let seg_len = info_read_u16_be(data, pos + 2)
    pos += 2 + seg_len
  }
  None
}

///|
/// 从 PNM 头部读取信息（P5/P6 二进制格式）
fn info_pnm(data : Bytes) -> @types.ImageInfo? {
  let len = data.length()
  if len < 4 {
    return None
  }
  // P5: gray (1ch), P6: rgb (3ch)
  let channels = match data[1].to_int() {
    0x35 => 1 // P5
    0x36 => 3 // P6
    _ => return None
  }
  // 解析 ASCII header: P5/P6 + whitespace + width + whitespace + height + whitespace + maxval
  let mut pos = 2
  // 跳过空白和注释
  fn skip_ws_comments(data : Bytes, pos : Int, len : Int) -> Int {
    let mut p = pos
    while p < len {
      let b = data[p].to_int()
      if b == 0x23 {
        // # 注释行，跳过到行尾
        while p < len && data[p].to_int() != 0x0A {
          p += 1
        }
        p += 1
      } else if b == 0x20 || b == 0x0A || b == 0x0D || b == 0x09 {
        p += 1
      } else {
        break
      }
    }
    p
  }
  fn read_ascii_int(data : Bytes, pos : Int, len : Int) -> (Int, Int)? {
    let mut p = pos
    let mut val = 0
    let mut has_digit = false
    while p < len {
      let b = data[p].to_int()
      if b >= 0x30 && b <= 0x39 {
        val = val * 10 + (b - 0x30)
        has_digit = true
        p += 1
      } else {
        break
      }
    }
    if has_digit {
      Some((val, p))
    } else {
      None
    }
  }
  pos = skip_ws_comments(data, pos, len)
  let (width, pos2) = match read_ascii_int(data, pos, len) {
    Some(v) => v
    None => return None
  }
  pos = skip_ws_comments(data, pos2, len)
  let (height, _) = match read_ascii_int(data, pos, len) {
    Some(v) => v
    None => return None
  }
  if width <= 0 || height <= 0 {
    return None
  }
  Some(@types.ImageInfo::{ width, height, channels })
}

///|
/// 检测是否为 HDR 格式（magic: "#?RADIANCE" 或 "#?RGBE"）
pub fn is_hdr_from_bytes_pure(data : Bytes) -> Bool {
  let len = data.length()
  if len < 2 || data[0].to_int() != 0x23 || data[1].to_int() != 0x3F {
    return false
  }
  // 检查 "#?RADIANCE" 或 "#?RGBE"
  let radiance = [
    b'\x52', b'\x41', b'\x44', b'\x49', b'\x41', b'\x4E', b'\x43', b'\x45',
  ]
  let rgbe = [b'\x52', b'\x47', b'\x42', b'\x45']
  if len >= 10 {
    let mut match_radiance = true
    for i in 0..<8 {
      if data[2 + i] != radiance[i] {
        match_radiance = false
        break
      }
    }
    if match_radiance {
      return true
    }
  }
  if len >= 6 {
    let mut match_rgbe = true
    for i in 0..<4 {
      if data[2 + i] != rgbe[i] {
        match_rgbe = false
        break
      }
    }
    if match_rgbe {
      return true
    }
  }
  false
}

///|
/// 检测是否为 16-bit 图像（仅 PNG 支持 16-bit）
pub fn is_16_bit_from_bytes_pure(data : Bytes) -> Bool {
  let len = data.length()
  if len < 26 {
    return false
  }
  // 检查 PNG signature
  if data[0].to_int() != 0x89 ||
    data[1].to_int() != 0x50 ||
    data[2].to_int() != 0x4E ||
    data[3].to_int() != 0x47 {
    return false
  }
  // PNG bit depth 在 IHDR chunk 的 offset 24
  data[24].to_int() == 16
}

///|
/// 从字节流读取图像信息（纯 MoonBit，全目标可用）。
/// 支持 BMP/QOI/PSD/GIF/PNG/JPEG/PNM(HDR 检测但不解析尺寸)。
/// 返回 None 如果格式不支持或数据无效。
pub fn info_from_bytes_pure(
  data : Bytes,
) -> @types.ImageInfo? raise @types.LoadError {
  if data.length() == 0 {
    raise @types.LoadError::DecodeFailed("输入数据为空")
  }
  // BMP
  if data.length() >= 2 && data[0].to_int() == 0x42 && data[1].to_int() == 0x4D {
    return info_bmp(data)
  }
  // QOI
  if data.length() >= 4 &&
    data[0].to_int() == 0x71 &&
    data[1].to_int() == 0x6F &&
    data[2].to_int() == 0x69 &&
    data[3].to_int() == 0x66 {
    return info_qoi(data)
  }
  // PSD
  if data.length() >= 4 &&
    data[0].to_int() == 0x38 &&
    data[1].to_int() == 0x42 &&
    data[2].to_int() == 0x50 &&
    data[3].to_int() == 0x53 {
    return info_psd(data)
  }
  // GIF
  if data.length() >= 6 &&
    data[0].to_int() == 0x47 &&
    data[1].to_int() == 0x49 &&
    data[2].to_int() == 0x46 {
    return info_gif(data)
  }
  // PNG
  if data.length() >= 8 &&
    data[0].to_int() == 0x89 &&
    data[1].to_int() == 0x50 &&
    data[2].to_int() == 0x4E &&
    data[3].to_int() == 0x47 {
    return info_png(data)
  }
  // JPEG
  if data.length() >= 2 && data[0].to_int() == 0xFF && data[1].to_int() == 0xD8 {
    return info_jpeg(data)
  }
  // PNM (P5/P6)
  if data.length() >= 2 && data[0].to_int() == 0x50 {
    let p = data[1].to_int()
    if p == 0x35 || p == 0x36 {
      return info_pnm(data)
    }
  }
  None
}

///|
/// 纯 MoonBit 错误原因字符串（全目标可用）。
/// 返回上次解码失败的错误描述。
pub fn failure_reason_pure() -> String {
  "pure MoonBit decoder error"
}
