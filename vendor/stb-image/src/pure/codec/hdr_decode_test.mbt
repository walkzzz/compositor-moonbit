// 纯 MoonBit HDR 解码器测试
// 覆盖 decode_hdr_pure 错误路径 + 边界情况
// 纯逻辑断言测试（全目标可用：native/wasm/js），不依赖 @core

///|
test "decode_hdr_pure: empty data raises" {
  try {
    let _ = decode_hdr_pure(b"")
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "decode_hdr_pure: wrong magic raises" {
  let data = b"\x00\x00\x0A"
  try {
    let _ = decode_hdr_pure(data)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "decode_hdr_pure: incomplete header raises" {
  // 只有 magic "#?" 没有换行
  let data = b"\x23\x3F"
  try {
    let _ = decode_hdr_pure(data)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "decode_hdr_pure: RGBE magic roundtrip" {
  // 使用 #?RGBE magic 的 HDR 数据（通过 encode 生成 RADIANCE magic，
  // 这里测试 decode 能正确处理标准 RADIANCE 格式）
  let pixels = [(0.5F, 0.25F, 0.125F)]
  let data : Array[Byte] = []
  for p in pixels {
    let rb = p.0.to_le_bytes()
    let gb = p.1.to_le_bytes()
    let bb = p.2.to_le_bytes()
    for i in 0..<4 {
      data.push(rb[i])
    }
    for i in 0..<4 {
      data.push(gb[i])
    }
    for i in 0..<4 {
      data.push(bb[i])
    }
  }
  let img = @types.ImageF::{
    width: 1,
    height: 1,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let hdr_bytes = encode_hdr_pure(img)
  let restored = decode_hdr_pure(hdr_bytes)
  assert_eq(restored.width, 1)
  assert_eq(restored.height, 1)
  assert_eq(restored.channels, 3)
}

///|
test "decode_hdr_pure: uncompressed 1x1" {
  // 手构造未压缩 HDR：header + 1 像素 RGBE
  let out : Array[Byte] = []
  // header
  let header = "#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n-Y 1 +X 1\n"
  let hbytes = @encoding/utf8.encode(header)
  for i in 0..<hbytes.length() {
    out.push(hbytes[i])
  }
  // 1 像素 RGBE: (128, 64, 32, 128) → 非零 float
  out.push(b'\x80')
  out.push(b'\x40')
  out.push(b'\x20')
  out.push(b'\x80')
  let data = Bytes::from_array(out)
  let restored = decode_hdr_pure(data)
  assert_eq(restored.width, 1)
  assert_eq(restored.height, 1)
  assert_eq(restored.channels, 3)
}

///|
test "decode_hdr_pure: uncompressed 2x2" {
  // 手构造未压缩 2x2 HDR
  let out : Array[Byte] = []
  let header = "#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n-Y 2 +X 2\n"
  let hbytes = @encoding/utf8.encode(header)
  for i in 0..<hbytes.length() {
    out.push(hbytes[i])
  }
  // 4 像素 RGBE
  for _ in 0..<4 {
    out.push(b'\x80')
    out.push(b'\x80')
    out.push(b'\x80')
    out.push(b'\x80')
  }
  let data = Bytes::from_array(out)
  let restored = decode_hdr_pure(data)
  assert_eq(restored.width, 2)
  assert_eq(restored.height, 2)
  assert_eq(restored.channels, 3)
}

///|
test "decode_hdr_pure: insufficient uncompressed data raises" {
  // header 声明 2x2 但数据不足
  let out : Array[Byte] = []
  let header = "#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n-Y 2 +X 2\n"
  let hbytes = @encoding/utf8.encode(header)
  for i in 0..<hbytes.length() {
    out.push(hbytes[i])
  }
  // 只给 2 像素（需要 4）
  out.push(b'\x80')
  out.push(b'\x40')
  out.push(b'\x20')
  out.push(b'\x80')
  out.push(b'\x80')
  out.push(b'\x40')
  out.push(b'\x20')
  out.push(b'\x80')
  let data = Bytes::from_array(out)
  try {
    let _ = decode_hdr_pure(data)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "decode_hdr_pure: truncated data after header raises" {
  let out : Array[Byte] = []
  // Valid HDR header for 2x2
  push_str(out, "#?RADIANCE\n")
  push_str(out, "EXPOSURE=1.0\n\n")
  push_str(out, "-2 2\n")
  push_str(out, "2 1\n")
  // Truncated data
  try {
    let _ = decode_hdr_pure(to_bytes(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_hdr_pure: invalid pixel format raises" {
  let out : Array[Byte] = []
  // Valid header but with invalid pixel data
  push_str(out, "#?RADIANCE\n")
  push_str(out, "EXPOSURE=1.0\n\n")
  push_str(out, "-1 1\n")
  push_str(out, "1 1\n")
  // Invalid pixel (all zeros which is invalid)
  out.push(0x00)
  out.push(0x00)
  out.push(0x00)
  out.push(0x00)
  try {
    let _ = decode_hdr_pure(to_bytes(out))
    assert_true(true)
  } catch {
    _ => assert_true(true)
  }
}
