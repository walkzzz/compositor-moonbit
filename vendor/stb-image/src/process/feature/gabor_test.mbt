// Gabor 滤波测试

///|
test "gabor_filter 基本功能" {
  // 5x5 灰度图
  let data = Bytes::from_array([
    b'\x40', b'\x50', b'\x60', b'\x50', b'\x40', b'\x50', b'\x60', b'\x70', b'\x60',
    b'\x50', b'\x60', b'\x70', b'\x80', b'\x70', b'\x60', b'\x50', b'\x60', b'\x70',
    b'\x60', b'\x50', b'\x40', b'\x50', b'\x60', b'\x50', b'\x40',
  ])
  let img = @types.Image::{ width: 5, height: 5, channels: 1, data }
  let out = gabor_filter(img, 3, 2.0F, 0.0F, lambda=5.0F)
  assert_eq(out.width, 5)
  assert_eq(out.height, 5)
  assert_eq(out.channels, 1)
  // 所有像素应在 [0, 255]
  for i in 0..<25 {
    let v = out.data[i].to_int()
    assert_true(v >= 0 && v <= 255)
  }
}

///|
test "gabor_filter RGB 图" {
  let data = Bytes::from_array(Array::make(75, b'\x80'))
  let img = @types.Image::{ width: 5, height: 5, channels: 3, data }
  let out = gabor_filter(img, 3, 2.0F, 0.0F, lambda=5.0F)
  assert_eq(out.width, 5)
  assert_eq(out.height, 5)
  assert_eq(out.channels, 3)
}

///|
test "gabor_filter RGBA alpha 不变" {
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
  let out = gabor_filter(img, 3, 2.0F, 0.0F, lambda=5.0F)
  for i in 0..<25 {
    assert_eq(out.data[i * 4 + 3], b'\xFF')
  }
}

///|
test "gabor_filter 不同方向" {
  let data = Bytes::from_array([
    b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\x00', b'\x00', b'\xFF',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00',
  ])
  let img = @types.Image::{ width: 5, height: 5, channels: 1, data }
  // 0° 方向
  let out0 = gabor_filter(img, 3, 2.0F, 0.0F, lambda=5.0F)
  // 90° 方向
  let out90 = gabor_filter(img, 3, 2.0F, 1.5708F, lambda=5.0F)
  assert_eq(out0.width, 5)
  assert_eq(out90.width, 5)
}

///|
test "gabor_filter 错误参数" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x00']),
  }
  try {
    let _ = gabor_filter(img, 2, 1.0F, 0.0F)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  try {
    let _ = gabor_filter(img, 3, 0.0F, 0.0F)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  try {
    let _ = gabor_filter(img, 3, 1.0F, 0.0F, lambda=0.0F)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "gabor_filter_bank 基本功能" {
  let data = Bytes::from_array(Array::make(25, b'\x80'))
  let img = @types.Image::{ width: 5, height: 5, channels: 1, data }
  let out = gabor_filter_bank(img, 3, 2.0F, num_orientations=4, lambda=5.0F)
  assert_eq(out.width, 5)
  assert_eq(out.height, 5)
  assert_eq(out.channels, 1)
}

///|
test "gabor_filter_bank 错误参数" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x00']),
  }
  try {
    let _ = gabor_filter_bank(img, 3, 1.0F, num_orientations=0)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "gabor_kernel 基本功能" {
  let kernel = gabor_kernel(3, 2.0F, 0.0F, lambda=5.0F)
  assert_eq(kernel.length(), 3)
  assert_eq(kernel[0].length(), 3)
  // 核值应为有限数
  for y in 0..<3 {
    for x in 0..<3 {
      assert_true(kernel[y][x] > -100.0F && kernel[y][x] < 100.0F)
    }
  }
}

///|
test "gabor_kernel 错误参数" {
  try {
    let _ = gabor_kernel(2, 1.0F, 0.0F)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  try {
    let _ = gabor_kernel(3, 0.0F, 0.0F)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "gabor_filter 1x1 功能测试" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x80']),
  }
  let out = gabor_filter(img, 3, 2.0F, 0.0F)
  assert_eq(out.width, 1)
  assert_eq(out.height, 1)
  assert_eq(out.channels, 1)
}
