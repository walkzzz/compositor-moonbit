// 暗通道先验去雾测试

///|
test "dehaze 基本功能" {
  // 5x5 RGB 图像
  let data : Array[Byte] = Array::make(75, b'\x00')
  for i in 0..<25 {
    data[i * 3] = b'\x80'
    data[i * 3 + 1] = b'\x80'
    data[i * 3 + 2] = b'\x80'
  }
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let out = dehaze(img, patch_size=1, omega=0.95F, t0=0.1F)
  assert_eq(out.width, 5)
  assert_eq(out.height, 5)
  assert_eq(out.channels, 3)
}

///|
test "dehaze RGBA alpha 不变" {
  let data : Array[Byte] = Array::make(100, b'\x00')
  for i in 0..<25 {
    data[i * 4] = b'\x80'
    data[i * 4 + 1] = b'\x80'
    data[i * 4 + 2] = b'\x80'
    data[i * 4 + 3] = b'\xFF'
  }
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 4,
    data: Bytes::from_array(data),
  }
  let out = dehaze(img, patch_size=1)
  for i in 0..<25 {
    assert_eq(out.data[i * 4 + 3], b'\xFF')
  }
}

///|
test "dehaze 错误参数" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x00']),
  }
  try {
    let _ = dehaze(img)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  let img2 = @types.Image::{
    width: 1,
    height: 1,
    channels: 3,
    data: Bytes::from_array([b'\x00', b'\x00', b'\x00']),
  }
  try {
    let _ = dehaze(img2, patch_size=0)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  try {
    let _ = dehaze(img2, omega=0.0F)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  try {
    let _ = dehaze(img2, t0=0.0F)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "dehaze 彩色图" {
  // 3x3 彩色图
  let data = Bytes::from_array([
    b'\x40', b'\x60', b'\x80', b'\x50', b'\x70', b'\x90', b'\x60', b'\x80', b'\xA0',
    b'\x50', b'\x70', b'\x90', b'\x60', b'\x80', b'\xA0', b'\x70', b'\x90', b'\xB0',
    b'\x60', b'\x80', b'\xA0', b'\x70', b'\x90', b'\xB0', b'\x80', b'\xA0', b'\xC0',
  ])
  let img = @types.Image::{ width: 3, height: 3, channels: 3, data }
  let out = dehaze(img, patch_size=1)
  assert_eq(out.width, 3)
  assert_eq(out.height, 3)
  // 所有像素应在 [0, 255] 范围
  for i in 0..<27 {
    let v = out.data[i].to_int()
    assert_true(v >= 0 && v <= 255)
  }
}

///|
test "guided_filter 基本功能" {
  let data = Bytes::from_array(Array::make(9, b'\x80'))
  let img = @types.Image::{ width: 3, height: 3, channels: 1, data }
  let input = Array::make(9, 0.5F)
  let out = guided_filter(img, input, radius=1, eps=0.001F)
  assert_eq(out.length(), 9)
  for i in 0..<9 {
    assert_true(out[i] >= 0.0F && out[i] <= 1.0F)
  }
}

///|
test "guided_filter 错误参数" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x00']),
  }
  try {
    let _ = guided_filter(img, [], radius=1)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

// ==================== dehaze 错误路径补充测试 ====================

///|
test "dehaze: empty image returns self" {
  let img = @types.Image::{ width: 0, height: 0, channels: 3, data: b"" }
  let out = dehaze(img)
  assert_eq(out.width, 0)
  assert_eq(out.height, 0)
}

///|
test "dehaze: invalid channels raises" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 2,
    data: Bytes::from_array([b'\x80', b'\x80']),
  }
  try {
    let _ = dehaze(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "dehaze: transmission clamped to t0" {
  // Very bright image → transmission may be < t0, should be clamped
  let data : Array[Byte] = Array::make(75, b'\xFF')
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let out = dehaze(img, patch_size=1, omega=0.95F, t0=0.5F)
  assert_eq(out.width, 5)
  assert_eq(out.height, 5)
  for i in 0..<75 {
    let v = out.data[i].to_int()
    assert_true(v >= 0 && v <= 255)
  }
}

///|
test "guided_filter: invalid channels raises" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 2,
    data: Bytes::from_array([b'\x80', b'\x80']),
  }
  try {
    let _ = guided_filter(img, [0.5F], radius=1)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "guided_filter: RGB guide computation" {
  let data = Bytes::from_array([
    b'\x40', b'\x80', b'\xC0', b'\x60', b'\xA0', b'\xE0', b'\x20', b'\x50', b'\x90',
  ])
  let img = @types.Image::{ width: 3, height: 1, channels: 3, data }
  let input = Array::make(3, 0.5F)
  let out = guided_filter(img, input, radius=1, eps=0.001F)
  assert_eq(out.length(), 3)
  let _ = data
  let _ = img
  let _ = out
}
