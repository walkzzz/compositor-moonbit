// 纯 MoonBit ICNS 编解码测试

///|
fn make_32x32_rgba_image() -> @types.Image {
  // 32x32 RGBA 全红
  let data : Array[Byte] = Array::make(32 * 32 * 4, b'\x00')
  for i in 0..<1024 {
    data[i * 4] = b'\xFF'
    data[i * 4 + 3] = b'\xFF'
  }
  @types.Image::{
    width: 32,
    height: 32,
    channels: 4,
    data: Bytes::from_array(data),
  }
}

///|
test "encode_icns_pure / decode_icns_pure: 32x32 PNG roundtrip" {
  let img = make_32x32_rgba_image()
  let icns = encode_icns_pure(img)
  // 检查 magic "icns"
  assert_eq(icns[0].to_int(), 0x69)
  assert_eq(icns[1].to_int(), 0x63)
  assert_eq(icns[2].to_int(), 0x6E)
  assert_eq(icns[3].to_int(), 0x73)
  let decoded = decode_icns_pure(icns)
  assert_eq(decoded.width, 32)
  assert_eq(decoded.height, 32)
  // PNG 编码器可能剥离全不透明 alpha，channels 可能为 3 或 4
  let ch = decoded.channels
  // 全红
  for i in 0..<1024 {
    assert_eq(decoded.data[i * ch].to_int(), 255)
  }
}

///|
test "encode_icns_pure: 64x64 使用 ic13 type" {
  let data : Array[Byte] = Array::make(64 * 64 * 4, b'\xFF')
  let img = @types.Image::{
    width: 64,
    height: 64,
    channels: 4,
    data: Bytes::from_array(data),
  }
  let icns = encode_icns_pure(img)
  // chunk type 在 offset 8-11，应为 "ic13"
  assert_eq(icns[8].to_int(), 0x69) // 'i'
  assert_eq(icns[9].to_int(), 0x63) // 'c'
  assert_eq(icns[10].to_int(), 0x31) // '1'
  assert_eq(icns[11].to_int(), 0x33) // '3'
}

///|
test "encode_icns_pure: 128x128 使用 ic07 type" {
  let data : Array[Byte] = Array::make(128 * 128 * 3, b'\x80')
  let img = @types.Image::{
    width: 128,
    height: 128,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let icns = encode_icns_pure(img)
  // chunk type 应为 "ic07"
  assert_eq(icns[10].to_int(), 0x30) // '0'
  assert_eq(icns[11].to_int(), 0x37) // '7'
  let decoded = decode_icns_pure(icns)
  assert_eq(decoded.width, 128)
  assert_eq(decoded.height, 128)
}

///|
test "decode_icns_pure: ARGB 16x16 解码" {
  // 手工构造 ic04 ARGB 16x16 ICNS
  let out : Array[Byte] = []
  // ICNS 头
  out.push(b'\x69')
  out.push(b'\x63')
  out.push(b'\x6E')
  out.push(b'\x73')
  let pixel_count = 16 * 16
  let chunk_data_size = pixel_count * 4
  let chunk_total = 8 + chunk_data_size
  let file_size = 8 + chunk_total
  // file size BE
  out.push(((file_size >> 24) & 0xFF).to_byte())
  out.push(((file_size >> 16) & 0xFF).to_byte())
  out.push(((file_size >> 8) & 0xFF).to_byte())
  out.push((file_size & 0xFF).to_byte())
  // chunk type "ic04"
  out.push(b'\x69')
  out.push(b'\x63')
  out.push(b'\x30')
  out.push(b'\x34')
  // chunk length BE
  out.push(((chunk_total >> 24) & 0xFF).to_byte())
  out.push(((chunk_total >> 16) & 0xFF).to_byte())
  out.push(((chunk_total >> 8) & 0xFF).to_byte())
  out.push((chunk_total & 0xFF).to_byte())
  // ARGB 数据：全红不透明
  for _ in 0..<pixel_count {
    out.push(b'\xFF') // A
    out.push(b'\xFF') // R
    out.push(b'\x00') // G
    out.push(b'\x00') // B
  }
  let icns = Bytes::from_array(out)
  let decoded = decode_icns_pure(icns)
  assert_eq(decoded.width, 16)
  assert_eq(decoded.height, 16)
  assert_eq(decoded.channels, 4)
  // 第一个像素 RGBA = (255, 0, 0, 255)
  assert_eq(decoded.data[0].to_int(), 255)
  assert_eq(decoded.data[1].to_int(), 0)
  assert_eq(decoded.data[2].to_int(), 0)
  assert_eq(decoded.data[3].to_int(), 255)
}

///|
test "decode_icns_pure: magic 不匹配报错" {
  try {
    let _ = decode_icns_pure(b"XXXX\x00\x00\x00\x08")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_icns_pure: 数据过短报错" {
  try {
    let _ = decode_icns_pure(b"\x69\x63")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_icns_pure: too short raises" {
  try {
    let _ = decode_icns_pure(b"\x69\x63\x6E\x73")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_icns_pure: wrong magic raises" {
  try {
    let _ = decode_icns_pure(
      b"\x00\x00\x00\x00\x00\x00\x00\x08\x00\x00\x00\x01\x00\x00\x00\x01",
    )
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_icns_pure: no valid chunk raises" {
  // ICNS header with no valid icon chunks
  let data : Array[Byte] = [
    b'i', b'c', b'n', b's', // magic
     0x00, 0x00, 0x00, 0x0C, // size=12
     0x00, 0x00, 0x00, 0x01, // version
     0x31, 0x52, 0x47, 0x42, // type='1RGB' (valid)
     0x00, 0x00, 0x00, 0x04, // size=4
     b'\x00', b'\x00', b'\x00', b'\x00', // data (too short for ARGB)
  ]
  try {
    let _ = decode_icns_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}
