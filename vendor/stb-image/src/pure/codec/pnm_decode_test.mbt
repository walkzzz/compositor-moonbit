// 纯 MoonBit PNM 解码器测试
// 纯逻辑断言测试（全目标可用：native/wasm/js），不依赖 @core
// 手构造 PNM 字节流验证解码正确性，覆盖 P5/P6/注释/whitespace/错误路径
// 规范: https://netpbm.sourceforge.net/doc/pgm.html / ppm.html

///|
fn push_str(arr : Array[Byte], s : String) -> Unit {
  let n = s.length()
  for i in 0..<n {
    arr.push(s[i].to_int().to_byte())
  }
}

///|
test "decode_pnm_pure: P6 2x2 RGB basic" {
  let out : Array[Byte] = []
  push_str(out, "P6\n2 2\n255\n")
  // 2x2 RGB: (255,0,0) (0,255,0) (0,0,255) (255,255,255)
  out.push(b'\xFF')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\xFF')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\xFF')
  out.push(b'\xFF')
  out.push(b'\xFF')
  out.push(b'\xFF')
  let img = decode_pnm_pure(to_bytes(out))
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 3)
  let expected = [255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255]
  for i in 0..<12 {
    assert_eq(img.data[i].to_int(), expected[i])
  }
}

///|
test "decode_pnm_pure: P5 2x2 grayscale basic" {
  let out : Array[Byte] = []
  push_str(out, "P5\n2 2\n255\n")
  // 2x2 灰度: 0, 64, 128, 255
  out.push(b'\x00')
  out.push(b'\x40')
  out.push(b'\x80')
  out.push(b'\xFF')
  let img = decode_pnm_pure(to_bytes(out))
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 1)
  let expected = [0, 64, 128, 255]
  for i in 0..<4 {
    assert_eq(img.data[i].to_int(), expected[i])
  }
}

///|
test "decode_pnm_pure: comment line in header" {
  let out : Array[Byte] = []
  // "P6\n# comment\n2 2\n# comment2\n255\n"
  push_str(out, "P6\n# comment\n2 2\n# comment2\n255\n")
  // 2x2 RGB pixels
  out.push(b'\xFF')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\xFF')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\x00')
  out.push(b'\xFF')
  out.push(b'\xFF')
  out.push(b'\xFF')
  out.push(b'\xFF')
  let img = decode_pnm_pure(to_bytes(out))
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 3)
  let expected = [255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255]
  for i in 0..<12 {
    assert_eq(img.data[i].to_int(), expected[i])
  }
}

///|
test "decode_pnm_pure: mixed whitespace separators" {
  let out : Array[Byte] = []
  // "P6\t2\n2\t255\n" - tab + LF 混合分隔
  push_str(out, "P6\t2\n2\t255\n")
  // 2x2 RGB pixels
  out.push(b'\x10')
  out.push(b'\x20')
  out.push(b'\x30')
  out.push(b'\x40')
  out.push(b'\x50')
  out.push(b'\x60')
  out.push(b'\x70')
  out.push(b'\x80')
  out.push(b'\x90')
  out.push(b'\xA0')
  out.push(b'\xB0')
  out.push(b'\xC0')
  let img = decode_pnm_pure(to_bytes(out))
  assert_eq(img.width, 2)
  assert_eq(img.height, 2)
  assert_eq(img.channels, 3)
  let expected = [
    0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80, 0x90, 0xA0, 0xB0, 0xC0,
  ]
  for i in 0..<12 {
    assert_eq(img.data[i].to_int(), expected[i])
  }
}

///|
test "decode_pnm_pure: 1x1 minimal image" {
  let out : Array[Byte] = []
  push_str(out, "P6\n1 1\n255\n")
  out.push(b'\x42')
  out.push(b'\x84')
  out.push(b'\xC6')
  let img = decode_pnm_pure(to_bytes(out))
  assert_eq(img.width, 1)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 3)
  assert_eq(img.data[0].to_int(), 0x42)
  assert_eq(img.data[1].to_int(), 0x84)
  assert_eq(img.data[2].to_int(), 0xC6)
}

///|
test "decode_pnm_pure: too short raises" {
  let short = b"\x50\x36"
  try {
    let _ = decode_pnm_pure(short)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_pnm_pure: unsupported magic raises" {
  let out : Array[Byte] = []
  push_str(out, "P3\n2 2\n255\n")
  try {
    let _ = decode_pnm_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_pnm_pure: unsupported maxval raises" {
  let out : Array[Byte] = []
  push_str(out, "P6\n2 2\n65535\n")
  try {
    let _ = decode_pnm_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_pnm_pure: invalid dimensions raises" {
  let out : Array[Byte] = []
  push_str(out, "P6\n0 0\n255\n")
  try {
    let _ = decode_pnm_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_pnm_pure: truncated pixel data raises" {
  let out : Array[Byte] = []
  push_str(out, "P6\n2 2\n255\n")
  // Only provide 2 bytes (need 16 for 2x2 RGB)
  out.push(b'\xFF')
  out.push(b'\x00')
  try {
    let _ = decode_pnm_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}
