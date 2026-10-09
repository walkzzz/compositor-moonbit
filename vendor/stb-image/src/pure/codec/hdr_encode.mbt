// 纯 MoonBit HDR 编码（全目标可用：native/wasm/js）
// RGBE 格式编码，使用 RLE 压缩扫描线
// 仅依赖 @types，不依赖 @core/FFI

///|
/// RLE 编码单个通道扫描线
fn rle_encode_scanline_channel(
  channel_data : Array[Byte],
  scanline_len : Int,
) -> Array[Byte] {
  let out : Array[Byte] = []
  let mut pos = 0
  while pos < scanline_len {
    // 查找重复 run
    let mut run_len = 1
    while pos + run_len < scanline_len &&
          channel_data[pos + run_len] == channel_data[pos] &&
          run_len < 127 {
      run_len += 1
    }
    if run_len >= 4 {
      // RLE 编码
      out.push((128 + run_len).to_byte())
      out.push(channel_data[pos])
      pos += run_len
    } else {
      // 查找非重复 run
      let mut lit_len = 1
      while pos + lit_len < scanline_len && lit_len < 128 {
        // 检查是否开始新的重复 run
        let mut next_run = 0
        while pos + lit_len + next_run < scanline_len &&
              channel_data[pos + lit_len + next_run] ==
              channel_data[pos + lit_len] &&
              next_run < 3 {
          next_run += 1
        }
        if next_run >= 4 {
          break
        }
        lit_len += 1
      }
      // 非重复编码
      out.push(lit_len.to_byte())
      for i in 0..<lit_len {
        out.push(channel_data[pos + i])
      }
      pos += lit_len
    }
  }
  out
}

///|
/// HDR 编码（纯 MoonBit，全目标可用）。
/// 输入 ImageF（32-bit float 像素数据），返回 HDR 格式字节流。
pub fn encode_hdr_pure(img : @types.ImageF) -> Bytes raise @types.LoadError {
  if img.channels != 3 {
    raise @types.LoadError::EncodeFailed(
      "HDR 编码需要 3 通道 float 图像",
    )
  }
  let width = img.width
  let height = img.height
  let pixel_count = width * height
  // 构建输出
  let out : Array[Byte] = []
  // 写入 header
  let header_str = "#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n"
  let header_bytes = @encoding/utf8.encode(header_str)
  for i in 0..<header_bytes.length() {
    out.push(header_bytes[i])
  }
  // 写入尺寸行: "-Y HEIGHT +X WIDTH\n"
  let dim_str = "-Y " + height.to_string() + " +X " + width.to_string() + "\n"
  let dim_bytes = @encoding/utf8.encode(dim_str)
  for i in 0..<dim_bytes.length() {
    out.push(dim_bytes[i])
  }
  // 将 float 像素转换为 RGBE
  let rgbe : Array[Byte] = Array::make(pixel_count * 4, b'\x00')
  for i in 0..<pixel_count {
    // 读取 little-endian float
    let r_int = img.data[i * 12].to_int() |
      (img.data[i * 12 + 1].to_int() << 8) |
      (img.data[i * 12 + 2].to_int() << 16) |
      (img.data[i * 12 + 3].to_int() << 24)
    let g_int = img.data[i * 12 + 4].to_int() |
      (img.data[i * 12 + 5].to_int() << 8) |
      (img.data[i * 12 + 6].to_int() << 16) |
      (img.data[i * 12 + 7].to_int() << 24)
    let b_int = img.data[i * 12 + 8].to_int() |
      (img.data[i * 12 + 9].to_int() << 8) |
      (img.data[i * 12 + 10].to_int() << 16) |
      (img.data[i * 12 + 11].to_int() << 24)
    let r = Float::reinterpret_from_int(r_int)
    let g = Float::reinterpret_from_int(g_int)
    let b = Float::reinterpret_from_int(b_int)
    let (rb, gb, bb, eb) = float_to_rgbe(r, g, b)
    rgbe[i * 4] = rb
    rgbe[i * 4 + 1] = gb
    rgbe[i * 4 + 2] = bb
    rgbe[i * 4 + 3] = eb
  }
  // RLE 编码每行
  if width < 8 || width > 32767 {
    // 小图或大图：不压缩
    for i in 0..<(pixel_count * 4) {
      out.push(rgbe[i])
    }
  } else {
    // RLE 编码
    for y in 0..<height {
      // 写入行头 [2, 2, width_hi, width_lo]
      out.push(b'\x02')
      out.push(b'\x02')
      out.push((width >> 8).to_byte())
      out.push((width & 0xFF).to_byte())
      // 4 通道分别 RLE 编码
      for c in 0..<4 {
        let channel_data : Array[Byte] = []
        for x in 0..<width {
          channel_data.push(rgbe[(y * width + x) * 4 + c])
        }
        let encoded = rle_encode_scanline_channel(channel_data, width)
        for i in 0..<encoded.length() {
          out.push(encoded[i])
        }
      }
    }
  }
  Bytes::from_array(out)
}
