// 纯 MoonBit PNG 编码（全目标可用：native/wasm/js）
// 使用 filter type 0 (None) + zlib stored blocks（无压缩但有效）

///|
/// 简单 zlib deflate（stored blocks，无压缩）
fn zlib_deflate_stored(data : Bytes) -> Bytes {
  let out : Array[Byte] = []
  // zlib header: CMF=0x78, FLG=0x01 (check: 0x78*256+0x01 = 30721, 30721%31=0)
  out.push(b'\x78')
  out.push(b'\x01')
  // DEFLATE stored blocks
  let len = data.length()
  let mut pos = 0
  while pos < len {
    let block_len = if len - pos > 65535 { 65535 } else { len - pos }
    let is_final = if pos + block_len >= len { 1 } else { 0 }
    // BFINAL + BTYPE = 0b?00, aligned to byte → 0x01 for final, 0x00 for non-final
    out.push(is_final.to_byte())
    // LEN (little-endian)
    out.push((block_len & 0xFF).to_byte())
    out.push(((block_len >> 8) & 0xFF).to_byte())
    // NLEN (one's complement of LEN)
    out.push((block_len & 0xFF).to_byte() ^ b'\xFF')
    out.push(((block_len >> 8) & 0xFF).to_byte() ^ b'\xFF')
    // Data
    for i in 0..<block_len {
      out.push(data[pos + i])
    }
    pos += block_len
  }
  // ADLER32 (big-endian)
  let adler = @util.adler32(data)
  out.push(((adler >> 24) & 0xFF).to_byte())
  out.push(((adler >> 16) & 0xFF).to_byte())
  out.push(((adler >> 8) & 0xFF).to_byte())
  out.push((adler & 0xFF).to_byte())
  Bytes::from_array(out)
}

///|
/// 写入 PNG chunk
fn write_chunk(out : Array[Byte], chunk_type : String, data : Bytes) -> Unit {
  let len = data.length()
  // length (big-endian)
  out.push(((len >> 24) & 0xFF).to_byte())
  out.push(((len >> 16) & 0xFF).to_byte())
  out.push(((len >> 8) & 0xFF).to_byte())
  out.push((len & 0xFF).to_byte())
  // type
  let type_bytes = @encoding/utf8.encode(chunk_type)
  for i in 0..<4 {
    out.push(type_bytes[i])
  }
  // data
  for i in 0..<len {
    out.push(data[i])
  }
  // CRC (over type + data)
  let crc_data : Array[Byte] = []
  for i in 0..<4 {
    crc_data.push(type_bytes[i])
  }
  for i in 0..<len {
    crc_data.push(data[i])
  }
  let crc = @util.crc32(Bytes::from_array(crc_data))
  out.push(((crc >> 24) & 0xFF).to_byte())
  out.push(((crc >> 16) & 0xFF).to_byte())
  out.push(((crc >> 8) & 0xFF).to_byte())
  out.push((crc & 0xFF).to_byte())
}

///|
/// PNG 编码（纯 MoonBit，全目标可用）。
/// 输入 Image（RGB），返回 PNG 格式字节流。
/// 使用 filter type 0 (None) + zlib stored blocks（无压缩）。
pub fn encode_png_pure(img : @types.Image) -> Bytes {
  let width = img.width
  let height = img.height
  let ch = img.channels
  // 确定输出通道数
  let out_ch = if ch == 4 {
    4
  } else if ch == 2 {
    2
  } else if ch == 1 {
    1
  } else {
    3
  }
  let color_type = if out_ch == 1 {
    0
  } else if out_ch == 2 {
    4
  } else if out_ch == 4 {
    6
  } else {
    2
  }
  let out : Array[Byte] = []
  // PNG signature
  out.push(b'\x89')
  out.push(b'\x50')
  out.push(b'\x4E')
  out.push(b'\x47')
  out.push(b'\x0D')
  out.push(b'\x0A')
  out.push(b'\x1A')
  out.push(b'\x0A')
  // IHDR chunk
  let ihdr : Array[Byte] = []
  // width (big-endian)
  ihdr.push(((width >> 24) & 0xFF).to_byte())
  ihdr.push(((width >> 16) & 0xFF).to_byte())
  ihdr.push(((width >> 8) & 0xFF).to_byte())
  ihdr.push((width & 0xFF).to_byte())
  // height (big-endian)
  ihdr.push(((height >> 24) & 0xFF).to_byte())
  ihdr.push(((height >> 16) & 0xFF).to_byte())
  ihdr.push(((height >> 8) & 0xFF).to_byte())
  ihdr.push((height & 0xFF).to_byte())
  ihdr.push(b'\x08') // bit depth = 8
  ihdr.push(color_type.to_byte())
  ihdr.push(b'\x00') // compression = 0
  ihdr.push(b'\x00') // filter = 0
  ihdr.push(b'\x00') // interlace = 0
  write_chunk(out, "IHDR", Bytes::from_array(ihdr))
  // 构建过滤后的图像数据
  let filtered : Array[Byte] = []
  for y in 0..<height {
    filtered.push(b'\x00') // filter type 0 (None)
    for x in 0..<width {
      let src_off = (y * width + x) * ch
      if ch == out_ch {
        // 直接拷贝
        for c in 0..<ch {
          filtered.push(img.data[src_off + c])
        }
      } else {
        // 通道数不匹配时，取前 out_ch 个通道
        for c in 0..<out_ch {
          if c < ch {
            filtered.push(img.data[src_off + c])
          } else {
            filtered.push(b'\xFF')
          }
        }
      }
    }
  }
  // zlib deflate
  let compressed = zlib_deflate_stored(Bytes::from_array(filtered))
  // IDAT chunk
  write_chunk(out, "IDAT", compressed)
  // IEND chunk
  write_chunk(out, "IEND", Bytes::from_array([]))
  Bytes::from_array(out)
}
