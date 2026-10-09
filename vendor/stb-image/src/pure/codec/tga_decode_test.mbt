// 纯 MoonBit TGA 解码器测试
// 纯逻辑断言测试（全目标可用：native/wasm/js），不依赖 @core
// 手构造 TGA 字节流验证解码正确性，覆盖 type 2/type 10/24-bit/32-bit/行序/错误路径
// 规范: https://en.wikipedia.org/wiki/Truevision_TGA

///|
fn make_tga_header(
  width : Int,
  height : Int,
  bpp : Int,
  image_type : Int,
  descriptor : Int,
) -> Array[Byte] {
  let out : Array[Byte] = []
  out.push(b'\x00') // ID length
  out.push(b'\x00') // color map type
  out.push(image_type.to_byte()) // image type
  out.push(b'\x00')
  out.push(b'\x00') // color map start (LE)
  out.push(b'\x00')
  out.push(b'\x00') // color map length (LE)
  out.push(b'\x00') // color map bits
  out.push(b'\x00')
  out.push(b'\x00') // x origin (LE)
  out.push(b'\x00')
  out.push(b'\x00') // y origin (LE)
  out.push((width & 0xFF).to_byte())
  out.push(((width >> 8) & 0xFF).to_byte()) // width (LE)
  out.push((height & 0xFF).to_byte())
  out.push(((height >> 8) & 0xFF).to_byte()) // height (LE)
  out.push(bpp.to_byte()) // bits per pixel
  out.push(descriptor.to_byte()) // descriptor
  out
}

///|
fn push_bgr(arr : Array[Byte], r : Int, g : Int, b : Int) -> Unit {
  arr.push(b.to_byte())
  arr.push(g.to_byte())
  arr.push(r.to_byte())
}

///|
fn push_bgra(arr : Array[Byte], r : Int, g : Int, b : Int, a : Int) -> Unit {
  arr.push(b.to_byte())
  arr.push(g.to_byte())
  arr.push(r.to_byte())
  arr.push(a.to_byte())
}

///|
test "decode_tga_pure: 1x1 24-bit type 2 (uncompressed RGB)" {
  let out = make_tga_header(1, 1, 24, 2, 0)
  push_bgr(out, 255, 0, 0) // 红色 BGR
  let img = decode_tga_pure(to_bytes(out))
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 3)
  // 红色像素 RGB
  assert_eq(img.data[0].to_int(), 255)
  assert_eq(img.data[1].to_int(), 0)
  assert_eq(img.data[2].to_int(), 0)
}

///|
test "decode_tga_pure: 1x1 32-bit type 2 (uncompressed RGBA)" {
  let out = make_tga_header(1, 1, 32, 2, 0)
  push_bgra(out, 255, 0, 0, 255) // 红色 BGRA
  let img = decode_tga_pure(to_bytes(out))
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 4)
  // 红色像素 RGBA
  assert_eq(img.data[0].to_int(), 255)
  assert_eq(img.data[1].to_int(), 0)
  assert_eq(img.data[2].to_int(), 0)
  assert_eq(img.data[3].to_int(), 255)
}

///|
test "decode_tga_pure: 2x2 24-bit type 10 (RLE RGB)" {
  let out = make_tga_header(2, 2, 24, 10, 0x10) // top-down
  // RLE packet: header=0x81 (run=2), 1 像素红色 BGR
  out.push(b'\x81')
  push_bgr(out, 255, 0, 0)
  // raw packet: header=0x01 (count=2), 2 像素绿色 BGR
  out.push(b'\x01')
  push_bgr(out, 0, 255, 0)
  push_bgr(out, 0, 255, 0)
  let img = decode_tga_pure(to_bytes(out))
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 3)
  // top-down: 红红绿绿
  let expected = [255, 0, 0, 255, 0, 0, 0, 255, 0, 0, 255, 0]
  for i in 0..<12 {
    assert_eq(img.data[i].to_int(), expected[i])
  }
}

///|
test "decode_tga_pure: 2x2 32-bit type 10 (RLE RGBA)" {
  let out = make_tga_header(2, 2, 32, 10, 0x10) // top-down
  // RLE packet: header=0x81 (run=2), 1 像素红色 BGRA
  out.push(b'\x81')
  push_bgra(out, 255, 0, 0, 255)
  // raw packet: header=0x01 (count=2), 2 像素绿色 BGRA
  out.push(b'\x01')
  push_bgra(out, 0, 255, 0, 255)
  push_bgra(out, 0, 255, 0, 255)
  let img = decode_tga_pure(to_bytes(out))
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 4)
  // top-down: 红红绿绿
  let expected = [
    255, 0, 0, 255, 255, 0, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255,
  ]
  for i in 0..<16 {
    assert_eq(img.data[i].to_int(), expected[i])
  }
}

///|
test "decode_tga_pure: bottom-up row order" {
  let out = make_tga_header(2, 2, 24, 2, 0) // bottom-up
  // 文件行序：row0=黑黑, row1=红红
  push_bgr(out, 0, 0, 0)
  push_bgr(out, 0, 0, 0)
  push_bgr(out, 255, 0, 0)
  push_bgr(out, 255, 0, 0)
  let img = decode_tga_pure(to_bytes(out))
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 3)
  // bottom-up: out_row0=红红, out_row1=黑黑
  let expected = [255, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0]
  for i in 0..<12 {
    assert_eq(img.data[i].to_int(), expected[i])
  }
}

///|
test "decode_tga_pure: top-down row order" {
  let out = make_tga_header(2, 2, 24, 2, 0x10) // top-down
  // 文件行序：row0=红红, row1=黑黑
  push_bgr(out, 255, 0, 0)
  push_bgr(out, 255, 0, 0)
  push_bgr(out, 0, 0, 0)
  push_bgr(out, 0, 0, 0)
  let img = decode_tga_pure(to_bytes(out))
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 3)
  // top-down: out_row0=红红, out_row1=黑黑
  let expected = [255, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0]
  for i in 0..<12 {
    assert_eq(img.data[i].to_int(), expected[i])
  }
}

///|
test "decode_tga_pure: too short raises" {
  let short = b"\x00\x00\x02"
  try {
    let _ = decode_tga_pure(short)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tga_pure: unsupported image type raises" {
  // type 1（颜色映射）
  let out = make_tga_header(1, 1, 24, 1, 0)
  try {
    let _ = decode_tga_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tga_pure: unsupported bpp raises" {
  // bpp=16
  let out = make_tga_header(1, 1, 16, 2, 0)
  try {
    let _ = decode_tga_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tga_pure: zero dimensions raises" {
  let out = make_tga_header(0, 0, 24, 0, 0)
  try {
    let _ = decode_tga_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_tga_pure: truncated pixel data raises" {
  let out = make_tga_header(1, 1, 24, 0, 0)
  // Append only partial pixel data (need 3 bytes for 24-bit)
  out.push(b'\xFF')
  out.push(b'\x00')
  try {
    let _ = decode_tga_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}
