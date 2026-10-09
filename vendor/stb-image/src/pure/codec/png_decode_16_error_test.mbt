// PNG 16-bit 解码错误路径测试
// 覆盖 decode_png_16_pure 的各种错误分支

///|
test "decode_png_16_pure: invalid signature raises" {
  let bad = b"\x00\x00\x00\x00\x00\x00\x00\x00"
  try {
    let _ = decode_png_16_pure(bad)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_png_16_pure: too short raises" {
  let bad = b"\x89PNG\r\n\x1A\n"
  try {
    let _ = decode_png_16_pure(bad)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_png_16_pure: truncated chunk header raises" {
  let out : Array[Byte] = [
    b'\x89', b'P', b'N', b'G', b'\r', b'\n', b'\x1A', b'\n', b'\x00', b'\x00', // truncated chunk length
  ]
  let bad = Bytes::from_array(out)
  try {
    let _ = decode_png_16_pure(bad)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_png_16_pure: req_channels out of range raises" {
  let out : Array[Byte] = [
    b'\x89', b'P', b'N', b'G', b'\r', b'\n', b'\x1A', b'\n', b'\x00', b'\x00', b'\x00',
    b'\x0D', // IHDR length=13
     b'I', b'H', b'D', b'R', b'\x00', b'\x00', b'\x00', b'\x01', // width=1
     b'\x00', b'\x00', b'\x00', b'\x01', // height=1
     b'\x10', // bit depth=16
     b'\x02', // color type=2 (RGB)
     b'\x00', b'\x00', b'\x00',
  ]
  let bad = Bytes::from_array(out)
  try {
    let _ = decode_png_16_pure(bad, req_channels=Some(5))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_png_16_pure: no IHDR raises" {
  let out : Array[Byte] = [
    b'\x89', b'P', b'N', b'G', b'\r', b'\n', b'\x1A', b'\n', b'\x00', b'\x00', b'\x00',
    b'\x04', // some chunk
     b't', b'E', b'X', b't', b'\x00', b'\x00', b'\x00', b'\x00', // crc
  ]
  let bad = Bytes::from_array(out)
  try {
    let _ = decode_png_16_pure(bad)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_png_16_pure: chunk data beyond file raises" {
  let out : Array[Byte] = [
    b'\x89', b'P', b'N', b'G', b'\r', b'\n', b'\x1A', b'\n', b'\x00', b'\x00', b'\xFF',
    b'\xFF', // IHDR length=65535 (beyond file)
     b'I', b'H', b'D', b'R',
  ]
  let bad = Bytes::from_array(out)
  try {
    let _ = decode_png_16_pure(bad)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_png_16_pure: interlace not supported raises" {
  let out : Array[Byte] = [
    b'\x89', b'P', b'N', b'G', b'\r', b'\n', b'\x1A', b'\n', b'\x00', b'\x00', b'\x00',
    b'\x0D', // IHDR length=13
     b'I', b'H', b'D', b'R', b'\x00', b'\x00', b'\x00', b'\x01', // width=1
     b'\x00', b'\x00', b'\x00', b'\x01', // height=1
     b'\x10', // bit depth=16
     b'\x02', // color type=2 (RGB)
     b'\x00', b'\x00', b'\x01', // interlace=1
  ]
  let bad = Bytes::from_array(out)
  try {
    let _ = decode_png_16_pure(bad)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_png_16_pure: invalid color type raises" {
  let out : Array[Byte] = [
    b'\x89', b'P', b'N', b'G', b'\r', b'\n', b'\x1A', b'\n', b'\x00', b'\x00', b'\x00',
    b'\x0D', // IHDR length=13
     b'I', b'H', b'D', b'R', b'\x00', b'\x00', b'\x00', b'\x01', // width=1
     b'\x00', b'\x00', b'\x00', b'\x01', // height=1
     b'\x10', // bit depth=16
     b'\x05', // color type=5 (invalid)
     b'\x00', b'\x00', b'\x00',
  ]
  let bad = Bytes::from_array(out)
  try {
    let _ = decode_png_16_pure(bad)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_png_16_pure: IHDR too short raises" {
  // chunk_len=12 < 13
  let out : Array[Byte] = [
    b'\x89', b'P', b'N', b'G', b'\r', b'\n', b'\x1A', b'\n', b'\x00', b'\x00', b'\x00',
    b'\x0C', // IHDR length=12 (too short)
     b'I', b'H', b'D', b'R', b'\x00', b'\x00', b'\x00', b'\x01', // width=1
     b'\x00', b'\x00', b'\x00', b'\x01', // height=1
     b'\x10', // bit depth=16
     b'\x02', // color type=2
     b'\x00', b'\x00', b'\x00', // missing 1 byte
  ]
  let bad = Bytes::from_array(out)
  try {
    let _ = decode_png_16_pure(bad)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_png_16_pure: width zero raises" {
  let out : Array[Byte] = [
    b'\x89', b'P', b'N', b'G', b'\r', b'\n', b'\x1A', b'\n', b'\x00', b'\x00', b'\x00',
    b'\x0D', // IHDR length=13
     b'I', b'H', b'D', b'R', b'\x00', b'\x00', b'\x00', b'\x00', // width=0
     b'\x00', b'\x00', b'\x00', b'\x01', // height=1
     b'\x10', // bit depth=16
     b'\x02', // color type=2
     b'\x00', b'\x00', b'\x00',
  ]
  let bad = Bytes::from_array(out)
  try {
    let _ = decode_png_16_pure(bad)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_png_16_pure: invalid bit depth raises" {
  // bit_depth=4 (not 8 or 16)
  let out : Array[Byte] = [
    b'\x89', b'P', b'N', b'G', b'\r', b'\n', b'\x1A', b'\n', b'\x00', b'\x00', b'\x00',
    b'\x0D', // IHDR length=13
     b'I', b'H', b'D', b'R', b'\x00', b'\x00', b'\x00', b'\x01', // width=1
     b'\x00', b'\x00', b'\x00', b'\x01', // height=1
     b'\x04', // bit depth=4 (invalid)
     b'\x02', // color type=2
     b'\x00', b'\x00', b'\x00',
  ]
  let bad = Bytes::from_array(out)
  try {
    let _ = decode_png_16_pure(bad)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}
