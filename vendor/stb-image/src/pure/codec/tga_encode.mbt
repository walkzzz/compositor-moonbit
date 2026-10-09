// 纯 MoonBit TGA 编码（全目标可用：native/wasm/js）
// 24-bit uncompressed true-color TGA, top-down, BGR

///|
/// TGA 编码（纯 MoonBit，全目标可用）。
pub fn encode_tga_pure(img : @types.Image) -> Bytes {
  let width = img.width
  let height = img.height
  let channels = img.channels
  let data = img.data
  let out : Array[Byte] = []
  // TGA Header (18 bytes)
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x02')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push((width & 0xFF).to_byte())
  out.push(((width >> 8) & 0xFF).to_byte())
  out.push((height & 0xFF).to_byte())
  out.push(((height >> 8) & 0xFF).to_byte())
  out.push(b'\x18')
  out.push(b'\x20')
  // Pixel data (top-down, BGR)
  for y in 0..<height {
    let row_start = y * width * channels
    for x in 0..<width {
      let idx = row_start + x * channels
      let r = data[idx].to_int()
      let g = if channels >= 2 { data[idx + 1].to_int() } else { r }
      let b = if channels >= 3 { data[idx + 2].to_int() } else { r }
      out.push(b.to_byte())
      out.push(g.to_byte())
      out.push(r.to_byte())
    }
  }
  Bytes::from_array(out)
}
