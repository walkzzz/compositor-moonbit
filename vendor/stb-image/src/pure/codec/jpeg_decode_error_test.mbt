// JPEG 解码错误路径测试
// 覆盖 decode_jpeg_pure 的各种错误分支

///|
test "decode_jpeg_pure: empty data raises" {
  try {
    let _ = decode_jpeg_pure(b"")
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "decode_jpeg_pure: wrong SOI marker raises" {
  // not FF D8
  let data = b"\x00\x00\xFF\xC0"
  try {
    let _ = decode_jpeg_pure(data)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "decode_jpeg_pure: only SOI raises" {
  // FF D8 only, no other markers
  let data = b"\xFF\xD8"
  try {
    let _ = decode_jpeg_pure(data)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "decode_jpeg_pure: single byte raises" {
  let data = b"\xFF"
  try {
    let _ = decode_jpeg_pure(data)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "decode_jpeg_pure: truncated after SOI raises" {
  // Just SOI marker with nothing else
  let data : Array[Byte] = [0xFF, 0xD8]
  try {
    let _ = decode_jpeg_pure(Bytes::from_array(data))
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "decode_jpeg_pure: SOF0 too short raises" {
  // FF D8 FF C0 with insufficient data for SOF0 header
  // SOI(2) + SOF0 marker(2) + length(2) + precision(1) + height(2) + width(2) + num_comp(1) + comp_id(1)
  // = 13 bytes needed, give only 12
  let data : Array[Byte] = [
    0xFF, 0xD8, // SOI
     0xFF, 0xC0, // SOF0 marker
     0x00, 0x0B, // length=11
     0x08, // precision
     0x00, 0x01, // height=1
     0x00, 0x01, // width=1
     0x01, // num_components=1
     0x01, // component_id
    // truncated - missing sampling and quant_table
  ]
  try {
    let _ = decode_jpeg_pure(Bytes::from_array(data))
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "decode_jpeg_pure: invalid dimensions raises" {
  // Construct minimal JPEG with invalid (zero) dimensions
  let data : Array[Byte] = [
    0xFF, 0xD8, // SOI
     0xFF, 0xC0, // SOF0
     0x00, 0x0C, // length=12
     0x08, // precision
     0x00, 0x00, // height=0 (invalid)
     0x00, 0x00, // width=0 (invalid)
     0x01, // num_components=1
     0x01, // component_id
     0x11, // sampling
     0x00, // quant_table
  ]
  try {
    let _ = decode_jpeg_pure(Bytes::from_array(data))
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "decode_jpeg_pure: truncated component data raises" {
  // SOF0 with truncated component info
  // Need at least 2 (SOI) + 2 (marker) + 2 (len) + 9 (header) + 3 (comp) = 18 bytes
  // Give only 17
  let data : Array[Byte] = [
    0xFF, 0xD8, // SOI
     0xFF, 0xC0, // SOF0
     0x00, 0x0C, // length=12
     0x08, // precision
     0x00, 0x08, // height=8
     0x00, 0x08, // width=8
     0x01, // num_components=1
     0x01, // component_id
     0x11, // sampling
    // truncated - missing quant_table
  ]
  try {
    let _ = decode_jpeg_pure(Bytes::from_array(data))
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "decode_jpeg_pure: Huffman table index out of bounds raises" {
  // Construct a JPEG with a Huffman table that has invalid indices
  // This should trigger "JPEG Huffman 索引越界" error
  let data : Array[Byte] = [
    0xFF, 0xD8, // SOI
     0xFF, 0xE0, // APP0 (JFIF)
     0x00, 0x10, // length=16
     0x4A, 0x46, 0x49, 0x46, 0x00, // "JFIF\x00"
     0x01, 0x01, // version
     0x00, // units
     0x00, 0x01, // Xdensity
     0x00, 0x01, // Ydensity
     0x00, 0x00, // thumbnail
     0xFF, 0xC0, // SOF0
     0x00, 0x0C, // length=12
     0x08, // precision
     0x00, 0x08, // height=8
     0x00, 0x08, // width=8
     0x01, // num_components=1
     0x01, // component_id
     0x11, // sampling
     0x00, // quant_table
     0xFF, 0xDB, // DQT
     0x00, 0x43, // length=67
     0x00, // table id
    // 64 quantization values (all zeros for simplicity)
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF,
    0xC4, // DHT (Huffman table)
     0x00, 0x13, // length=19
     0x00, // table class=0 (DC), table id=0
    // 16 counts (all zeros except first)
     0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
    // 1 value
     0x00, 0xFF, 0xDA, // SOS
     0x00, 0x08, // length=8
     0x01, // num_components=1
     0x01, // component_id
     0x00, // dc_table=0
     0x00, // ac_table=0
     0x00, 0x3F, 0x00, // spectral start=0, end=63, approximation=0
    // Dummy scan data that will trigger Huffman error
     0xFF, 0xFF, 0xFF, 0xFF,
  ]
  try {
    let _ = decode_jpeg_pure(Bytes::from_array(data))
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}
