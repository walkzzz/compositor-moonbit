// 纯 MoonBit ICNS 编解码（全目标可用：native/wasm/js）
// ICNS 规范: https://en.wikipedia.org/wiki/Apple_Icon_Image_format
// 文件结构: "icns" + file_size(BE32) + chunks
// 每个 chunk: type_code(4B) + length(BE32, 含8B头) + data
// PNG 类型: ic07(128), ic08(256), ic09(512), ic10(1024),
//           ic11(16), ic12(32), ic13(64), ic14(256)
// ARGB 类型: ic04(16), ic05(32), icp6(64), icp7(128), icp8(256), icp9(512)

///|
/// ICNS chunk 信息
priv struct IcnsChunk {
  data_offset : Int
  data_size : Int
  icon_size : Int // 像素边长，0 表示非图标数据
  is_png : Bool
}

///|
/// 从 4 字节构造 type code 字符串
fn icns_type_to_string(data : Bytes, offset : Int) -> String {
  let buf : Array[Byte] = [
    data[offset],
    data[offset + 1],
    data[offset + 2],
    data[offset + 3],
  ]
  @encoding/utf8.decode(Bytes::from_array(buf)) catch {
    _ => "????"
  }
}

///|
/// 根据 type code 获取图标像素边长和是否 PNG
fn icns_icon_info(type_code : String) -> (Int, Bool) {
  match type_code {
    "ic07" => (128, true) // 128x128 PNG
    "ic08" => (256, true) // 256x256 PNG
    "ic09" => (512, true) // 512x512 PNG
    "ic10" => (1024, true) // 1024x1024 PNG
    "ic11" => (16, true) // 16x16 PNG
    "ic12" => (32, true) // 32x32 PNG
    "ic13" => (64, true) // 64x64 PNG
    "ic14" => (256, true) // 256x256 PNG
    "ic04" => (16, false) // 16x16 ARGB
    "ic05" => (32, false) // 32x32 ARGB
    "icp4" => (16, false) // 16x16 ARGB
    "icp5" => (32, false) // 32x32 ARGB
    "icp6" => (64, false) // 64x64 ARGB
    "icp7" => (128, false) // 128x128 ARGB
    "icp8" => (256, false) // 256x256 ARGB
    "icp9" => (512, false) // 512x512 ARGB
    _ => (0, false)
  }
}

///|
/// 根据像素边长选择最佳 type code（PNG 类型）
fn icns_size_to_type(size : Int) -> String {
  match size {
    16 => "ic11"
    32 => "ic12"
    64 => "ic13"
    128 => "ic07"
    256 => "ic08"
    512 => "ic09"
    1024 => "ic10"
    _ => "ic08" // 默认用 256x256
  }
}

///|
/// 解析 ICNS 文件，返回所有 chunk
fn parse_icns(data : Bytes) -> Array[IcnsChunk] raise @types.LoadError {
  let len = data.length()
  if len < 8 {
    raise @types.LoadError::DecodeFailed("ICNS 数据过短")
  }
  // 检查 magic "icns"
  if data[0].to_int() != 0x69 ||
    data[1].to_int() != 0x63 ||
    data[2].to_int() != 0x6E ||
    data[3].to_int() != 0x73 {
    raise @types.LoadError::DecodeFailed("ICNS magic 不匹配")
  }
  let file_size = read_u32_be(data, 4)
  let chunks : Array[IcnsChunk] = []
  let mut pos = 8
  let end = if file_size < len { file_size } else { len }
  while pos + 8 <= end {
    let type_code = icns_type_to_string(data, pos)
    let chunk_len = read_u32_be(data, pos + 4)
    if chunk_len < 8 || pos + chunk_len > end {
      break
    }
    let data_offset = pos + 8
    let data_size = chunk_len - 8
    let (icon_size, is_png) = icns_icon_info(type_code)
    chunks.push(IcnsChunk::{ data_offset, data_size, icon_size, is_png })
    pos += chunk_len
  }
  if chunks.length() == 0 {
    raise @types.LoadError::DecodeFailed("ICNS 无图标 chunk")
  }
  chunks
}

///|
/// 解码 ARGB 原始数据为 Image（BGRA → RGBA）
fn decode_icns_argb(
  data : Bytes,
  offset : Int,
  size : Int,
) -> @types.Image raise @types.LoadError {
  let len = data.length()
  let pixel_count = size * size
  if offset + pixel_count * 4 > len {
    raise @types.LoadError::DecodeFailed("ICNS ARGB 数据不完整")
  }
  let pixels : Array[Byte] = Array::make(pixel_count * 4, b'\x00')
  for i in 0..<pixel_count {
    let src = offset + i * 4
    let a = data[src].to_int()
    let r = data[src + 1].to_int()
    let g = data[src + 2].to_int()
    let b = data[src + 3].to_int()
    let dst = i * 4
    pixels[dst] = r.to_byte()
    pixels[dst + 1] = g.to_byte()
    pixels[dst + 2] = b.to_byte()
    pixels[dst + 3] = a.to_byte()
  }
  @types.Image::{
    width: size,
    height: size,
    channels: 4,
    data: Bytes::from_array(pixels),
  }
}

///|
/// 解码 ICNS 字节流为 Image（选择面积最大的图标）
/// 支持 PNG 子图像（ic07-ic14）和 ARGB 原始数据（ic04/ic05/icp4-9）
pub fn decode_icns_pure(data : Bytes) -> @types.Image raise @types.LoadError {
  let chunks = parse_icns(data)
  // 选择面积最大的图标 chunk
  let mut best_idx = 0
  let mut best_area = 0
  for i in 0..<chunks.length() {
    let area = chunks[i].icon_size * chunks[i].icon_size
    if area > best_area {
      best_area = area
      best_idx = i
    }
  }
  let chunk = chunks[best_idx]
  if chunk.icon_size == 0 {
    raise @types.LoadError::DecodeFailed("ICNS 无有效图标 chunk")
  }
  if chunk.is_png {
    // PNG 子图像
    let sub : Array[Byte] = []
    for i in 0..<chunk.data_size {
      sub.push(data[chunk.data_offset + i])
    }
    decode_png_pure(Bytes::from_array(sub))
  } else {
    // ARGB 原始数据
    decode_icns_argb(data, chunk.data_offset, chunk.icon_size)
  }
}

///|
/// 将单个 Image 编码为 ICNS 字节流（内嵌 PNG）
pub fn encode_icns_pure(img : @types.Image) -> Bytes {
  let png_data = encode_png_pure(img)
  let type_code = icns_size_to_type(img.width)
  let type_bytes = @encoding/utf8.encode(type_code)
  let chunk_data_size = png_data.length()
  let chunk_total_size = 8 + chunk_data_size
  let file_size = 8 + chunk_total_size
  let out : Array[Byte] = []
  // ICNS 文件头
  out.push(b'\x69') // 'i'
  out.push(b'\x63') // 'c'
  out.push(b'\x6E') // 'n'
  out.push(b'\x73') // 's'
  write_u32_be(out, file_size)
  // chunk 头
  for i in 0..<4 {
    out.push(type_bytes[i])
  }
  write_u32_be(out, chunk_total_size)
  // chunk 数据（PNG）
  for i in 0..<chunk_data_size {
    out.push(png_data[i])
  }
  Bytes::from_array(out)
}
