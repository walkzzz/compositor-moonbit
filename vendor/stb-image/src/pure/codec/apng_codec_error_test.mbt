// APNG 解码错误路径测试
// 覆盖 decode_apng_pure 的各种错误分支

///|
test "decode_apng_pure: too short raises" {
  try {
    let _ = decode_apng_pure(b"\x89PNG\r\n\x1A\n\x00\x00\x00\x00")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_apng_pure: no IHDR raises" {
  // PNG signature + acTL but no IHDR
  let sig : Array[Byte] = [
    b'\x89', b'P', b'N', b'G', b'\r', b'\n', b'\x1A', b'\n',
  ]
  // acTL chunk: type=0x61\x63\x54\x4C, length=8, data=0x00\x00\x00\x01\x00\x00\x00\x01
  let actl : Array[Byte] = [
    0x00, 0x00, 0x00, 0x08, // length=8
     b'a', b'c', b'T', b'L', // type
     0x00, 0x00, 0x00, 0x01, // num_frames=1
     0x00, 0x00, 0x00, 0x01, // num_plays=1
     0xA1, 0xB2, 0xC3, 0xD4, // crc
  ]
  let data : Array[Byte] = []
  for b in sig {
    data.push(b)
  }
  for b in actl {
    data.push(b)
  }
  try {
    let _ = decode_apng_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_apng_pure: chunk data beyond file raises" {
  // PNG signature followed by chunk with length beyond file
  let out : Array[Byte] = [
    b'\x89', b'P', b'N', b'G', b'\r', b'\n', b'\x1A', b'\n', b'\x00', b'\x00', b'\xFF',
    b'\xFF', // chunk length=65535
     b'I', b'H', b'D', b'R',
  ]
  try {
    let _ = decode_apng_pure(Bytes::from_array(out))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_apng_pure: invalid signature raises" {
  try {
    let _ = decode_apng_pure(b"\x00\x00\x00\x00\x00\x00\x00\x00")
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "encode_apng_pure: empty frames raises" {
  let anim = @types.PngAnimation::{ frames: [], delays: [] }
  try {
    let _ = encode_apng_pure(anim)
    assert_true(false)
  } catch {
    @types.LoadError::EncodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "decode_apng_pure: no IDAT chunk raises" {
  // PNG with IHDR and acTL but no IDAT
  let sig : Array[Byte] = [
    b'\x89', b'P', b'N', b'G', b'\r', b'\n', b'\x1A', b'\n',
  ]
  // IHDR chunk (minimal 1x1 RGB)
  let ihdr : Array[Byte] = [
    0x00, 0x00, 0x00, 0x0D, // length=13
     b'I', b'H', b'D', b'R', 0x00, 0x00, 0x00, 0x01, // width=1
     0x00, 0x00, 0x00, 0x01, // height=1
     0x08, // bit depth=8
     0x02, // color type=2 (RGB)
     0x00, b'\x00', b'\x00', // compression, filter, interlace
  ]
  // acTL chunk
  let actl : Array[Byte] = [
    0x00, 0x00, 0x00, 0x08, // length=8
     b'a', b'c', b'T', b'L', 0x00, 0x00, 0x00, 0x01, // num_frames=1
     0x00, 0x00, 0x00, 0x01, // num_plays=1
     0x00, 0x00, 0x00, 0x00, // crc
  ]
  let data : Array[Byte] = []
  for b in sig {
    data.push(b)
  }
  for b in ihdr {
    data.push(b)
  }
  for b in actl {
    data.push(b)
  }
  try {
    let _ = decode_apng_pure(Bytes::from_array(data))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}
