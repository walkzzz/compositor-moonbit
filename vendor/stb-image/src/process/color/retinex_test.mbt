// 多尺度 Retinex 测试

///|
test "ssr 灰度图基本功能" {
  let data = Bytes::from_array([
    b'\x40', b'\x80', b'\xC0', b'\x60', b'\xA0', b'\xE0', b'\x20', b'\x50', b'\x90',
  ])
  let img = @types.Image::{ width: 3, height: 3, channels: 1, data }
  let out = ssr(img, sigma=2.0F, gain=1.0F, offset=0.0F)
  assert_eq(out.width, 3)
  assert_eq(out.height, 3)
  assert_eq(out.channels, 1)
  // 所有像素应在 [0, 255] 范围
  for i in 0..<9 {
    let v = out.data[i].to_int()
    assert_true(v >= 0 && v <= 255)
  }
}

///|
test "ssr 常量图" {
  let data = Bytes::from_array(Array::make(9, b'\x80'))
  let img = @types.Image::{ width: 3, height: 3, channels: 1, data }
  let out = ssr(img, sigma=2.0F)
  // 常量图 SSR 结果应接近中心值
  for i in 0..<9 {
    let v = out.data[i].to_int()
    assert_true(v >= 100 && v <= 160)
  }
}

///|
test "ssr RGB 图" {
  let data = Bytes::from_array([
    b'\x40', b'\x80', b'\xC0', b'\x60', b'\xA0', b'\xE0', b'\x20', b'\x50', b'\x90',
    b'\x40', b'\x80', b'\xC0', b'\x60', b'\xA0', b'\xE0', b'\x20', b'\x50', b'\x90',
    b'\x40', b'\x80', b'\xC0', b'\x60', b'\xA0', b'\xE0', b'\x20', b'\x50', b'\x90',
  ])
  let img = @types.Image::{ width: 3, height: 3, channels: 3, data }
  let out = ssr(img, sigma=2.0F)
  assert_eq(out.width, 3)
  assert_eq(out.height, 3)
  assert_eq(out.channels, 3)
  for i in 0..<27 {
    let v = out.data[i].to_int()
    assert_true(v >= 0 && v <= 255)
  }
}

///|
test "ssr RGBA alpha 不变" {
  let data = Bytes::from_array([
    b'\x40', b'\x80', b'\xC0', b'\xFF', b'\x60', b'\xA0', b'\xE0', b'\x80', b'\x20',
    b'\x50', b'\x90', b'\xFF', b'\x40', b'\x80', b'\xC0', b'\xC0',
  ])
  let img = @types.Image::{ width: 2, height: 2, channels: 4, data }
  let out = ssr(img, sigma=2.0F)
  assert_eq(out.data[3], b'\xFF')
  assert_eq(out.data[7], b'\x80')
  assert_eq(out.data[11], b'\xFF')
  assert_eq(out.data[15], b'\xC0')
}

///|
test "ssr 错误参数" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x80']),
  }
  try {
    let _ = ssr(img, sigma=0.0F)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  try {
    let _ = ssr(img, sigma=-1.0F)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "msr 灰度图基本功能" {
  let data = Bytes::from_array([
    b'\x40', b'\x80', b'\xC0', b'\x60', b'\xA0', b'\xE0', b'\x20', b'\x50', b'\x90',
  ])
  let img = @types.Image::{ width: 3, height: 3, channels: 1, data }
  let out = msr(img, sigmas=[2.0F, 5.0F, 10.0F])
  assert_eq(out.width, 3)
  assert_eq(out.height, 3)
  assert_eq(out.channels, 1)
  for i in 0..<9 {
    let v = out.data[i].to_int()
    assert_true(v >= 0 && v <= 255)
  }
}

///|
test "msr 单尺度" {
  let data = Bytes::from_array(Array::make(9, b'\x80'))
  let img = @types.Image::{ width: 3, height: 3, channels: 1, data }
  let out = msr(img, sigmas=[5.0F])
  assert_eq(out.width, 3)
  assert_eq(out.height, 3)
  for i in 0..<9 {
    let v = out.data[i].to_int()
    assert_true(v >= 0 && v <= 255)
  }
}

///|
test "msr 错误参数" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x80']),
  }
  try {
    let _ = msr(img, sigmas=[])
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  try {
    let _ = msr(img, sigmas=[0.0F])
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "msrcr RGB 图基本功能" {
  let data = Bytes::from_array([
    b'\x40', b'\x80', b'\xC0', b'\x60', b'\xA0', b'\xE0', b'\x20', b'\x50', b'\x90',
    b'\x40', b'\x80', b'\xC0', b'\x60', b'\xA0', b'\xE0', b'\x20', b'\x50', b'\x90',
    b'\x40', b'\x80', b'\xC0', b'\x60', b'\xA0', b'\xE0', b'\x20', b'\x50', b'\x90',
  ])
  let img = @types.Image::{ width: 3, height: 3, channels: 3, data }
  let out = msrcr(img, sigmas=[2.0F, 5.0F, 10.0F])
  assert_eq(out.width, 3)
  assert_eq(out.height, 3)
  assert_eq(out.channels, 3)
  for i in 0..<27 {
    let v = out.data[i].to_int()
    assert_true(v >= 0 && v <= 255)
  }
}

///|
test "msrcr RGBA alpha 不变" {
  let data = Bytes::from_array([
    b'\x40', b'\x80', b'\xC0', b'\xFF', b'\x60', b'\xA0', b'\xE0', b'\x80', b'\x20',
    b'\x50', b'\x90', b'\xFF', b'\x40', b'\x80', b'\xC0', b'\xC0',
  ])
  let img = @types.Image::{ width: 2, height: 2, channels: 4, data }
  let out = msrcr(img, sigmas=[2.0F, 5.0F])
  assert_eq(out.data[3], b'\xFF')
  assert_eq(out.data[7], b'\x80')
  assert_eq(out.data[11], b'\xFF')
  assert_eq(out.data[15], b'\xC0')
}

///|
test "msrcr 错误参数" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x80']),
  }
  try {
    let _ = msrcr(img)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  let img2 = @types.Image::{
    width: 1,
    height: 1,
    channels: 3,
    data: Bytes::from_array([b'\x80', b'\x80', b'\x80']),
  }
  try {
    let _ = msrcr(img2, sigmas=[])
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

// ==================== 错误路径补充测试 ====================

///|
test "ssr: invalid channels raises" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 2,
    data: Bytes::from_array([b'\x80', b'\x80']),
  }
  try {
    let _ = ssr(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "ssr: empty image returns self" {
  let img = @types.Image::{ width: 0, height: 0, channels: 1, data: b"" }
  let out = ssr(img, sigma=2.0F)
  assert_eq(out.width, 0)
  assert_eq(out.height, 0)
}

///|
test "msr: invalid channels raises" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 2,
    data: Bytes::from_array([b'\x80', b'\x80']),
  }
  try {
    let _ = msr(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "msr: empty image returns self" {
  let img = @types.Image::{ width: 0, height: 0, channels: 3, data: b"" }
  let out = msr(img)
  assert_eq(out.width, 0)
  assert_eq(out.height, 0)
}

///|
test "msr: RGBA alpha preserved" {
  let data = Bytes::from_array([
    b'\x40', b'\x80', b'\xC0', b'\xAA', b'\x60', b'\xA0', b'\xE0', b'\xBB', b'\x20',
    b'\x50', b'\x90', b'\xCC', b'\x10', b'\x20', b'\x30', b'\xDD',
  ])
  let img = @types.Image::{ width: 2, height: 2, channels: 4, data }
  let out = msr(img, sigmas=[10.0F])
  assert_eq(out.data[3], b'\xAA')
  assert_eq(out.data[7], b'\xBB')
  assert_eq(out.data[11], b'\xCC')
  assert_eq(out.data[15], b'\xDD')
}

///|
test "msrcr: empty image returns self" {
  let img = @types.Image::{ width: 0, height: 0, channels: 3, data: b"" }
  let out = msrcr(img)
  assert_eq(out.width, 0)
  assert_eq(out.height, 0)
}
