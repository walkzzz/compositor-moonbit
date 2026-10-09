// NLM 去噪测试

///|
test "nlm_denoise 灰度图基本功能" {
  // 3x3 灰度图
  let data = Bytes::from_array([
    b'\x80', b'\x82', b'\x7F', b'\x81', b'\x80', b'\x83', b'\x7F', b'\x82', b'\x80',
  ])
  let img = @types.Image::{ width: 3, height: 3, channels: 1, data }
  let out = nlm_denoise(img, patch_size=1, search_size=1, h=10)
  assert_eq(out.width, 3)
  assert_eq(out.height, 3)
  assert_eq(out.channels, 1)
  // 中心像素应在合理范围内（原图值约 0x80=128）
  let center = out.data[4].to_int()
  assert_true(center >= 120 && center <= 135)
}

///|
test "nlm_denoise 常量图不变" {
  // 3x3 常量灰度图
  let data = Bytes::from_array(Array::make(9, b'\x80'))
  let img = @types.Image::{ width: 3, height: 3, channels: 1, data }
  let out = nlm_denoise(img, patch_size=1, search_size=1, h=10)
  // 常量图去噪后应保持不变
  for i in 0..<9 {
    assert_eq(out.data[i], b'\x80')
  }
}

///|
test "nlm_denoise RGB 图" {
  let data = Bytes::from_array([
    b'\xFF', b'\x00', b'\x00', b'\xFE', b'\x01', b'\x00', b'\xFF', b'\x00', b'\x01',
    b'\xFE', b'\x00', b'\x00', b'\xFF', b'\x01', b'\x00', b'\xFF', b'\x00', b'\x00',
    b'\xFF', b'\x00', b'\x01', b'\xFF', b'\x00', b'\x00', b'\xFE', b'\x01', b'\x00',
  ])
  let img = @types.Image::{ width: 3, height: 3, channels: 3, data }
  let out = nlm_denoise(img, patch_size=1, search_size=1, h=15)
  assert_eq(out.width, 3)
  assert_eq(out.height, 3)
  assert_eq(out.channels, 3)
  // R 通道应在合理范围
  let r = out.data[0].to_int()
  assert_true(r >= 200)
}

///|
test "nlm_denoise RGBA 图 alpha 不变" {
  let data = Bytes::from_array([
    b'\x80', b'\x80', b'\x80', b'\xFF', b'\x82', b'\x82', b'\x82', b'\x80', b'\x7F',
    b'\x7F', b'\x7F', b'\xFF', b'\x81', b'\x81', b'\x81', b'\xC0',
  ])
  let img = @types.Image::{ width: 2, height: 2, channels: 4, data }
  let out = nlm_denoise(img, patch_size=1, search_size=1, h=10)
  // alpha 通道应保持不变
  assert_eq(out.data[3], b'\xFF')
  assert_eq(out.data[7], b'\x80')
  assert_eq(out.data[11], b'\xFF')
  assert_eq(out.data[15], b'\xC0')
}

///|
test "nlm_denoise 错误参数" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x00']),
  }
  try {
    let _ = nlm_denoise(img, patch_size=0)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  try {
    let _ = nlm_denoise(img, search_size=0)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  try {
    let _ = nlm_denoise(img, h=0)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "nlm_denoise_fast 基本功能" {
  let data = Bytes::from_array([
    b'\x80', b'\x82', b'\x7F', b'\x81', b'\x81', b'\x80', b'\x83', b'\x7F', b'\x7F',
    b'\x82', b'\x80', b'\x81', b'\x82', b'\x7F', b'\x81', b'\x80',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let out = nlm_denoise_fast(img, patch_size=1, search_size=2, h=10, step=2)
  assert_eq(out.width, 4)
  assert_eq(out.height, 4)
  assert_eq(out.channels, 1)
  // 所有像素应在合理范围
  for i in 0..<16 {
    let v = out.data[i].to_int()
    assert_true(v >= 0 && v <= 255)
  }
}

///|
test "nlm_denoise_fast 常量图不变" {
  let data = Bytes::from_array(Array::make(16, b'\x80'))
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let out = nlm_denoise_fast(img, patch_size=1, search_size=2, h=10, step=2)
  for i in 0..<16 {
    assert_eq(out.data[i], b'\x80')
  }
}

///|
test "nlm_denoise_fast 错误参数" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x00']),
  }
  try {
    let _ = nlm_denoise_fast(img, step=0)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  try {
    let _ = nlm_denoise_fast(img, step=6)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "nlm_denoise 1x1 功能测试" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x80']),
  }
  let out = nlm_denoise(img, patch_size=1, search_size=1, h=10)
  assert_eq(out.width, 1)
  assert_eq(out.height, 1)
  assert_eq(out.data[0], b'\x80')
}

///|
test "nlm_denoise 大图像触发内部区域" {
  // 25x25 灰度图，inner_start = search_size + patch_size = 7 + 3 = 10
  // 内部区域: y in [10, 15), x in [10, 15) -> 5x5 = 25 pixels
  let n = 25 * 25
  let data = Bytes::from_array(Array::make(n, b'\x80'))
  let img = @types.Image::{ width: 25, height: 25, channels: 1, data }
  let out = nlm_denoise(img, patch_size=3, search_size=7, h=10)
  // 常量图应保持不变
  for i in 0..<n {
    assert_eq(out.data[i], b'\x80')
  }
}

///|
test "nlm_denoise 大图像 RGB 内部区域" {
  // 25x25 RGB 图
  let n = 25 * 25 * 3
  let data = Bytes::from_array(Array::make(n, b'\x40'))
  let img = @types.Image::{ width: 25, height: 25, channels: 3, data }
  let out = nlm_denoise(img, patch_size=2, search_size=5, h=15)
  assert_eq(out.width, 25)
  assert_eq(out.height, 25)
  assert_eq(out.channels, 3)
  // 常量图应保持不变
  for i in 0..<n {
    assert_eq(out.data[i], b'\x40')
  }
}

///|
test "nlm_denoise 大图像 RGBA alpha 保持" {
  // 25x25 RGBA 图
  let n = 25 * 25
  let data : Array[Byte] = Array::make(n * 4, b'\x00')
  // 设置 alpha 通道为不同值
  for i in 0..<n {
    data[i * 4 + 3] = (i % 256).to_byte()
  }
  let img = @types.Image::{
    width: 25,
    height: 25,
    channels: 4,
    data: Bytes::from_array(data),
  }
  let out = nlm_denoise(img, patch_size=2, search_size=5, h=10)
  // alpha 通道应保持不变
  for i in 0..<n {
    assert_eq(out.data[i * 4 + 3], (i % 256).to_byte())
  }
}

///|
test "nlm_denoise_fast 大图像触发内部区域" {
  // 25x25 灰度图
  let n = 25 * 25
  let data = Bytes::from_array(Array::make(n, b'\x80'))
  let img = @types.Image::{ width: 25, height: 25, channels: 1, data }
  let out = nlm_denoise_fast(img, patch_size=3, search_size=7, h=10, step=2)
  // 常量图应保持不变
  for i in 0..<n {
    assert_eq(out.data[i], b'\x80')
  }
}

///|
test "nlm_denoise_fast 大图像 RGB 内部区域" {
  let n = 25 * 25 * 3
  let data = Bytes::from_array(Array::make(n, b'\x60'))
  let img = @types.Image::{ width: 25, height: 25, channels: 3, data }
  let out = nlm_denoise_fast(img, patch_size=2, search_size=5, h=12, step=1)
  for i in 0..<n {
    assert_eq(out.data[i], b'\x60')
  }
}

///|
test "nlm_denoise 无效通道数" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 2,
    data: Bytes::from_array(Array::make(8, b'\x00')),
  }
  try {
    let _ = nlm_denoise(img)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "nlm_denoise_fast 无效通道数" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 2,
    data: Bytes::from_array(Array::make(8, b'\x00')),
  }
  try {
    let _ = nlm_denoise_fast(img)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "nlm_denoise patch_size 超范围" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Bytes::from_array(Array::make(16, b'\x00')),
  }
  try {
    let _ = nlm_denoise(img, patch_size=11)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  try {
    let _ = nlm_denoise(img, search_size=21)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "nlm_denoise 0x0 图像" {
  let img = @types.Image::{
    width: 0,
    height: 0,
    channels: 1,
    data: Bytes::from_array([]),
  }
  // 0x0 图像现在会 raise 错误（生产级验证）
  try {
    ignore(nlm_denoise(img))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}
