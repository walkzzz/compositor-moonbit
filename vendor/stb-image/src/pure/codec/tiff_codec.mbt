// 纯 MoonBit TIFF 编解码（全目标可用：native/wasm/js）
// 支持无压缩 (Compression=1) 和 LZW 压缩 (Compression=5) TIFF
// 支持 8-bit 灰度、8-bit RGB、8-bit RGBA
// 规范: https://www.itu.int/rec/dologin.asp?lang=e&id=T-81-199303-I!!1-E

///|
/// TIFF IFD 条目
priv struct TiffIfdEntry {
  tag : Int
  type_id : Int
  count : Int
  value_or_offset : Int
}

///|
/// TIFF 解析上下文
priv struct TiffContext {
  data : Bytes
  little_endian : Bool
}

///|
/// 读取 16-bit 值（根据字节序）
fn tiff_read_u16(ctx : TiffContext, offset : Int) -> Int {
  if ctx.little_endian {
    read_u16_le(ctx.data, offset)
  } else {
    read_u16_be(ctx.data, offset)
  }
}

///|
/// 读取 32-bit 值（根据字节序）
fn tiff_read_u32(ctx : TiffContext, offset : Int) -> Int {
  if ctx.little_endian {
    read_u32_le(ctx.data, offset)
  } else {
    read_u32_be(ctx.data, offset)
  }
}

///|
/// 根据 type_id 和 count 计算 IFD 条目值的字节数
fn tiff_type_size(type_id : Int) -> Int {
  match type_id {
    1 => 1 // BYTE
    2 => 1 // ASCII
    3 => 2 // SHORT
    4 => 4 // LONG
    5 => 8 // RATIONAL
    6 => 1 // SBYTE
    7 => 1 // UNDEFINED
    8 => 2 // SSHORT
    9 => 4 // SLONG
    10 => 8 // SRATIONAL
    11 => 4 // FLOAT
    12 => 8 // DOUBLE
    _ => 0
  }
}

///|
/// 读取 IFD 条目的数值数组（当值超过 4 字节时从偏移处读取）
fn tiff_read_values(ctx : TiffContext, entry : TiffIfdEntry) -> Array[Int] {
  let total_bytes = tiff_type_size(entry.type_id) * entry.count
  let values : Array[Int] = []
  if total_bytes <= 4 {
    // 值内联在 value_or_offset 中
    let v = entry.value_or_offset
    match entry.type_id {
      1 | 7 =>
        for i in 0..<entry.count {
          values.push((v >> (i * 8)) & 0xFF)
        }
      3 =>
        for i in 0..<entry.count {
          values.push((v >> (i * 16)) & 0xFFFF)
        }
      4 => values.push(v)
      _ =>
        for _ in 0..<entry.count {
          values.push(0)
        }
    }
  } else {
    // 值在偏移处
    let base = entry.value_or_offset
    let len = ctx.data.length()
    match entry.type_id {
      1 | 7 =>
        for i in 0..<entry.count {
          if base + i < len {
            values.push(ctx.data[base + i].to_int())
          } else {
            values.push(0)
          }
        }
      3 =>
        for i in 0..<entry.count {
          values.push(tiff_read_u16(ctx, base + i * 2))
        }
      4 =>
        for i in 0..<entry.count {
          values.push(tiff_read_u32(ctx, base + i * 4))
        }
      _ =>
        for _ in 0..<entry.count {
          values.push(0)
        }
    }
  }
  values
}

///|
/// 解析 IFD 条目
fn tiff_parse_ifd(
  ctx : TiffContext,
  ifd_offset : Int,
) -> Array[TiffIfdEntry] raise @types.LoadError {
  let len = ctx.data.length()
  if ifd_offset + 2 > len {
    raise @types.LoadError::DecodeFailed("TIFF IFD 偏移越界")
  }
  let count = tiff_read_u16(ctx, ifd_offset)
  if ifd_offset + 2 + count * 12 > len {
    raise @types.LoadError::DecodeFailed("TIFF IFD 条目数据不完整")
  }
  let entries : Array[TiffIfdEntry] = []
  for i in 0..<count {
    let base = ifd_offset + 2 + i * 12
    let tag = tiff_read_u16(ctx, base)
    let type_id = tiff_read_u16(ctx, base + 2)
    let cnt = tiff_read_u32(ctx, base + 4)
    let val_or_off = tiff_read_u32(ctx, base + 8)
    entries.push(TiffIfdEntry::{
      tag,
      type_id,
      count: cnt,
      value_or_offset: val_or_off,
    })
  }
  entries
}

///|
/// 在 IFD 条目中查找指定 tag 的值数组
fn tiff_get_values(
  entries : Array[TiffIfdEntry],
  ctx : TiffContext,
  tag : Int,
) -> Array[Int]? {
  for i in 0..<entries.length() {
    if entries[i].tag == tag {
      return Some(tiff_read_values(ctx, entries[i]))
    }
  }
  None
}

///|
/// 在 IFD 条目中查找指定 tag 的单个值
fn tiff_get_value(
  entries : Array[TiffIfdEntry],
  ctx : TiffContext,
  tag : Int,
) -> Int? {
  match tiff_get_values(entries, ctx, tag) {
    Some(arr) => if arr.length() > 0 { Some(arr[0]) } else { None }
    None => None
  }
}

// ==================== LZW 解码器 ====================

///|
/// 解码 TIFF LZW 压缩的字节流
pub fn tiff_lzw_decode(data : Bytes) -> Array[Byte] raise @types.LoadError {
  let len = data.length()
  if len < 2 {
    raise @types.LoadError::DecodeFailed("TIFF LZW 数据过短")
  }
  let init_code_len = data[0].to_int()
  if init_code_len < 2 || init_code_len > 11 {
    raise @types.LoadError::DecodeFailed("TIFF LZW 初始码长无效")
  }
  let clear_code = 1 << init_code_len
  let eoi_code = clear_code + 1
  let dict : Array[Int] = Array::make(512, 0)
  for i in 0..<=255 {
    dict[i] = i
  }
  let mut next_code = clear_code + 2
  let mut bit_pos = 8
  let data_len = data.length()

  fn read_bits(data : Bytes, pos : Int, count : Int, len : Int) -> (Int, Int) {
    let mut code : Int = 0
    let mut p = pos
    let mut i : Int = 0
    while i < count && p < len * 8 {
      let byte_idx = p / 8
      let bit_offset = p % 8
      if byte_idx < len {
        let bit = (data[byte_idx].to_int() >> bit_offset) & 1
        code = code | (bit << i)
      }
      p += 1
      i += 1
    }
    (code, p)
  }

  // 读取 CLEAR 码并推进 bit_pos
  let (code, new_bit_pos) = read_bits(data, 8, init_code_len + 1, data_len)
  bit_pos = new_bit_pos
  if code != clear_code {
    raise @types.LoadError::DecodeFailed("TIFF LZW 首码应为 CLEAR")
  }

  let output : Array[Byte] = []
  let mut prev_code : Int = 0
  let mut code_len = init_code_len
  let mut done = false

  while !done {
    let (c, new_pos) = read_bits(data, bit_pos, code_len + 1, data_len)
    bit_pos = new_pos

    if c == eoi_code {
      done = true
    } else if c == clear_code {
      for j in 0..<=255 {
        dict[j] = j
      }
      next_code = clear_code + 2
      code_len = init_code_len
    } else if c < next_code {
      // 输出 c 对应的字符串
      if c <= 255 {
        output.push(c.to_byte())
      } else {
        // 回溯字典获取字符串
        let k = c
        let path : Array[Int] = [k]
        let mut current = dict[k]
        while current >= clear_code &&
              current < next_code &&
              path.length() < 512 {
          path.push(current)
          current = dict[current]
        }
        // 手动反转输出
        let mut i = path.length()
        while i > 0 {
          i -= 1
          output.push(path[i].to_byte())
        }
        if current <= 255 {
          output.push(current.to_byte())
        }
      }
      // 更新字典
      if next_code < 4096 {
        dict[next_code] = prev_code
        next_code += 1
      }
      prev_code = c
    } else {
      raise @types.LoadError::DecodeFailed("TIFF LZW 码越界")
    }
  }
  output
}

///|
/// 解码 TIFF PackBits 压缩的字节流
pub fn tiff_packbits_decode(data : Bytes) -> Array[Byte] raise @types.LoadError {
  let len = data.length()
  let mut pos : Int = 0
  let output : Array[Byte] = []

  while pos < len {
    let count = data[pos].to_int()
    pos += 1
    let signed_count : Int = if count > 127 { count - 256 } else { count }

    if signed_count == -128 {
      // Extended PackBits
      if pos + 1 >= len {
        raise @types.LoadError::DecodeFailed(
          "TIFF PackBits 扩展模式数据不足",
        )
      }
      let extended_count = ((data[pos].to_int() << 8) | data[pos + 1].to_int()) -
        32768
      pos += 2
      if extended_count >= 0 {
        // 复制 extended_count + 1 个字节
        let n = extended_count + 1
        let mut i = 0
        while i < n && pos < len {
          output.push(data[pos])
          pos += 1
          i += 1
        }
      } else {
        // 重复下一个字节
        if pos >= len {
          raise @types.LoadError::DecodeFailed(
            "TIFF PackBits 扩展模式数据不足",
          )
        }
        let repeat_byte = data[pos]
        pos += 1
        let n = -extended_count + 1
        let mut i = 0
        while i < n {
          output.push(repeat_byte)
          i += 1
        }
      }
    } else if signed_count >= 0 {
      // 复制 count + 1 个字节
      let n = signed_count + 1
      let mut i = 0
      while i < n && pos < len {
        output.push(data[pos])
        pos += 1
        i += 1
      }
    } else {
      // 重复下一个字节 (-signed_count + 1) 次
      let repeat_count = -signed_count + 1
      if pos >= len {
        raise @types.LoadError::DecodeFailed("TIFF PackBits 数据不足")
      }
      let repeat_byte = data[pos]
      pos += 1
      let mut i = 0
      while i < repeat_count {
        output.push(repeat_byte)
        i += 1
      }
    }
  }
  output
}

///|
/// 解码 TIFF 字节流为 Image
/// 支持无压缩 (Compression=1) 和 LZW 压缩 (Compression=5) 8-bit 灰度/RGB/RGBA
pub fn decode_tiff_pure(data : Bytes) -> @types.Image raise @types.LoadError {
  let len = data.length()
  if len < 8 {
    raise @types.LoadError::DecodeFailed("TIFF 数据过短")
  }
  // 检查字节序
  let little_endian = match data[0].to_int() {
    0x49 => true // 'I' = little-endian
    0x4D => false // 'M' = big-endian
    _ => raise @types.LoadError::DecodeFailed("TIFF 字节序标记无效")
  }
  let ctx = TiffContext::{ data, little_endian }
  // 检查 magic 42
  let magic = tiff_read_u16(ctx, 2)
  if magic != 42 {
    raise @types.LoadError::DecodeFailed("TIFF magic 无效")
  }
  let ifd_offset = tiff_read_u32(ctx, 4)
  if ifd_offset < 0 || ifd_offset >= len {
    raise @types.LoadError::DecodeFailed("TIFF IFD 偏移无效")
  }
  let entries = tiff_parse_ifd(ctx, ifd_offset)
  // 读取必要字段
  let width = match tiff_get_value(entries, ctx, 256) {
    Some(w) => w
    None => raise @types.LoadError::DecodeFailed("TIFF 缺少 ImageWidth")
  }
  let height = match tiff_get_value(entries, ctx, 257) {
    Some(h) => h
    None => raise @types.LoadError::DecodeFailed("TIFF 缺少 ImageLength")
  }
  let bits_per_sample = match tiff_get_values(entries, ctx, 258) {
    Some(arr) => arr
    None => [8]
  }
  let compression = match tiff_get_value(entries, ctx, 259) {
    Some(c) => c
    None => 1
  }
  let photometric = match tiff_get_value(entries, ctx, 262) {
    Some(p) => p
    None => 1
  }
  let samples_per_pixel = match tiff_get_value(entries, ctx, 277) {
    Some(s) => s
    None => 1
  }
  let strip_offsets = match tiff_get_values(entries, ctx, 273) {
    Some(arr) => arr
    None => raise @types.LoadError::DecodeFailed("TIFF 缺少 StripOffsets")
  }
  let rows_per_strip = match tiff_get_value(entries, ctx, 278) {
    Some(r) => r
    None => height
  }
  let strip_byte_counts = match tiff_get_values(entries, ctx, 279) {
    Some(arr) => arr
    None => []
  }
  // 支持无压缩、LZW、PackBits 和 Deflate 压缩
  if compression != 1 &&
    compression != 5 &&
    compression != 32773 &&
    compression != 8 {
    raise @types.LoadError::DecodeFailed(
      "TIFF 仅支持无压缩 (Compression=1)、LZW (5)、PackBits (32773) 和 Deflate (8)",
    )
  }
  // 仅支持 8-bit
  for i in 0..<bits_per_sample.length() {
    if bits_per_sample[i] != 8 {
      raise @types.LoadError::DecodeFailed("TIFF 仅支持 8-bit 样本")
    }
  }
  if width <= 0 || height <= 0 {
    raise @types.LoadError::DecodeFailed("TIFF 尺寸无效")
  }
  // 确定输出 channels
  let out_channels = samples_per_pixel
  if out_channels != 1 && out_channels != 3 && out_channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "TIFF 仅支持 1/3/4 samples per pixel",
    )
  }
  @types.check_dims(width, height, out_channels)
  // 读取像素数据（支持 LZW/PackBits 解压）
  let pixel_count = width * height
  let pixels : Array[Byte] = Array::make(pixel_count * out_channels, b'\x00')
  let bytes_per_pixel = out_channels
  // 如果使用了压缩，先解压所有 strip 数据
  let decompressed : Bytes = if compression == 5 {
    // LZW 解压：逐 strip 读取并解码
    let all_data : Array[Byte] = []
    let mut strip_idx : Int = 0
    while strip_idx < strip_offsets.length() {
      let strip_offset = strip_offsets[strip_idx]
      let byte_count = if strip_idx < strip_byte_counts.length() {
        strip_byte_counts[strip_idx]
      } else {
        width * height * out_channels - all_data.length()
      }
      // 手动提取 strip 数据（Bytes 无 slice 方法，逐字节取）
      let strip_data : Bytes = {
        let tmp : Array[Byte] = []
        let mut i = strip_offset
        let end = i + byte_count
        while i < end {
          if i < len {
            tmp.push(ctx.data[i])
          }
          i += 1
        }
        Bytes::from_array(tmp)
      }
      let decoded = tiff_lzw_decode(strip_data)
      // 手动拼接（Array 无 concat 方法，逐元素 push）
      for d in decoded {
        all_data.push(d)
      }
      strip_idx += 1
    }
    Bytes::from_array(all_data)
  } else if compression == 32773 {
    // PackBits 解压：逐 strip 读取并解码
    let all_data : Array[Byte] = []
    let mut strip_idx : Int = 0
    while strip_idx < strip_offsets.length() {
      let strip_offset = strip_offsets[strip_idx]
      let byte_count = if strip_idx < strip_byte_counts.length() {
        strip_byte_counts[strip_idx]
      } else {
        width * height * out_channels - all_data.length()
      }
      // 手动提取 strip 数据
      let strip_data : Bytes = {
        let tmp : Array[Byte] = []
        let mut i = strip_offset
        let end = i + byte_count
        while i < end {
          if i < len {
            tmp.push(ctx.data[i])
          }
          i += 1
        }
        Bytes::from_array(tmp)
      }
      let decoded = tiff_packbits_decode(strip_data)
      for d in decoded {
        all_data.push(d)
      }
      strip_idx += 1
    }
    Bytes::from_array(all_data)
  } else if compression == 8 {
    // Deflate 解压：逐 strip 读取并解码
    let all_data : Array[Byte] = []
    let mut strip_idx : Int = 0
    while strip_idx < strip_offsets.length() {
      let strip_offset = strip_offsets[strip_idx]
      let byte_count = if strip_idx < strip_byte_counts.length() {
        strip_byte_counts[strip_idx]
      } else {
        width * height * out_channels - all_data.length()
      }
      // 手动提取 strip 数据
      let strip_data : Bytes = {
        let tmp : Array[Byte] = []
        let mut i = strip_offset
        let end = i + byte_count
        while i < end {
          if i < len {
            tmp.push(ctx.data[i])
          }
          i += 1
        }
        Bytes::from_array(tmp)
      }
      let decoded = tiff_deflate_decode(strip_data)
      for d in decoded {
        all_data.push(d)
      }
      strip_idx += 1
    }
    Bytes::from_array(all_data)
  } else {
    // 无压缩：直接从 strip offset 读取像素数据
    let all_data : Array[Byte] = []
    let mut strip_idx : Int = 0
    while strip_idx < strip_offsets.length() {
      let strip_offset = strip_offsets[strip_idx]
      let byte_count = if strip_idx < strip_byte_counts.length() {
        strip_byte_counts[strip_idx]
      } else {
        width * height * out_channels - all_data.length()
      }
      let mut i = strip_offset
      let end = i + byte_count
      while i < end && i < len {
        all_data.push(ctx.data[i])
        i += 1
      }
      strip_idx += 1
    }
    Bytes::from_array(all_data)
  }
  let len = decompressed.length()
  let mut row = 0
  for _ in 0..<strip_offsets.length() {
    if row >= height {
      break
    }
    let rows_in_strip = if row + rows_per_strip > height {
      height - row
    } else {
      rows_per_strip
    }
    for r in 0..<rows_in_strip {
      let y = row + r
      let row_start = r * width * bytes_per_pixel
      for x in 0..<width {
        let src = row_start + x * bytes_per_pixel
        let dst = (y * width + x) * out_channels
        if src + bytes_per_pixel > len {
          raise @types.LoadError::DecodeFailed("TIFF 像素数据越界")
        }
        if out_channels == 1 {
          // 灰度
          let g = decompressed[src].to_int()
          let val = if photometric == 0 { 255 - g } else { g }
          pixels[dst] = val.to_byte()
          // RGB 或 RGBA
        } else if photometric == 2 {
          // RGB
          pixels[dst] = decompressed[src]
          pixels[dst + 1] = decompressed[src + 1]
          pixels[dst + 2] = decompressed[src + 2]
          if out_channels == 4 {
            pixels[dst + 3] = decompressed[src + 3]
          }
        } else if photometric == 0 || photometric == 1 {
          // 灰度存储为多通道（不常见，但处理之）
          let g = decompressed[src].to_int()
          let val = if photometric == 0 { 255 - g } else { g }
          pixels[dst] = val.to_byte()
          pixels[dst + 1] = val.to_byte()
          pixels[dst + 2] = val.to_byte()
          if out_channels == 4 {
            pixels[dst + 3] = decompressed[src + 3]
          }
        } else {
          raise @types.LoadError::DecodeFailed(
            "TIFF 不支持的 PhotometricInterpretation",
          )
        }
      }
    }
    row += rows_in_strip
  }
  @types.Image::{
    width,
    height,
    channels: out_channels,
    data: Bytes::from_array(pixels),
  }
}

///|
/// 将 Image 编码为无压缩 TIFF 字节流（小端序）
/// 支持 1/3/4 channels
pub fn encode_tiff_pure(img : @types.Image) -> Bytes raise @types.LoadError {
  let width = img.width
  let height = img.height
  let channels = img.channels
  let data = img.data
  if channels != 1 && channels != 3 && channels != 4 {
    raise @types.LoadError::EncodeFailed(
      "TIFF 编码需要 channels 为 1 (灰度)、3 (RGB) 或 4 (RGBA)",
    )
  }
  let out : Array[Byte] = []
  // TIFF Header (8 bytes)
  out.push(b'\x49') // 'I' little-endian
  out.push(b'\x49') // 'I'
  write_u16_le(out, 42) // magic
  write_u32_le(out, 8) // IFD offset (immediately after header)
  // IFD: count(2) + entries(12 each) + next IFD offset(4)
  // 需要的 tags:
  // 256 ImageWidth, 257 ImageLength, 258 BitsPerSample,
  // 259 Compression, 262 Photometric, 273 StripOffsets,
  // 277 SamplesPerPixel, 278 RowsPerStrip, 279 StripByteCounts
  let num_entries = 9
  let ifd_size = 2 + num_entries * 12 + 4
  // BitsPerSample 可能需要外部存储（如果 channels > 1，3个SHORT=6字节 > 4字节）
  let bps_offset = 8 + ifd_size
  let bps_external = channels > 1
  let bps_bytes = if bps_external { 6 } else { 0 } // 3 SHORTs for RGB, 4 SHORTs for RGBA
  let bps_actual = if channels == 4 { 8 } else { bps_bytes }
  // 像素数据偏移
  let pixel_offset = bps_offset + bps_actual
  let pixel_size = width * height * channels
  // 写入 IFD
  write_u16_le(out, num_entries)
  // 辅助函数：写入 IFD 条目
  let write_entry = fn(
    tag : Int,
    type_id : Int,
    count : Int,
    value : Int,
  ) -> Unit {
    write_u16_le(out, tag)
    write_u16_le(out, type_id)
    write_u32_le(out, count)
    write_u32_le(out, value)
  }
  // 256: ImageWidth (LONG)
  write_entry(256, 4, 1, width)
  // 257: ImageLength (LONG)
  write_entry(257, 4, 1, height)
  // 258: BitsPerSample (SHORT)
  if bps_external {
    // 值在外部存储
    write_entry(258, 3, channels, bps_offset)
  } else {
    // 单通道，值内联
    write_entry(258, 3, 1, 8)
  }
  // 259: Compression (SHORT) = 1 (无压缩)
  write_entry(259, 3, 1, 1)
  // 262: PhotometricInterpretation (SHORT)
  let photometric = if channels == 1 { 1 } else { 2 } // 1=BlackIsZero, 2=RGB
  write_entry(262, 3, 1, photometric)
  // 273: StripOffsets (LONG)
  write_entry(273, 4, 1, pixel_offset)
  // 277: SamplesPerPixel (SHORT)
  write_entry(277, 3, 1, channels)
  // 278: RowsPerStrip (LONG)
  write_entry(278, 4, 1, height)
  // 279: StripByteCounts (LONG)
  write_entry(279, 4, 1, pixel_size)
  // Next IFD offset = 0 (无更多 IFD)
  write_u32_le(out, 0)
  // BitsPerSample 外部数据
  if bps_external {
    for _ in 0..<channels {
      write_u16_le(out, 8)
    }
  }
  // 像素数据
  for y in 0..<height {
    for x in 0..<width {
      let idx = (y * width + x) * channels
      if channels == 1 {
        out.push(data[idx])
      } else {
        // RGB 或 RGBA，TIFF 存储为 RGB(A)
        out.push(data[idx])
        out.push(data[idx + 1])
        out.push(data[idx + 2])
        if channels == 4 {
          out.push(data[idx + 3])
        }
      }
    }
  }
  Bytes::from_array(out)
}

///|
/// 解码 TIFF Deflate (ZIP) 压缩的字节流
/// 支持标准 Huffman 和动态 Huffman 表
pub fn tiff_deflate_decode(data : Bytes) -> Array[Byte] raise @types.LoadError {
  let len = data.length()
  if len < 2 {
    raise @types.LoadError::DecodeFailed("TIFF Deflate 数据过短")
  }

  // Deflate 格式：每个块以 1 位标记位 + 2 位块类型开始
  // 块类型：00=未压缩，01=静态 Huffman，10=动态 Huffman，11=保留

  let mut bit_pos : Int = 0
  let output : Array[Byte] = []

  // 位读取器
  fn read_bits(data : Bytes, pos : Int, count : Int, len : Int) -> (Int, Int) {
    let mut code : Int = 0
    let mut p = pos
    let mut i : Int = 0
    while i < count && p < len * 8 {
      let byte_idx = p / 8
      let bit_offset = p % 8
      if byte_idx < len {
        let bit = (data[byte_idx].to_int() >> bit_offset) & 1
        code = code | (bit << i)
      }
      p += 1
      i += 1
    }
    (code, p)
  }

  // 读取标记位
  let (_bits1, new_pos) = read_bits(data, bit_pos, 1, len)
  bit_pos = new_pos
  let (block_type_bits, final_pos) = read_bits(data, new_pos, 2, len)
  bit_pos = final_pos
  let block_type = block_type_bits & 0x03
  // 字节对齐（未压缩块的数据必须从字节边界开始）
  bit_pos = (bit_pos + 7) / 8 * 8

  // 目前只支持未压缩块（block_type=0）
  if block_type != 0 {
    raise @types.LoadError::DecodeFailed("TIFF Deflate 仅支持未压缩块")
  }

  // 未压缩块：4 字节长度 + 4 字节长度取反 + 数据
  // 跳过位读取，直接从字节边界读取
  let byte_pos = bit_pos / 8
  let len1 = data[byte_pos].to_int() | (data[byte_pos + 1].to_int() << 8)
  let len2 = data[byte_pos + 2].to_int() | (data[byte_pos + 3].to_int() << 8)
  let block_len = len1
  let block_len_inv = len2

  if block_len_inv != (block_len ^ 0xFFFF) {
    raise @types.LoadError::DecodeFailed("TIFF Deflate 长度校验失败")
  }

  // 读取数据
  let mut i = byte_pos + 4
  let end = i + block_len
  while i < end && i < len {
    output.push(data[i])
    i += 1
  }

  output
}
