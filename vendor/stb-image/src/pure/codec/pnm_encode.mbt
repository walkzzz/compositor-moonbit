// 纯 MoonBit PNM 格式编码器：PPM (P6) + PGM (P5)
// 移植自 src/format/pnm_encode.mbt，仅替换类型引用：
//   @core.Image -> @types.Image

///|
/// 编码为 PPM (P6 binary RGB) 格式。
/// 灰度输入自动转为 RGB，RGBA 输入丢弃 alpha。
pub fn encode_ppm_pure(img : @types.Image) -> Bytes {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let n = w * h
  // 构建 RGB 像素数据
  let pixel_data : Array[Byte] = Array::make(n * 3, b'\x00')
  for i in 0..<n {
    let r = img.data[i * ch]
    let g = if ch >= 2 { img.data[i * ch + 1] } else { r }
    let b = if ch >= 3 { img.data[i * ch + 2] } else { r }
    pixel_data[i * 3] = r
    pixel_data[i * 3 + 1] = g
    pixel_data[i * 3 + 2] = b
  }
  // 头部: "P6\n{w} {h}\n255\n"
  let header = "P6\n" + w.to_string() + " " + h.to_string() + "\n255\n"
  let header_bytes = @encoding/utf8.encode(header)
  let result : Array[Byte] = []
  for i in 0..<header_bytes.length() {
    result.push(header_bytes[i])
  }
  for i in 0..<pixel_data.length() {
    result.push(pixel_data[i])
  }
  Bytes::from_array(result)
}

///|
/// 编码为 PGM (P5 binary grayscale) 格式。
/// RGB 输入自动转为灰度（BT.601），RGBA 丢弃 alpha。
pub fn encode_pgm_pure(img : @types.Image) -> Bytes {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let n = w * h
  // 构建灰度像素数据
  let pixel_data : Array[Byte] = Array::make(n, b'\x00')
  for i in 0..<n {
    if ch == 1 {
      pixel_data[i] = img.data[i]
    } else {
      let r = img.data[i * ch].to_int()
      let g = img.data[i * ch + 1].to_int()
      let b = img.data[i * ch + 2].to_int()
      pixel_data[i] = ((r * 299 + g * 587 + b * 114) / 1000).to_byte()
    }
  }
  // 头部: "P5\n{w} {h}\n255\n"
  let header = "P5\n" + w.to_string() + " " + h.to_string() + "\n255\n"
  let header_bytes = @encoding/utf8.encode(header)
  let result : Array[Byte] = []
  for i in 0..<header_bytes.length() {
    result.push(header_bytes[i])
  }
  for i in 0..<pixel_data.length() {
    result.push(pixel_data[i])
  }
  Bytes::from_array(result)
}

///|
/// 自动选择 PNM 格式编码。
/// channels <= 1 → PGM (P5)，否则 → PPM (P6)。
pub fn encode_pnm_pure(img : @types.Image) -> Bytes {
  if img.channels <= 1 {
    encode_pgm_pure(img)
  } else {
    encode_ppm_pure(img)
  }
}
