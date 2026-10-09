// WebP 解码错误路径测试
// 覆盖 decode_webp_pure 的各种错误分支

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
test "decode_webp_pure: no VP8L chunk raises" {
  // RIFF + WEBP but no VP8L chunk
  let data : Array[Byte] = [
    b'R', b'I', b'F', b'F', 0x14, 0x00, 0x00, 0x00, b'W', b'E', b'B', b'P', b'V',
    b'P', b'8', b'X', 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00,
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
test "decode_webp_pure: VP8L signature wrong raises" {
  // RIFF + WEBP + VP8L with wrong signature
  let data : Array[Byte] = [
    b'R', b'I', b'F', b'F', 0x17, 0x00, 0x00, 0x00, b'W', b'E', b'B', b'P', b'V',
    b'P', b'8', b'L', 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, // wrong sig 0x00 instead of 0x2f
  ]
  try {
    let _ = decode_webp_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}
