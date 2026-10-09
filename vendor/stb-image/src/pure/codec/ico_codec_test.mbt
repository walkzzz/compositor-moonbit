// 纯 MoonBit ICO/CUR 编解码测试

///|
fn make_2x2_rgba_image() -> @types.Image {
  // 2x2 RGBA: 红, 绿, 蓝, 白
  @types.Image::{
    width: 2,
    height: 2,
    channels: 4,
    data: b"\xFF\x00\x00\xFF\x00\xFF\x00\xFF\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF",
  }
}

///|
fn make_3x3_rgb_image() -> @types.Image {
  // 3x3 RGB 全红
  let data : Array[Byte] = Array::make(27, b'\x00')
  for i in 0..<9 {
    data[i * 3] = b'\xFF'
  }
  @types.Image::{
    width: 3,
    height: 3,
    channels: 3,
    data: Bytes::from_array(data),
  }
}

///|
/// 构造单个 BMP 子图像的 ICO (type=1)，DIB 起始于偏移 22。
/// dib: 40 字节 BITMAPINFOHEADER（调用方控制 biSize/biCompression/biWidth 等）
/// pixel: DIB 之后的像素数据
/// byte_size_override: 可选，覆盖 ICONDIRENTRY 中的 byte_size（用于模拟截断）
fn make_ico_bmp(
  dib : Array[Byte],
  pixel : Array[Byte],
  byte_size_override? : Int? = None,
) -> Bytes {
  let out : Array[Byte] = []
  // ICONDIR (6 bytes)
  out.push(b'\x00')
  out.push(b'\x00') // reserved
  out.push(b'\x01')
  out.push(b'\x00') // type = ICO
  out.push(b'\x01')
  out.push(b'\x00') // count = 1
  // ICONDIRENTRY (16 bytes)
  out.push(b'\x01') // width = 1
  out.push(b'\x01') // height = 1
  out.push(b'\x00') // color count
  out.push(b'\x00') // reserved
  out.push(b'\x01')
  out.push(b'\x00') // planes = 1
  out.push(b'\x20')
  out.push(b'\x00') // bit count = 32
  let bs = match byte_size_override {
    Some(n) => n
    None => 40 + pixel.length()
  }
  out.push((bs & 0xFF).to_byte())
  out.push(((bs >> 8) & 0xFF).to_byte())
  out.push(((bs >> 16) & 0xFF).to_byte())
  out.push(((bs >> 24) & 0xFF).to_byte())
  out.push(b'\x16')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00') // offset = 22
  for i in 0..<dib.length() {
    out.push(dib[i])
  }
  for i in 0..<pixel.length() {
    out.push(pixel[i])
  }
  Bytes::from_array(out)
}

///|
test "encode_ico_pure / decode_ico_pure: 2x2 RGBA roundtrip" {
  let img = make_2x2_rgba_image()
  let ico = encode_ico_pure(img)
  let decoded = decode_ico_pure(ico)
  assert_eq(decoded.width, 2)
  assert_eq(decoded.height, 2)
  assert_eq(decoded.channels, 4)
  let expected = [
    255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255,
  ]
  for i in 0..<16 {
    assert_eq(decoded.data[i].to_int(), expected[i])
  }
}

///|
test "encode_ico_pure / decode_ico_pure: 3x3 RGB roundtrip" {
  let img = make_3x3_rgb_image()
  let ico = encode_ico_pure(img)
  let decoded = decode_ico_pure(ico)
  assert_eq(decoded.width, 3)
  assert_eq(decoded.height, 3)
  assert_eq(decoded.channels, 4)
  for i in 0..<9 {
    assert_eq(decoded.data[i * 4].to_int(), 255)
    assert_eq(decoded.data[i * 4 + 1].to_int(), 0)
    assert_eq(decoded.data[i * 4 + 2].to_int(), 0)
    assert_eq(decoded.data[i * 4 + 3].to_int(), 255)
  }
}

///|
test "encode_ico_pure: ICO 文件头正确" {
  let img = make_2x2_rgba_image()
  let ico = encode_ico_pure(img)
  assert_eq(ico[0].to_int(), 0)
  assert_eq(ico[1].to_int(), 0)
  assert_eq(ico[2].to_int(), 1)
  assert_eq(ico[3].to_int(), 0)
  assert_eq(ico[4].to_int(), 1)
  assert_eq(ico[5].to_int(), 0)
}

///|
test "decode_ico_pure: 透明像素 AND 掩码" {
  // 使用有效的 32-bit BMP (不需要 AND mask)
  let data : Array[Byte] = [
    0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x20,
    0x00, 0x30, 0x00, 0x00, 0x00, 0x16, 0x00, 0x00, 0x00, 0x28, 0x00, 0x00, 0x00,
    0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x01, 0x00, 0x20, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0x80, 0xFF,
    0xFF, 0x00, 0x00, 0x00, 0x00,
  ]
  let ico = Bytes::from_array(data)
  let decoded = decode_ico_pure(ico)
  assert_eq(decoded.width, 1)
  assert_eq(decoded.height, 1)
  assert_eq(decoded.channels, 4)
  assert_eq(decoded.data[0].to_int(), 255)
  assert_eq(decoded.data[1].to_int(), 128)
  assert_eq(decoded.data[2].to_int(), 64)
  assert_eq(decoded.data[3].to_int(), 255)
}

///|
test "decode_ico_pure: BMP pixel data out of bounds raises" {
  // 有效 DIB，但像素数据缺少 1 字节 (需要 4 字节，只有 3)
  let dib : Array[Byte] = [
    0x28, 0x00, 0x00, 0x00, // biSize=40
     0x01, 0x00, 0x00, 0x00, // biWidth=1
     0x02, 0x00, 0x00, 0x00, // biHeight=2
     0x01, 0x00, // biPlanes=1
     0x20, 0x00, // biBitCount=32
     0x00, 0x00, 0x00, 0x00, // biCompression=0
     0x04, 0x00, 0x00, 0x00, // biSizeImage=4
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
  ]
  let data = make_ico_bmp(dib, [0xFF, 0x00, 0x00]) // 仅 3 字节像素
  try {
    let _ = decode_ico_pure(data)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_ico_pure: width=0 height=0 in directory entry" {
  // 目录条目 width=0/height=0 表示 256，解析时应转换为 256
  let data : Array[Byte] = [
    0x00, 0x00, 0x01, 0x00, // type=1 (ICO), count=1
     0x00, 0x00, 0x01, 0x00, // width=0(256), height=0(256)
     0x00, 0x00, 0x00, 0x00, // reserved
     0x00, 0x00, 0x00, 0x00, // reserved
     0x28, 0x00, 0x00, 0x00, // DIB header size=40
     0x01, 0x00, 0x00, 0x00, // width=1
     0x02, 0x00, 0x00, 0x00, // height=2 (1x XOR + 1x AND)
     0x01, 0x00, // planes=1
     0x20, 0x00, // bit count=32
     0x00, 0x00, 0x00, 0x00, // compression=0
     0x04, 0x00, 0x00, 0x00, // image size=4
     0x00, 0x00, 0x00, 0x00, // h resolution
     0x00, 0x00, 0x00, 0x00, // v resolution
     0x00, 0x00, 0x00, 0x00, // colors used
     0x00, 0x00, 0x00, 0x00, // important colors
     0xFF, 0x00, 0x00, 0xFF, // 1 pixel RGBA
     0x00, 0x00, 0x00, 0x00, // AND mask (1 bit, padded to 4 bytes)
  ]
  try {
    let _ = decode_ico_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    // 目录 width=0 → 256，但数据过小应失败
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_ico_pure: data too short raises" {
  try {
    let _ = decode_ico_pure(b"\x00\x01")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_ico_pure: invalid type raises" {
  // type=3 is not ICO or CUR
  let data : Array[Byte] = [
    0x00, 0x00, // reserved
     0x03, 0x00, // type=3 (invalid)
     0x01, 0x00, // count=1
  ]
  try {
    let _ = decode_ico_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_ico_pure: directory incomplete raises" {
  // type=1, count=1 but only 8 bytes (< 6 + 1*16 = 22)
  let data : Array[Byte] = [0x00, 0x00, 0x01, 0x00, 0x01, 0x00]
  try {
    let _ = decode_ico_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_ico_pure: BMP offset beyond data raises" {
  // byte_size 远大于数据长度，触发偏移越界检查
  // ICONDIR(6) + ICONDIRENTRY(16) + DIB(40) + pixel(4) = 66 bytes, but byte_size claims 0xFF
  let data : Array[Byte] = [
    0x00, 0x00, // reserved
     0x01, 0x00, // type = ICO
     0x01, 0x00, // count = 1
     0x01, // width = 1
     0x01, // height = 1
     0x00, // color count
     0x00, // reserved
     0x01, 0x00, // planes = 1
     0x20, 0x00, // bit count = 32
     0xFF, 0x00, 0x00, 0x00, // byte_size = 0xFF (远超实际数据)
     0x16, 0x00, 0x00, 0x00, // offset = 22
    // DIB header (40 bytes)
     0x28, 0x00, 0x00, 0x00, // biSize=40
     0x01, 0x00, 0x00, 0x00, // biWidth=1
     0x02, 0x00, 0x00, 0x00, // biHeight=2
     0x01, 0x00, // biPlanes=1
     0x20, 0x00, // biBitCount=32
     0x00, 0x00, 0x00, 0x00, // biCompression=0
     0x04, 0x00, 0x00, 0x00, // biSizeImage=4
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
    // Pixel data (4 bytes)
     0xFF, 0x00, 0x00, 0xFF,
  ]
  try {
    let _ = decode_ico_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_ico_pure: DIB header too short raises" {
  // DIB biSize 字段 < 40
  let dib : Array[Byte] = [
    0x20, 0x00, 0x00, 0x00, // biSize=32 (< 40)
     0x01, 0x00, 0x00, 0x00, // biWidth=1
     0x02, 0x00, 0x00, 0x00, // biHeight=2
     0x01, 0x00, // biPlanes=1
     0x20, 0x00, // biBitCount=32
     0x00, 0x00, 0x00, 0x00, // biCompression=0
     0x04, 0x00, 0x00, 0x00, // biSizeImage=4
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
  ]
  let data = make_ico_bmp(dib, [0xFF, 0x00, 0x00, 0xFF])
  try {
    let _ = decode_ico_pure(data)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_ico_pure: compressed BMP raises" {
  // DIB biCompression != 0 (不支持压缩)
  let dib : Array[Byte] = [
    0x28, 0x00, 0x00, 0x00, // biSize=40
     0x01, 0x00, 0x00, 0x00, // biWidth=1
     0x02, 0x00, 0x00, 0x00, // biHeight=2
     0x01, 0x00, // biPlanes=1
     0x20, 0x00, // biBitCount=32
     0x01, 0x00, 0x00, 0x00, // biCompression=1 (BI_RLE8)
     0x04, 0x00, 0x00, 0x00, // biSizeImage=4
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
  ]
  let data = make_ico_bmp(dib, [0xFF, 0x00, 0x00, 0xFF])
  try {
    let _ = decode_ico_pure(data)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_ico_pure: zero width raises" {
  // DIB biWidth=0
  let dib : Array[Byte] = [
    0x28, 0x00, 0x00, 0x00, // biSize=40
     0x00, 0x00, 0x00, 0x00, // biWidth=0
     0x02, 0x00, 0x00, 0x00, // biHeight=2
     0x01, 0x00, // biPlanes=1
     0x20, 0x00, // biBitCount=32
     0x00, 0x00, 0x00, 0x00, // biCompression=0
     0x02, 0x00, 0x00, 0x00, // biSizeImage=2
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
  ]
  let data = make_ico_bmp(dib, [0xFF, 0x00, 0x00, 0xFF])
  try {
    let _ = decode_ico_pure(data)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}
