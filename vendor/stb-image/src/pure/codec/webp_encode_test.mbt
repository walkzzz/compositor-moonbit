// WebP lossy 编码测试

///|
test "encode_webp_lossy: basic 2x2 RGB" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 3,
    data: Bytes::from_array([
      b'\xFF', b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\x00', b'\xFF',
      b'\xFF', b'\xFF', b'\x00',
    ]),
  }
  let result = @codec.encode_webp_lossy_pure(img, quality=75)
  // RIFF header
  assert_eq(result[0], b'\x52') // 'R'
  assert_eq(result[1], b'\x49') // 'I'
  assert_eq(result[2], b'\x46') // 'F'
  assert_eq(result[3], b'\x46') // 'F'
  // WEBP fourcc
  assert_eq(result[8], b'\x57') // 'W'
  assert_eq(result[9], b'\x45') // 'E'
  assert_eq(result[10], b'\x42') // 'B'
  assert_eq(result[11], b'\x50') // 'P'
  // VP8 chunk
  assert_eq(result[12], b'\x56') // 'V'
  assert_eq(result[13], b'\x50') // 'P'
  assert_eq(result[14], b'\x38') // '8'
  assert_eq(result[15], b'\x20') // ' '
  let _ = img
  let _ = result
}

///|
test "encode_webp_lossy: quality parameter" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 3,
    data: Bytes::from_array(Array::make(48, b'\x80')),
  }
  let low_q = @codec.encode_webp_lossy_pure(img, quality=10)
  let high_q = @codec.encode_webp_lossy_pure(img, quality=90)
  // Both should produce valid RIFF headers
  assert_eq(low_q[0], b'\x52')
  assert_eq(high_q[0], b'\x52')
  let _ = img
  let _ = low_q
  let _ = high_q
}

///|
test "encode_webp_lossy: invalid dimensions raises" {
  let img = @types.Image::{ width: 0, height: 0, channels: 3, data: b"" }
  try {
    let _ = @codec.encode_webp_lossy_pure(img)
    fail("expected error for zero dimensions")
  } catch {
    _ => ()
  }
}

///|
test "encode_webp_lossy: invalid channels raises" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: Bytes::from_array(Array::make(4, b'\x80')),
  }
  try {
    let _ = @codec.encode_webp_lossy_pure(img)
    fail("expected error for channels=1")
  } catch {
    _ => ()
  }
}

///|
test "encode_webp_lossy: RGBA supported" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 4,
    data: Bytes::from_array(Array::make(16, b'\x80')),
  }
  let result = @codec.encode_webp_lossy_pure(img, quality=50)
  assert_eq(result[0], b'\x52')
  assert_eq(result[8], b'\x57')
  let _ = img
  let _ = result
}

///|
test "encode_webp_lossy: VP8 frame header" {
  let img = @types.Image::{
    width: 16,
    height: 16,
    channels: 3,
    data: Bytes::from_array(Array::make(768, b'\x80')),
  }
  let result = @codec.encode_webp_lossy_pure(img, quality=75)
  // VP8 chunk starts at offset 16 (RIFF 12 + chunk header 8)
  // Wait, RIFF header is 12 bytes (RIFF + size + WEBP), then chunk header is 8 bytes
  // VP8 data starts at offset 20
  // Frame tag: 3 bytes
  // Start code: 0x9D 0x01 0x2A
  assert_eq(result[23], b'\x9D')
  assert_eq(result[24], b'\x01')
  assert_eq(result[25], b'\x2A')
  // Width: 16 = 0x10 0x00
  assert_eq(result[26], b'\x10')
  assert_eq(result[27], b'\x00')
  // Height: 16 = 0x10 0x00
  assert_eq(result[28], b'\x10')
  assert_eq(result[29], b'\x00')
  let _ = img
  let _ = result
}
