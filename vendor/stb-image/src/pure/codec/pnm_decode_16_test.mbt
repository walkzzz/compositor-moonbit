// 纯 MoonBit PNM 16-bit 解码器测试
// 覆盖 decode_pnm_16_pure: P5/P6 16-bit/8-bit、错误路径
// push_str 复用 pnm_decode_test.mbt 中的定义

///|
test "decode_pnm_16_pure: P5 16-bit grayscale 2x2" {
  // P5 2x2 maxval=65535 (16-bit big-endian)
  let out : Array[Byte] = []
  push_str(out, "P5\n2 2\n65535\n")
  // 4 pixels, 16-bit big-endian each: 0x0001, 0x0100, 0x7FFF, 0xFFFF
  out.push(b'\x00')
  out.push(b'\x01')
  out.push(b'\x01')
  out.push(b'\x00')
  out.push(b'\x7F')
  out.push(b'\xFF')
  out.push(b'\xFF')
  out.push(b'\xFF')
  let img = decode_pnm_16_pure(Bytes::from_array(out))
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 1)
  // 16-bit stored as little-endian: hi/lo swapped
  // 0x0001 -> LE: 0x01, 0x00
  assert_eq(img.data[0].to_int(), 0x01)
  assert_eq(img.data[1].to_int(), 0x00)
  // 0x0100 -> LE: 0x00, 0x01
  assert_eq(img.data[2].to_int(), 0x00)
  assert_eq(img.data[3].to_int(), 0x01)
  // 0x7FFF -> LE: 0xFF, 0x7F
  assert_eq(img.data[4].to_int(), 0xFF)
  assert_eq(img.data[5].to_int(), 0x7F)
  // 0xFFFF -> LE: 0xFF, 0xFF
  assert_eq(img.data[6].to_int(), 0xFF)
  assert_eq(img.data[7].to_int(), 0xFF)
}

///|
test "decode_pnm_16_pure: P6 16-bit RGB 1x1" {
  let out : Array[Byte] = []
  push_str(out, "P6\n1 1\n65535\n")
  // 1 pixel RGB 16-bit: (0x1234, 0x5678, 0x9ABC)
  out.push(b'\x12')
  out.push(b'\x34')
  out.push(b'\x56')
  out.push(b'\x78')
  out.push(b'\x9A')
  out.push(b'\xBC')
  let img = decode_pnm_16_pure(Bytes::from_array(out))
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 3)
  // LE: 0x34,0x12, 0x78,0x56, 0xBC,0x9A
  assert_eq(img.data[0].to_int(), 0x34)
  assert_eq(img.data[1].to_int(), 0x12)
  assert_eq(img.data[2].to_int(), 0x78)
  assert_eq(img.data[3].to_int(), 0x56)
  assert_eq(img.data[4].to_int(), 0xBC)
  assert_eq(img.data[5].to_int(), 0x9A)
}

///|
test "decode_pnm_16_pure: P5 8-bit upsample to 16-bit" {
  // maxval=255 -> 8-bit, upscale: v * 257
  let out : Array[Byte] = []
  push_str(out, "P5\n2 1\n255\n")
  out.push(b'\x00')
  out.push(b'\xFF')
  let img = decode_pnm_16_pure(Bytes::from_array(out))
  assert_eq(img.width, 2)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 1)
  // 0 * 257 = 0 -> LE: 0x00, 0x00
  assert_eq(img.data[0].to_int(), 0x00)
  assert_eq(img.data[1].to_int(), 0x00)
  // 255 * 257 = 65535 -> LE: 0xFF, 0xFF
  assert_eq(img.data[2].to_int(), 0xFF)
  assert_eq(img.data[3].to_int(), 0xFF)
}

///|
test "decode_pnm_16_pure: P6 8-bit upsample to 16-bit" {
  let out : Array[Byte] = []
  push_str(out, "P6\n1 1\n255\n")
  out.push(b'\x80')
  out.push(b'\x40')
  out.push(b'\xC0')
  let img = decode_pnm_16_pure(Bytes::from_array(out))
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 3)
  // 0x80 * 257 = 32896 = 0x8080 -> LE: 0x80, 0x80
  assert_eq(img.data[0].to_int(), 0x80)
  assert_eq(img.data[1].to_int(), 0x80)
  // 0x40 * 257 = 16448 = 0x4040 -> LE: 0x40, 0x40
  assert_eq(img.data[2].to_int(), 0x40)
  assert_eq(img.data[3].to_int(), 0x40)
  // 0xC0 * 257 = 49344 = 0xC0C0 -> LE: 0xC0, 0xC0
  assert_eq(img.data[4].to_int(), 0xC0)
  assert_eq(img.data[5].to_int(), 0xC0)
}

///|
test "decode_pnm_16_pure: P5 with comments" {
  let out : Array[Byte] = []
  push_str(out, "P5\n# comment\n2 1\n65535\n")
  out.push(b'\x00')
  out.push(b'\x10')
  out.push(b'\x01')
  out.push(b'\x00')
  let img = decode_pnm_16_pure(Bytes::from_array(out))
  assert_eq(img.width, 2)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 1)
  // 0x0010 -> LE: 0x10, 0x00
  assert_eq(img.data[0].to_int(), 0x10)
  assert_eq(img.data[1].to_int(), 0x00)
}

///|
test "decode_pnm_16_pure: data too short" {
  try {
    let _ = decode_pnm_16_pure(Bytes::from_array([b'\x50']))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "decode_pnm_16_pure: invalid magic" {
  let out : Array[Byte] = []
  push_str(out, "P7\n1 1\n255\n")
  try {
    let _ = decode_pnm_16_pure(Bytes::from_array(out))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "decode_pnm_16_pure: invalid maxval" {
  let out : Array[Byte] = []
  push_str(out, "P5\n1 1\n0\n")
  try {
    let _ = decode_pnm_16_pure(Bytes::from_array(out))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "decode_pnm_16_pure: invalid dimensions" {
  let out : Array[Byte] = []
  push_str(out, "P5\n0 1\n255\n")
  try {
    let _ = decode_pnm_16_pure(Bytes::from_array(out))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "decode_pnm_16_pure: 16-bit pixel data insufficient" {
  let out : Array[Byte] = []
  push_str(out, "P5\n2 2\n65535\n")
  // Only 2 bytes instead of 8
  out.push(b'\x00')
  out.push(b'\x01')
  try {
    let _ = decode_pnm_16_pure(Bytes::from_array(out))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "decode_pnm_16_pure: 8-bit pixel data insufficient" {
  let out : Array[Byte] = []
  push_str(out, "P6\n2 2\n255\n")
  // Only 3 bytes instead of 12
  out.push(b'\xFF')
  out.push(b'\x00')
  out.push(b'\x00')
  try {
    let _ = decode_pnm_16_pure(Bytes::from_array(out))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}
