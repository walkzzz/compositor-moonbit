// 纯 MoonBit ICO/CUR 编解码（全目标可用：native/wasm/js）
// ICO 规范: https://en.wikipedia.org/wiki/ICO_(file_format)
// CUR 规范: 与 ICO 相同，但 type=2 且 ICONDIRENTRY 的 planes/bitcount 字段为热点坐标
// 子图像可为 BMP（无文件头，height 翻倍含 AND 掩码）或 PNG

///|
/// ICO/CUR 目录条目
priv struct IconDirEntry {
  width : Int
  height : Int
  byte_size : Int
  offset : Int
}

///|
/// 解析 ICO/CUR 目录条目，返回 (icon_type, entries)
fn parse_ico_header(
  data : Bytes,
) -> (Int, Array[IconDirEntry]) raise @types.LoadError {
  let len = data.length()
  if len < 6 {
    raise @types.LoadError::DecodeFailed("ICO/CUR 数据过短")
  }
  let icon_type = read_u16_le(data, 2)
  let count = read_u16_le(data, 4)
  if icon_type != 1 && icon_type != 2 {
    raise @types.LoadError::DecodeFailed("ICO/CUR type 无效")
  }
  if count == 0 {
    raise @types.LoadError::DecodeFailed("ICO/CUR 无图像条目")
  }
  if len < 6 + count * 16 {
    raise @types.LoadError::DecodeFailed("ICO/CUR 目录数据不完整")
  }
  let entries : Array[IconDirEntry] = []
  for i in 0..<count {
    let base = 6 + i * 16
    let w = data[base].to_int()
    let h = data[base + 1].to_int()
    let byte_size = read_u32_le(data, base + 8)
    let offset = read_u32_le(data, base + 12)
    entries.push(IconDirEntry::{
      width: if w == 0 {
        256
      } else {
        w
      },
      height: if h == 0 {
        256
      } else {
        h
      },
      byte_size,
      offset,
    })
  }
  (icon_type, entries)
}

///|
/// 从 ICO/CUR 中选择最佳条目（面积最大优先）
fn select_best_entry(entries : Array[IconDirEntry]) -> Int {
  let mut best_idx = 0
  let mut best_area = 0
  for i in 0..<entries.length() {
    let area = entries[i].width * entries[i].height
    if area > best_area {
      best_area = area
      best_idx = i
    }
  }
  best_idx
}

///|
/// 解码 BMP 子图像（ICO 内嵌，无文件头，height 翻倍）
fn decode_ico_bmp_subimage(
  data : Bytes,
  offset : Int,
  byte_size : Int,
) -> @types.Image raise @types.LoadError {
  let len = data.length()
  if offset + 40 > len {
    raise @types.LoadError::DecodeFailed("ICO BMP 子图像数据不完整")
  }
  let dib_size = read_u32_le(data, offset)
  if dib_size < 40 {
    raise @types.LoadError::DecodeFailed("ICO BMP DIB 头过短")
  }
  let width = read_u32_le(data, offset + 4)
  let height2 = read_u32_le(data, offset + 8)
  let bpp = read_u16_le(data, offset + 14)
  let compression = read_u32_le(data, offset + 16)
  if compression != 0 {
    raise @types.LoadError::DecodeFailed("ICO BMP 子图像不支持压缩")
  }
  let height = height2 / 2
  if width <= 0 || height <= 0 {
    raise @types.LoadError::DecodeFailed("ICO BMP 子图像尺寸无效")
  }
  let abs_w = if width < 0 { -width } else { width }
  let abs_h = if height < 0 { -height } else { height }
  let color_offset = offset + dib_size
  let bytes_per_pixel = bpp / 8
  let row_size = (abs_w * bytes_per_pixel + 3) / 4 * 4
  // AND 掩码：1 bit/pixel，每行 4 字节对齐
  let and_row_size = (abs_w + 31) / 32 * 4
  let out_channels = 4
  let pixel_count = abs_w * abs_h
  let pixels : Array[Byte] = Array::make(pixel_count * out_channels, b'\x00')
  // 色彩数据自下而上
  for file_row in 0..<abs_h {
    let out_row = abs_h - 1 - file_row
    let row_start = color_offset + file_row * row_size
    for x in 0..<abs_w {
      let px_off = row_start + x * bytes_per_pixel
      if px_off + bytes_per_pixel > len {
        raise @types.LoadError::DecodeFailed("ICO BMP 像素数据越界")
      }
      let b = data[px_off].to_int()
      let g = data[px_off + 1].to_int()
      let r = data[px_off + 2].to_int()
      let a = if bpp == 32 { data[px_off + 3].to_int() } else { 255 }
      let out_idx = (out_row * abs_w + x) * out_channels
      pixels[out_idx] = r.to_byte()
      pixels[out_idx + 1] = g.to_byte()
      pixels[out_idx + 2] = b.to_byte()
      pixels[out_idx + 3] = a.to_byte()
    }
  }
  // 处理 AND 掩码（1-bit 透明度），仅对非 32-bit 有效
  if bpp != 32 {
    let and_offset = color_offset + abs_h * row_size
    for file_row in 0..<abs_h {
      let out_row = abs_h - 1 - file_row
      let and_row_start = and_offset + file_row * and_row_size
      for x in 0..<abs_w {
        let byte_idx = x / 8
        let bit_idx = 7 - x % 8
        if and_row_start + byte_idx < len {
          let mask_byte = data[and_row_start + byte_idx].to_int()
          if ((mask_byte >> bit_idx) & 1) == 1 {
            let out_idx = (out_row * abs_w + x) * out_channels
            pixels[out_idx + 3] = b'\x00'
          }
        }
      }
    }
  }
  let _ = byte_size
  @types.Image::{
    width: abs_w,
    height: abs_h,
    channels: out_channels,
    data: Bytes::from_array(pixels),
  }
}

///|
/// 解码 ICO 字节流为 Image（选择面积最大的子图像）
/// 支持 BMP 子图像（24/32-bit）和 PNG 子图像
pub fn decode_ico_pure(data : Bytes) -> @types.Image raise @types.LoadError {
  let (icon_type, entries) = parse_ico_header(data)
  if icon_type != 1 {
    raise @types.LoadError::DecodeFailed("ICO type 应为 1")
  }
  let best = select_best_entry(entries)
  let entry = entries[best]
  let len = data.length()
  if entry.offset + entry.byte_size > len {
    raise @types.LoadError::DecodeFailed("ICO 子图像数据越界")
  }
  if is_png_signature(data, entry.offset) {
    // PNG 子图像：提取子字节流并委托 PNG 解码器
    let sub : Array[Byte] = []
    for i in 0..<entry.byte_size {
      sub.push(data[entry.offset + i])
    }
    decode_png_pure(Bytes::from_array(sub))
  } else {
    decode_ico_bmp_subimage(data, entry.offset, entry.byte_size)
  }
}

///|
/// 解码 CUR 字节流为 Image（选择面积最大的子图像）
pub fn decode_cur_pure(data : Bytes) -> @types.Image raise @types.LoadError {
  let (icon_type, entries) = parse_ico_header(data)
  if icon_type != 2 {
    raise @types.LoadError::DecodeFailed("CUR type 应为 2")
  }
  let best = select_best_entry(entries)
  let entry = entries[best]
  let len = data.length()
  if entry.offset + entry.byte_size > len {
    raise @types.LoadError::DecodeFailed("CUR 子图像数据越界")
  }
  if is_png_signature(data, entry.offset) {
    let sub : Array[Byte] = []
    for i in 0..<entry.byte_size {
      sub.push(data[entry.offset + i])
    }
    decode_png_pure(Bytes::from_array(sub))
  } else {
    decode_ico_bmp_subimage(data, entry.offset, entry.byte_size)
  }
}

///|
/// 将单个 Image 编码为 ICO 内嵌 BMP 子图像（32-bit BGRA + AND 掩码）
/// 返回 (子图像字节数组, 宽, 高)
fn encode_ico_bmp_subimage(img : @types.Image) -> (Array[Byte], Int, Int) {
  let width = img.width
  let height = img.height
  let channels = img.channels
  let data = img.data
  let out : Array[Byte] = []
  // BITMAPINFOHEADER (40 bytes)
  write_u32_le(out, 40) // biSize
  write_u32_le(out, width) // biWidth
  write_u32_le(out, height * 2) // biHeight = 2*h (XOR + AND)
  write_u16_le(out, 1) // biPlanes
  write_u16_le(out, 32) // biBitCount
  write_u32_le(out, 0) // biCompression = BI_RGB
  let xor_size = width * height * 4
  write_u32_le(out, xor_size) // biSizeImage
  write_u32_le(out, 0) // biXPelsPerMeter
  write_u32_le(out, 0) // biYPelsPerMeter
  write_u32_le(out, 0) // biClrUsed
  write_u32_le(out, 0) // biClrImportant
  // XOR 掩码：32-bit BGRA，自下而上
  for y in 0..<height {
    let ry = height - 1 - y
    let row_start = ry * width * channels
    for x in 0..<width {
      let idx = row_start + x * channels
      let r = data[idx].to_int()
      let g = if channels >= 2 { data[idx + 1].to_int() } else { r }
      let b = if channels >= 3 { data[idx + 2].to_int() } else { r }
      let a = if channels >= 4 { data[idx + 3].to_int() } else { 255 }
      out.push(b.to_byte())
      out.push(g.to_byte())
      out.push(r.to_byte())
      out.push(a.to_byte())
    }
  }
  // AND 掩码：1-bit/pixel，自下而上，每行 4 字节对齐
  let and_row_bytes = (width + 31) / 32 * 4
  for y in 0..<height {
    let ry = height - 1 - y
    let row_start = ry * width * channels
    let and_row : Array[Byte] = Array::make(and_row_bytes, b'\x00')
    for x in 0..<width {
      let idx = row_start + x * channels
      let a = if channels >= 4 { data[idx + 3].to_int() } else { 255 }
      // 透明像素 AND 掩码位置 1，不透明位置 0
      if a == 0 {
        let byte_idx = x / 8
        let bit_idx = 7 - x % 8
        and_row[byte_idx] = (and_row[byte_idx].to_int() | (1 << bit_idx)).to_byte()
      }
    }
    for i in 0..<and_row_bytes {
      out.push(and_row[i])
    }
  }
  (out, width, height)
}

///|
/// 将单个 Image 编码为 ICO 字节流（内嵌 32-bit BMP 子图像）
pub fn encode_ico_pure(img : @types.Image) -> Bytes {
  encode_ico_with_sizes_pure([img])
}

///|
/// 将多个尺寸的 Image 编码为多分辨率 ICO 字节流
pub fn encode_ico_with_sizes_pure(images : Array[@types.Image]) -> Bytes {
  let count = images.length()
  let out : Array[Byte] = []
  // ICONDIR (6 bytes)
  write_u16_le(out, 0) // reserved
  write_u16_le(out, 1) // type = ICO
  write_u16_le(out, count)
  // 先编码所有子图像，收集偏移和大小
  let subimages : Array[(Array[Byte], Int, Int)] = []
  for i in 0..<count {
    subimages.push(encode_ico_bmp_subimage(images[i]))
  }
  // 计算偏移：6 + count*16
  let dir_size = 6 + count * 16
  let mut offset = dir_size
  // 写入目录条目
  for i in 0..<count {
    let (sub, w, h) = subimages[i]
    let byte_size = sub.length()
    // ICONDIRENTRY (16 bytes)
    out.push((if w == 256 { 0 } else { w }).to_byte()) // width
    out.push((if h == 256 { 0 } else { h }).to_byte()) // height
    out.push(b'\x00') // colors (0 for >256 colors)
    out.push(b'\x00') // reserved
    write_u16_le(out, 1) // planes
    write_u16_le(out, 32) // bit count
    write_u32_le(out, byte_size)
    write_u32_le(out, offset)
    offset += byte_size
  }
  // 写入子图像数据
  for i in 0..<count {
    let (sub, _, _) = subimages[i]
    for j in 0..<sub.length() {
      out.push(sub[j])
    }
  }
  Bytes::from_array(out)
}

///|
/// 将单个 Image 编码为 CUR 字节流（内嵌 32-bit BMP 子图像，热点默认为中心）
pub fn encode_cur_pure(img : @types.Image) -> Bytes {
  encode_cur_with_hotspot_pure(img, img.width / 2, img.height / 2)
}

///|
/// 将单个 Image 编码为 CUR 字节流，指定热点坐标
pub fn encode_cur_with_hotspot_pure(
  img : @types.Image,
  hotspot_x : Int,
  hotspot_y : Int,
) -> Bytes {
  let out : Array[Byte] = []
  // ICONDIR (6 bytes)
  write_u16_le(out, 0) // reserved
  write_u16_le(out, 2) // type = CUR
  write_u16_le(out, 1) // count
  // 编码子图像
  let (sub, w, h) = encode_ico_bmp_subimage(img)
  let byte_size = sub.length()
  let offset = 6 + 16
  // ICONDIRENTRY (16 bytes)
  out.push((if w == 256 { 0 } else { w }).to_byte())
  out.push((if h == 256 { 0 } else { h }).to_byte())
  out.push(b'\x00') // colors
  out.push(b'\x00') // reserved
  write_u16_le(out, hotspot_x) // 热点 X
  write_u16_le(out, hotspot_y) // 热点 Y
  write_u32_le(out, byte_size)
  write_u32_le(out, offset)
  // 子图像数据
  for i in 0..<sub.length() {
    out.push(sub[i])
  }
  Bytes::from_array(out)
}
