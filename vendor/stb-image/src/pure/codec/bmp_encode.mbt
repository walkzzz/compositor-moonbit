// 纯 MoonBit BMP 编码（全目标可用：native/wasm/js）
// 24-bit BMP, BITMAPINFOHEADER, bottom-up, BGR, 4字节行对齐

///|
/// 写入 4 字节小端整数
fn bmp_write_i32_le(out : Array[Byte], val : Int) -> Unit {
  out.push((val & 0xFF).to_byte())
  out.push(((val >> 8) & 0xFF).to_byte())
  out.push(((val >> 16) & 0xFF).to_byte())
  out.push(((val >> 24) & 0xFF).to_byte())
}

///|
/// BMP 编码（纯 MoonBit，全目标可用）。
pub fn encode_bmp_pure(img : @types.Image) -> Bytes {
  let width = img.width
  let height = img.height
  let channels = img.channels
  let data = img.data
  let row_padded = (width * 3 + 3) & 0x7FFFFFFC
  let pixel_size = row_padded * height
  let file_size = 54 + pixel_size
  let out : Array[Byte] = []
  // BMP File Header (14 bytes)
  out.push(b'\x42')
  out.push(b'\x4D')
  bmp_write_i32_le(out, file_size)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x36')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  // DIB Header (40 bytes)
  out.push(b'\x28')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  bmp_write_i32_le(out, width)
  bmp_write_i32_le(out, height)
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x18')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  bmp_write_i32_le(out, pixel_size)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  // Pixel data (bottom-up, BGR, 4-byte row padding)
  for y in 0..<height {
    let ry = height - 1 - y
    let row_start = ry * width * channels
    for x in 0..<width {
      let idx = row_start + x * channels
      let r = data[idx].to_int()
      let g = if channels >= 2 { data[idx + 1].to_int() } else { r }
      let b = if channels >= 3 { data[idx + 2].to_int() } else { r }
      out.push(b.to_byte())
      out.push(g.to_byte())
      out.push(r.to_byte())
    }
    let padding = row_padded - width * 3
    for _ in 0..<padding {
      out.push(b'\x00')
    }
  }
  Bytes::from_array(out)
}
