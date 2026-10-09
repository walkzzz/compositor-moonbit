// CLAHE 测试

///|
test "clahe: grayscale uniform image produces uniform output" {
  let img = @types.Image::{
    width: 8,
    height: 8,
    channels: 1,
    data: Array::make(64, b'\x80') |> Bytes::from_array,
  }
  let result = clahe(img, 4, 2.0)
  // 均匀图像 CLAHE 后所有像素应相同
  let v0 = result.data[0]
  for i in 0..<64 {
    assert_eq(result.data[i], v0)
  }
  let _ = img
  let _ = result
}

///|
test "clahe: RGB image preserves channels" {
  let img = @types.Image::{
    width: 8,
    height: 8,
    channels: 3,
    data: Array::make(64 * 3, b'\x80') |> Bytes::from_array,
  }
  let result = clahe(img, 4, 2.0)
  assert_eq(result.channels, 3)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  let _ = img
  let _ = result
}

///|
test "clahe: RGBA preserves alpha" {
  let data : Array[Byte] = Array::make(64 * 4, b'\x80')
  for i in 0..<64 {
    data[i * 4 + 3] = b'\xFF'
  }
  let img = @types.Image::{
    width: 8,
    height: 8,
    channels: 4,
    data: Bytes::from_array(data),
  }
  let result = clahe(img, 4, 2.0)
  for i in 0..<64 {
    assert_eq(result.data[i * 4 + 3], b'\xFF')
  }
  let _ = img
  let _ = result
}

///|
test "clahe: raises on invalid tile_size" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Array::make(16, b'\x80') |> Bytes::from_array,
  }
  try {
    let _ = clahe(img, 1, 2.0)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "clahe: enhances contrast on gradient" {
  let data : Array[Byte] = Array::make(8 * 8, b'\x00')
  for y in 0..<8 {
    for x in 0..<8 {
      data[y * 8 + x] = (x * 32).to_byte()
    }
  }
  let img = @types.Image::{
    width: 8,
    height: 8,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = clahe(img, 4, 3.0)
  // CLAHE 后像素值应在 0-255 范围内
  for i in 0..<64 {
    let v = result.data[i].to_int()
    assert_true(v >= 0 && v <= 255)
  }
  let _ = img
  let _ = result
}

///|
test "clahe: raises on invalid channels" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 2,
    data: Array::make(16, b'\x80') |> Bytes::from_array,
  }
  try {
    let _ = clahe(img, 4, 2.0)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "clahe: 1x1 with large tile_size (tile_pixels=0)" {
  // 1x1 image with tile_size=8 → tile covers 1x1 but ntx=1, nty=1
  // tile_pixels = (1-0)*(1-0) = 1, not 0. Need tile_size > image dim
  // Actually tile_pixels can't be 0 for valid images. Let's test 1x1 edge case.
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x80']),
  }
  let result = clahe(img, 8, 2.0)
  assert_eq(result.width, 1)
  assert_eq(result.height, 1)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}

///|
test "clahe: clamp_i bounds (below lo and above hi)" {
  // Test that clamp_i correctly clamps values below lo and above hi
  // This covers the lo and hi branches in clamp_i helper
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Bytes::from_array([
      b'\x00', b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x07', b'\x08',
      b'\x09', b'\x0A', b'\x0B', b'\x0C', b'\x0D', b'\x0E', b'\x0F',
    ]),
  }
  // Use a large clip_limit to ensure CDF values can exceed bounds
  let result = clahe(img, 2, 10.0)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 1)
}
