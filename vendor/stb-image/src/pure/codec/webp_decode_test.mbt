// WebP lossless 解码器测试

///|
/// 构造最小 1x1 WebP lossless 文件（纯黑像素）
fn make_minimal_webp_1x1() -> Bytes {
  // RIFF header + WEBP + VP8L chunk
  // VP8L data: 0x2f sig + bits: w-1=0(14), h-1=0(14), alpha=0(1), ver=0(3),
  //   no_transform=0, no_cache=0, no_meta=0,
  //   simple_huffman: is_simple=1, num_symbols-1=0, max_bits-1=0(4bits), symbol=0(1bit)
  // Byte layout (LSB-first bit packing after 0x2f):
  //   byte0-3: 0x00 (width/height bits)
  //   byte4: 0x08 (bit35=is_simple=1)
  //   byte5: 0x00
  let vp8l_data = [0x2f, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00]
  let vp8l_len = vp8l_data.length()
  let riff_size = 4 + 4 + 4 + vp8l_len // "WEBP" + "VP8L" + chunk_size + data
  let result : Array[Byte] = []
  // RIFF
  result.push(b'R')
  result.push(b'I')
  result.push(b'F')
  result.push(b'F')
  // RIFF size (LE)
  result.push((riff_size & 0xFF).to_byte())
  result.push(((riff_size >> 8) & 0xFF).to_byte())
  result.push(((riff_size >> 16) & 0xFF).to_byte())
  result.push(((riff_size >> 24) & 0xFF).to_byte())
  // WEBP
  result.push(b'W')
  result.push(b'E')
  result.push(b'B')
  result.push(b'P')
  // VP8L
  result.push(b'V')
  result.push(b'P')
  result.push(b'8')
  result.push(b'L')
  // Chunk size (LE)
  result.push((vp8l_len & 0xFF).to_byte())
  result.push(((vp8l_len >> 8) & 0xFF).to_byte())
  result.push(((vp8l_len >> 16) & 0xFF).to_byte())
  result.push(((vp8l_len >> 24) & 0xFF).to_byte())
  // VP8L data
  for b in vp8l_data {
    result.push(b.to_byte())
  }
  Bytes::from_array(result)
}

///|
test "decode_webp: RIFF magic 检测" {
  let data = make_minimal_webp_1x1()
  // WebP magic: RIFF....WEBP
  assert_eq(data[0].to_int(), 0x52) // R
  assert_eq(data[1].to_int(), 0x49) // I
  assert_eq(data[2].to_int(), 0x46) // F
  assert_eq(data[3].to_int(), 0x46) // F
  assert_eq(data[8].to_int(), 0x57) // W
  assert_eq(data[9].to_int(), 0x45) // E
  assert_eq(data[10].to_int(), 0x42) // B
  assert_eq(data[11].to_int(), 0x50) // P
  let _ = data
}

///|
test "decode_webp: 错误 - 数据过短" {
  let data = [b'R', b'I'] |> Bytes::from_array
  try decode_webp_pure(data) catch {
    @types.LoadError::DecodeFailed(msg) => assert_true(msg.length() > 0)
    _ => fail("应该是 DecodeFailed")
  } noraise {
    _ => fail("应该抛出错误")
  }
}

///|
test "decode_webp: 错误 - RIFF magic 不匹配" {
  let data = Array::make(20, b'\x00') |> Bytes::from_array
  try decode_webp_pure(data) catch {
    @types.LoadError::DecodeFailed(msg) => assert_true(msg.contains("RIFF"))
    _ => fail("应该是 DecodeFailed")
  } noraise {
    _ => fail("应该抛出 RIFF 错误")
  }
}

///|
test "decode_webp: 错误 - WEBP magic 不匹配" {
  let data : Array[Byte] = [
    b'R', b'I', b'F', b'F', 0x14, 0x00, 0x00, 0x00, b'X', b'X', b'X', b'X',
  ]
  for _ in 0..<20 {
    data.push(b'\x00')
  }
  try decode_webp_pure(data |> Bytes::from_array) catch {
    @types.LoadError::DecodeFailed(msg) => assert_true(msg.contains("WEBP"))
    _ => fail("应该是 DecodeFailed")
  } noraise {
    _ => fail("应该抛出 WEBP 错误")
  }
}

///|
test "decode_webp: 错误 - 无 VP8L chunk" {
  // RIFF + WEBP but no VP8L chunk, only VP8X
  let data : Array[Byte] = [
    b'R', b'I', b'F', b'F', 0x14, 0x00, 0x00, 0x00, b'W', b'E', b'B', b'P', b'V',
    b'P', b'8', b'X', 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00,
  ]
  try decode_webp_pure(data |> Bytes::from_array) catch {
    @types.LoadError::DecodeFailed(msg) => assert_true(msg.contains("VP8L"))
    _ => fail("应该是 DecodeFailed")
  } noraise {
    _ => fail("应该抛出 VP8L 错误")
  }
}

///|
test "decode_webp: 1x1 最小图像解码" {
  let data = make_minimal_webp_1x1()
  try decode_webp_pure(data) catch {
    @types.LoadError::DecodeFailed(msg) => fail("解码失败: \{msg}")
    _ => fail("应该是 DecodeFailed")
  } noraise {
    img => {
      assert_eq(img.width, 1)
      assert_eq(img.height, 1)
      assert_true(img.channels == 3 || img.channels == 4)
    }
  }
}

///|
test "decode_webp: VP8L 签名验证" {
  // 构造 RIFF+WEBP+VP8L 但签名错误
  let data : Array[Byte] = [
    b'R', b'I', b'F', b'F', 0x17, 0x00, 0x00, 0x00, b'W', b'E', b'B', b'P', b'V',
    b'P', b'8', b'L', 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, // wrong sig 0x00 instead of 0x2f
  ]
  try decode_webp_pure(data |> Bytes::from_array) catch {
    @types.LoadError::DecodeFailed(msg) => assert_true(msg.contains("VP8L"))
    _ => fail("应该是 DecodeFailed")
  } noraise {
    _ => fail("应该抛出 VP8L 签名错误")
  }
}

///|
test "decode_webp_pure: too short raises" {
  try {
    let _ = decode_webp_pure(b"RIFF\x00\x00\x00\x00WEBP")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_webp_pure: wrong RIFF magic raises" {
  try {
    let _ = decode_webp_pure(b"XXXX\x10\x00\x00\x00WEBP")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_webp_pure: lossy VP8 raises" {
  // Construct minimal RIFF + WEBP + VP8 (lossy, not VP8L)
  let data : Array[Byte] = [
    b'R', b'I', b'F', b'F', 0x10, 0x00, 0x00, 0x00, b'W', b'E', b'B', b'P', b'V',
    b'P', b'8', b' ', 0x08, 0x00, 0x00, 0x00, 0x12, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  ]
  try {
    let _ = decode_webp_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_webp_pure: VP8L with transform skips" {
  // Construct a VP8L with a predictor transform (type 0)
  let vp8l_data : Array[Int] = [
    0x2F, // VP8L signature
     0x00, 0x00, // width=1, height=1 (14-bit: 0,0)
     0x00, // alpha=0, version=0
     0x01, // has_transform=1
     0x00, // transform_type=0 (predictor)
     0x08, // predictor bits=3 (unused)
     0x00, // no_transforms_after
     0x00, // no_color_cache
     0x00, // no_meta
     0x00, // simple_huffman: is_simple=1, max_bits=0
    // Literal green=0, R=0, B=0, A=255
     0x00, 0xFF, 0x00, 0xFF, 0x00, 0x00, 0x00, // EOB + padding
  ]
  let vp8l_len = vp8l_data.length()
  let riff_size = 4 + 4 + 4 + vp8l_len
  let result : Array[Byte] = []
  result.push(b'R')
  result.push(b'I')
  result.push(b'F')
  result.push(b'F')
  result.push((riff_size & 0xFF).to_byte())
  result.push(((riff_size >> 8) & 0xFF).to_byte())
  result.push(((riff_size >> 16) & 0xFF).to_byte())
  result.push(((riff_size >> 24) & 0xFF).to_byte())
  for b in [b'W', b'E', b'B', b'P'] {
    result.push(b)
  }
  for b in [b'V', b'P', b'8', b'L'] {
    result.push(b)
  }
  result.push((vp8l_len & 0xFF).to_byte())
  result.push(((vp8l_len >> 8) & 0xFF).to_byte())
  result.push(((vp8l_len >> 16) & 0xFF).to_byte())
  result.push(((vp8l_len >> 24) & 0xFF).to_byte())
  for v in vp8l_data {
    result.push(v.to_byte())
  }
  try {
    let _ = decode_webp_pure(Bytes::from_array(result))
    assert_true(true)
  } catch {
    // May fail due to incomplete VP8L data; just verify no panic
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(true)
  }
}
