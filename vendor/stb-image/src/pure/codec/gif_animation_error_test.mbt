// GIF 动画解码错误路径补充测试
// 覆盖 decode_gif_animation_pure 的各种错误分支

///|
test "decode_gif_animation_pure: truncated header raises" {
  try {
    let _ = decode_gif_animation_pure(b"GIF89")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_animation_pure: truncated logical screen raises" {
  // GIF89a header but truncated logical screen descriptor
  let data : Array[Byte] = [
    b'G', b'I', b'F', b'8', b'9', b'a', 0x10, 0x00, 0x10, 0x00, 0x00, // truncated (need 7 bytes)
  ]
  try {
    let _ = decode_gif_animation_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_animation_pure: truncated color table raises" {
  // GIF with GCT but truncated color table
  let data : Array[Byte] = [
    b'G', b'I', b'F', b'8', b'9', b'a', 0x02, 0x00, 0x02, 0x00, 0x81, 0x00, 0x00, // 2x2, GCT 2^1=2 entries, bg=0
     0xFF, 0x00, // GCT: only 1 entry (need 2)
     0x3B, // trailer
  ]
  try {
    let _ = decode_gif_animation_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_animation_pure: truncated image descriptor raises" {
  // GIF with Image Descriptor but truncated
  let data : Array[Byte] = [
    b'G', b'I', b'F', b'8', b'9', b'a', 0x02, 0x00, 0x02, 0x00, 0x80, 0x00, 0x00, // 2x2, no GCT
     0xFF, 0x00, 0x00, // GCT: red, black
     0x2C, // Image Descriptor start
     0x00, 0x00, // left=0
     0x00, // truncated
  ]
  try {
    let _ = decode_gif_animation_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_animation_pure: invalid LZW min code size raises" {
  // GIF with invalid LZW min code size
  let data : Array[Byte] = [
    b'G', b'I', b'F', b'8', b'9', b'a', 0x02, 0x00, 0x02, 0x00, 0x80, 0x00, 0x00, // 2x2, no GCT
     0xFF, 0x00, 0x00, // GCT: red, black
     0x2C, // Image Descriptor
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // left=0, top=0, w=2, h=2, packed=0
     0x09, // LZW min code size=9 (invalid, must be 2-8)
     0x03, 0x43, 0x00, 0x3B, // LZW data + trailer
  ]
  try {
    let _ = decode_gif_animation_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_animation_pure: no color table raises" {
  // GIF with Image Descriptor but no GCT or LCT
  let data : Array[Byte] = [
    b'G', b'I', b'F', b'8', b'9', b'a', 0x02, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, // 2x2, no GCT
     0x2C, // Image Descriptor
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // left=0, top=0, w=2, h=2, packed=0
     0x02, // LZW min code size
     0x03, 0x43, 0x00, 0x3B, // LZW data + trailer
  ]
  try {
    let _ = decode_gif_animation_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_animation_pure: truncated sub-block raises" {
  // GIF with valid header but truncated LZW sub-block
  let data : Array[Byte] = [
    b'G', b'I', b'F', b'8', b'9', b'a', 0x02, 0x00, 0x02, 0x00, 0x80, 0x00, 0x00, // 2x2, GCT present
     0xFF, 0x00, 0x00, // GCT: red
     0x00, 0x00, 0xFF, // GCT: blue
     0x2C, // Image Descriptor
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // left=0, top=0, w=2, h=2, packed=0
     0x02, // LZW min code size
     0x05, 0x01, 0x02, 0x03, 0x04, // sub-block with length 5 but only 4 bytes
  ]
  try {
    let _ = decode_gif_animation_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_gif_animation_pure: unknown block type raises" {
  // GIF with unknown block type after image data
  let data : Array[Byte] = [
    b'G', b'I', b'F', b'8', b'9', b'a', 0x01, 0x00, 0x01, 0x00, 0x80, 0x00, 0x00, // 1x1, GCT present
     0xFF, 0x00, 0x00, // GCT: red
     0x00, 0x00, 0xFF, // GCT: blue
     0x2C, // Image Descriptor
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // left=0, top=0, w=1, h=1, packed=0
     0x02, // LZW min code size
     0x03, 0x43, 0x00, // LZW data + trailer
     0x01, // unknown block type
     0x00, // empty sub-block
  ]
  try {
    let _ = decode_gif_animation_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}
