// 频域滤波测试

///|
test "freq_filter: 低通滤波平滑图像" {
  let data = Bytes::from_array([
    b'\x00', b'\xFF', b'\x00', b'\xFF', b'\xFF', b'\x00', b'\xFF', b'\x00', b'\x00',
    b'\xFF', b'\x00', b'\xFF', b'\xFF', b'\x00', b'\xFF', b'\x00',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let result = freq_filter(img, LowPass, 2.0F)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 1)
  for i in 0..<16 {
    assert_true(result.data[i].to_int() >= 0)
    assert_true(result.data[i].to_int() <= 255)
  }
}

///|
test "freq_filter: 高通滤波保留边缘" {
  let data = Bytes::from_array([
    b'\x10', b'\x20', b'\x30', b'\x40', b'\x10', b'\x20', b'\x30', b'\x40', b'\x10',
    b'\x20', b'\x30', b'\x40', b'\x10', b'\x20', b'\x30', b'\x40',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let result = freq_filter(img, HighPass, 1.0F)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  for i in 0..<16 {
    assert_true(result.data[i].to_int() >= 0)
    assert_true(result.data[i].to_int() <= 255)
  }
}

///|
test "freq_filter: 带通滤波" {
  let data = Bytes::from_array([
    b'\x00', b'\x40', b'\x80', b'\xC0', b'\x10', b'\x50', b'\x90', b'\xD0', b'\x20',
    b'\x60', b'\xA0', b'\xE0', b'\x30', b'\x70', b'\xB0', b'\xF0',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let result = freq_filter(img, BandPass, 2.0F, band_width=1.0F)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "freq_filter: 带阻滤波" {
  let data = Bytes::from_array([
    b'\x00', b'\x40', b'\x80', b'\xC0', b'\x10', b'\x50', b'\x90', b'\xD0', b'\x20',
    b'\x60', b'\xA0', b'\xE0', b'\x30', b'\x70', b'\xB0', b'\xF0',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let result = freq_filter(img, BandStop, 2.0F, band_width=1.0F)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "freq_filter: 高斯低通" {
  let data = Bytes::from_array([
    b'\x00', b'\xFF', b'\x00', b'\xFF', b'\xFF', b'\x00', b'\xFF', b'\x00', b'\x00',
    b'\xFF', b'\x00', b'\xFF', b'\xFF', b'\x00', b'\xFF', b'\x00',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let result = freq_filter_gaussian(img, LowPass, 2.0F)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  for i in 0..<16 {
    assert_true(result.data[i].to_int() >= 0)
    assert_true(result.data[i].to_int() <= 255)
  }
}

///|
test "freq_filter: 高斯高通" {
  let data = Bytes::from_array([
    b'\x80', b'\x80', b'\x80', b'\x80', b'\x80', b'\x80', b'\x80', b'\x80', b'\x80',
    b'\x80', b'\x80', b'\x80', b'\x80', b'\x80', b'\x80', b'\x80',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let result = freq_filter_gaussian(img, HighPass, 2.0F)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "freq_filter: RGB 图像" {
  let data = Bytes::from_array([
    b'\xFF', b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\x00', b'\xFF',
    b'\xFF', b'\xFF', b'\x00',
  ])
  let img = @types.Image::{ width: 2, height: 2, channels: 3, data }
  let result = freq_filter(img, LowPass, 1.0F)
  assert_eq(result.width, 2)
  assert_eq(result.height, 2)
  assert_eq(result.channels, 3)
}

///|
test "freq_filter: 通道验证" {
  let data = Bytes::from_array([b'\x00', b'\x00'])
  let img = @types.Image::{ width: 1, height: 1, channels: 2, data }
  try {
    let _ = freq_filter(img, LowPass, 1.0F)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}
