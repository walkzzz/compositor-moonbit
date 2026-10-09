///|
test "multi_band_blend: same images produces same image" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: b"\x00\x40\x80\xC0\x10\x50\x90\xD0\x20\x60\xA0\xE0\x30\x70\xB0\xF0",
  }
  let mask = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: b"\xFF\xFF\x00\x00\xFF\xFF\x00\x00\xFF\xFF\x00\x00\xFF\xFF\x00\x00",
  }
  let result = multi_band_blend(img, img, mask, num_bands=2)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 1)
  // Blending identical images should produce the same image
  for i in 0..<16 {
    assert_true((result.data[i].to_int() - img.data[i].to_int()).abs() <= 2)
  }
}

///|
test "multi_band_blend: all-white mask selects img_a" {
  let img_a = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Bytes::from_array(Array::make(16, b'\xFF')),
  }
  let img_b = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Bytes::from_array(Array::make(16, b'\x00')),
  }
  let mask = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Bytes::from_array(Array::make(16, b'\xFF')),
  }
  let result = multi_band_blend(img_a, img_b, mask, num_bands=2)
  // Should be close to img_a (all white)
  for i in 0..<16 {
    assert_true(result.data[i].to_int() > 200)
  }
}

///|
test "multi_band_blend: all-black mask selects img_b" {
  let img_a = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Bytes::from_array(Array::make(16, b'\xFF')),
  }
  let img_b = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Bytes::from_array(Array::make(16, b'\x00')),
  }
  let mask = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Bytes::from_array(Array::make(16, b'\x00')),
  }
  let result = multi_band_blend(img_a, img_b, mask, num_bands=2)
  // Should be close to img_b (all black)
  for i in 0..<16 {
    assert_true(result.data[i].to_int() < 50)
  }
}

///|
test "multi_band_blend: preserves dimensions" {
  let img_a = @types.Image::{
    width: 3,
    height: 2,
    channels: 3,
    data: Bytes::from_array(Array::make(18, b'\x80')),
  }
  let img_b = @types.Image::{
    width: 3,
    height: 2,
    channels: 3,
    data: Bytes::from_array(Array::make(18, b'\x40')),
  }
  let mask = @types.Image::{
    width: 3,
    height: 2,
    channels: 1,
    data: Bytes::from_array(Array::make(6, b'\x80')),
  }
  let result = multi_band_blend(img_a, img_b, mask, num_bands=2)
  assert_eq(result.width, 3)
  assert_eq(result.height, 2)
  assert_eq(result.channels, 3)
}

///|
test "multi_band_blend: mismatched img dimensions raises error" {
  let img_a = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Bytes::from_array(Array::make(16, b'\x80')),
  }
  let img_b = @types.Image::{
    width: 3,
    height: 4,
    channels: 1,
    data: Bytes::from_array(Array::make(12, b'\x80')),
  }
  let mask = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Bytes::from_array(Array::make(16, b'\x80')),
  }
  try {
    let _ = multi_band_blend(img_a, img_b, mask, num_bands=2)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "multi_band_blend: mismatched mask dimensions raises error" {
  let img_a = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Bytes::from_array(Array::make(16, b'\x80')),
  }
  let img_b = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Bytes::from_array(Array::make(16, b'\x80')),
  }
  let mask = @types.Image::{
    width: 3,
    height: 4,
    channels: 1,
    data: Bytes::from_array(Array::make(12, b'\x80')),
  }
  try {
    let _ = multi_band_blend(img_a, img_b, mask, num_bands=2)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}
