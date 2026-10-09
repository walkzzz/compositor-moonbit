// 纯 MoonBit GIF 编码器
// 单帧 GIF89a，使用 3-3-2 均匀量化（256 色调色板）+ LZW 压缩
// 移植自 src/format/gif_encode.mbt:1-177，仅替换类型引用：
//   @core.Image -> @types.Image, @core.LoadError -> @types.LoadError

// 3-3-2 量化: R 8 levels, G 8 levels, B 4 levels = 256 colors

///|
fn quantize_332(r : Int, g : Int, b : Int) -> Int {
  let r_level = (r >> 5) & 0x07
  let g_level = (g >> 5) & 0x07
  let b_level = (b >> 6) & 0x03
  r_level * 32 + g_level * 4 + b_level
}

// 构建 256 色 3-3-2 调色板

///|
fn build_332_palette() -> Array[Byte] {
  let palette : Array[Byte] = Array::make(768, b'\x00')
  for i in 0..<256 {
    let r_level = i / 32
    let g_level = i % 32 / 4
    let b_level = i % 4
    palette[i * 3] = (r_level * 36).to_byte()
    palette[i * 3 + 1] = (g_level * 36).to_byte()
    palette[i * 3 + 2] = (b_level * 85).to_byte()
  }
  palette
}

// LZW 压缩用于 GIF
// 返回压缩后的字节数组（包含 sub-block 包装）

///|
fn lzw_compress(indices : Array[Int], min_code_size : Int) -> Bytes {
  let clear_code = 1 << min_code_size
  let end_code = clear_code + 1
  let code_table : Array[(Int, Int)] = [] // (prefix_code, pixel_value) pairs
  // 初始化 code table
  for i in 0..<clear_code {
    code_table.push((-1, i))
  }
  code_table.push((-1, -1)) // clear code
  code_table.push((-1, -1)) // end code
  let next_code = Ref(clear_code + 2)
  let code_size = Ref(min_code_size + 1)
  let max_code = Ref((1 << code_size.val) - 1)
  // 输出位流
  let bit_buffer = Ref(0)
  let bit_count = Ref(0)
  let output : Array[Byte] = []
  fn emit_code(code : Int) -> Unit {
    bit_buffer.val = bit_buffer.val | (code << bit_count.val)
    bit_count.val += code_size.val
    while bit_count.val >= 8 {
      output.push((bit_buffer.val & 0xFF).to_byte())
      bit_buffer.val = bit_buffer.val >> 8
      bit_count.val -= 8
    }
  }
  emit_code(clear_code)
  if indices.length() > 0 {
    let prefix = Ref(indices[0])
    for i in 1..<indices.length() {
      let pixel = indices[i]
      // 查找 (prefix, pixel) 在 code table 中
      let found = Ref(-1)
      for j in 0..<code_table.length() {
        let (p, v) = code_table[j]
        if p == prefix.val && v == pixel {
          found.val = j
          break
        }
      }
      if found.val >= 0 {
        prefix.val = found.val
      } else {
        emit_code(prefix.val)
        if next_code.val < 4096 {
          code_table.push((prefix.val, pixel))
          if next_code.val > max_code.val && code_size.val < 12 {
            code_size.val += 1
            max_code.val = (1 << code_size.val) - 1
          }
          next_code.val += 1
        }
        prefix.val = pixel
      }
    }
    emit_code(prefix.val)
  }
  emit_code(end_code)
  // 刷新剩余位
  if bit_count.val > 0 {
    output.push((bit_buffer.val & 0xFF).to_byte())
  }
  // 包装为 sub-blocks (每块最多 255 字节)
  let result : Array[Byte] = []
  let pos = Ref(0)
  while pos.val < output.length() {
    let block_size = if output.length() - pos.val > 255 {
      255
    } else {
      output.length() - pos.val
    }
    result.push(block_size.to_byte())
    for i in 0..<block_size {
      result.push(output[pos.val + i])
    }
    pos.val += block_size
  }
  result.push(b'\x00') // block terminator
  Bytes::from_array(result)
}

///|
/// 将 Image 编码为单帧 GIF89a 字节流
/// 使用 3-3-2 均匀量化（256 色调色板）+ LZW 压缩
/// 输入 channels 应为 3 (RGB) 或 4 (RGBA，alpha 忽略)
pub fn encode_gif_pure(img : @types.Image) -> Bytes raise @types.LoadError {
  if img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::EncodeFailed(
      "GIF 编码需要 channels 为 3 (RGB) 或 4 (RGBA)",
    )
  }
  let out : Array[Byte] = []
  // GIF89a header
  out.push(b'\x47') // G
  out.push(b'\x49') // I
  out.push(b'\x46') // F
  out.push(b'\x38') // 8
  out.push(b'\x39') // 9
  out.push(b'\x61') // a
  // Logical Screen Descriptor (7 bytes)
  out.push((img.width & 0xFF).to_byte())
  out.push(((img.width >> 8) & 0xFF).to_byte())
  out.push((img.height & 0xFF).to_byte())
  out.push(((img.height >> 8) & 0xFF).to_byte())
  out.push(b'\xF7') // packed: global color table = 1, color resolution = 7, sort = 0, size = 7 (256 colors)
  out.push(b'\x00') // background color index
  out.push(b'\x00') // pixel aspect ratio
  // Global Color Table (256 * 3 = 768 bytes)
  let palette = build_332_palette()
  for i in 0..<768 {
    out.push(palette[i])
  }
  // 量化像素
  let indices : Array[Int] = Array::make(img.width * img.height, 0)
  for y in 0..<img.height {
    for x in 0..<img.width {
      let idx = y * img.width + x
      let r = img.data[idx * img.channels].to_int()
      let g = img.data[idx * img.channels + 1].to_int()
      let b = img.data[idx * img.channels + 2].to_int()
      indices[idx] = quantize_332(r, g, b)
    }
  }
  // Image Descriptor
  out.push(b'\x2C') // Image Separator
  out.push(b'\x00') // left position (LE)
  out.push(b'\x00')
  out.push(b'\x00') // top position (LE)
  out.push(b'\x00')
  out.push((img.width & 0xFF).to_byte())
  out.push(((img.width >> 8) & 0xFF).to_byte())
  out.push((img.height & 0xFF).to_byte())
  out.push(((img.height >> 8) & 0xFF).to_byte())
  out.push(b'\x00') // packed: no local color table, not interlaced
  // LZW Image Data
  out.push(b'\x08') // LZW Minimum Code Size
  let lzw_data = lzw_compress(indices, 8)
  for i in 0..<lzw_data.length() {
    out.push(lzw_data[i])
  }
  // Trailer
  out.push(b'\x3B')
  Bytes::from_array(out)
}

///|
/// 将多帧 Image 编码为动画 GIF89a 字节流。
/// frames 为帧数组，delays 为每帧延迟（毫秒，将转换为 1/100 秒单位）。
/// 所有帧应具有相同尺寸和 channels（3 或 4）。
/// 使用 3-3-2 均匀量化 + LZW 压缩，无限循环。
pub fn encode_gif_animation_pure(
  anim : @types.GifAnimation,
) -> Bytes raise @types.LoadError {
  let frames = anim.frames
  let delays = anim.delays
  if frames.length() == 0 {
    raise @types.LoadError::EncodeFailed("GIF 动画至少需要 1 帧")
  }
  if frames.length() != delays.length() {
    raise @types.LoadError::EncodeFailed("frames 和 delays 长度不匹配")
  }
  let first = frames[0]
  if first.channels != 3 && first.channels != 4 {
    raise @types.LoadError::EncodeFailed(
      "GIF 编码需要 channels 为 3 (RGB) 或 4 (RGBA)",
    )
  }
  let w = first.width
  let h = first.height
  let out : Array[Byte] = []
  // GIF89a header
  out.push(b'\x47')
  out.push(b'\x49')
  out.push(b'\x46')
  out.push(b'\x38')
  out.push(b'\x39')
  out.push(b'\x61')
  // Logical Screen Descriptor
  out.push((w & 0xFF).to_byte())
  out.push(((w >> 8) & 0xFF).to_byte())
  out.push((h & 0xFF).to_byte())
  out.push(((h >> 8) & 0xFF).to_byte())
  out.push(b'\xF7') // global color table flag, 256 colors
  out.push(b'\x00') // background color index
  out.push(b'\x00') // pixel aspect ratio
  // Global Color Table (256 * 3 = 768 bytes)
  let palette = build_332_palette()
  for i in 0..<768 {
    out.push(palette[i])
  }
  // Netscape Application Extension (无限循环)
  out.push(b'\x21') // Extension Introducer
  out.push(b'\xFF') // Application Extension Label
  out.push(b'\x0B') // Block Size
  // "NETSCAPE2.0"
  out.push(b'\x4E')
  out.push(b'\x45')
  out.push(b'\x54')
  out.push(b'\x53')
  out.push(b'\x43')
  out.push(b'\x41')
  out.push(b'\x50')
  out.push(b'\x45')
  out.push(b'\x32')
  out.push(b'\x2E')
  out.push(b'\x30')
  out.push(b'\x03') // Sub-block size
  out.push(b'\x01') // Sub-block ID
  out.push(b'\x00') // loop count LE (0 = infinite)
  out.push(b'\x00')
  out.push(b'\x00') // Block Terminator
  // 每帧
  for fi in 0..<frames.length() {
    let frame = frames[fi]
    // Graphic Control Extension
    out.push(b'\x21') // Extension Introducer
    out.push(b'\xF9') // Graphic Control Label
    out.push(b'\x04') // Block Size
    out.push(b'\x00') // packed: disposal=0, no user input, no transparency
    // delay in 1/100 seconds (毫秒 / 10)
    let delay = delays[fi] / 10
    out.push((delay & 0xFF).to_byte())
    out.push(((delay >> 8) & 0xFF).to_byte())
    out.push(b'\x00') // transparent color index
    out.push(b'\x00') // Block Terminator
    // 量化像素
    let indices : Array[Int] = Array::make(frame.width * frame.height, 0)
    for y in 0..<frame.height {
      for x in 0..<frame.width {
        let idx = y * frame.width + x
        let r = frame.data[idx * frame.channels].to_int()
        let g = frame.data[idx * frame.channels + 1].to_int()
        let b = frame.data[idx * frame.channels + 2].to_int()
        indices[idx] = quantize_332(r, g, b)
      }
    }
    // Image Descriptor
    out.push(b'\x2C') // Image Separator
    out.push(b'\x00') // left position LE
    out.push(b'\x00')
    out.push(b'\x00') // top position LE
    out.push(b'\x00')
    out.push((frame.width & 0xFF).to_byte())
    out.push(((frame.width >> 8) & 0xFF).to_byte())
    out.push((frame.height & 0xFF).to_byte())
    out.push(((frame.height >> 8) & 0xFF).to_byte())
    out.push(b'\x00') // packed: no local color table, not interlaced
    // LZW Image Data
    out.push(b'\x08') // LZW Minimum Code Size
    let lzw_data = lzw_compress(indices, 8)
    for i in 0..<lzw_data.length() {
      out.push(lzw_data[i])
    }
  }
  // Trailer
  out.push(b'\x3B')
  Bytes::from_array(out)
}
