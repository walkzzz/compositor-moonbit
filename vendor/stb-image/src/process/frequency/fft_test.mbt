// FFT 频域变换测试

///|
test "fft: 常数图像的 DC 分量" {
  // 4x4 常数图像，值为 100
  let data = Bytes::from_array([
    b'\x64', b'\x64', b'\x64', b'\x64', b'\x64', b'\x64', b'\x64', b'\x64', b'\x64',
    b'\x64', b'\x64', b'\x64', b'\x64', b'\x64', b'\x64', b'\x64',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let ffts = fft_2d(img)
  let fft = ffts[0]
  // DC 分量（左上角）= 100 * 16 = 1600
  inspect(fft.data[0].re, content="1600")
  // 其他分量应接近 0
  for i in 1..<(4 * 4) {
    assert_true(fft.data[i].re < 1.0F && fft.data[i].re > -1.0F)
    assert_true(fft.data[i].im < 1.0F && fft.data[i].im > -1.0F)
  }
}

///|
test "fft: FFT->IFFT 往返恢复原图" {
  // 4x4 灰度图
  let data = Bytes::from_array([
    b'\x00', b'\x20', b'\x40', b'\x60', b'\x80', b'\xA0', b'\xC0', b'\xE0', b'\xFF',
    b'\x10', b'\x30', b'\x50', b'\x70', b'\x90', b'\xB0', b'\xD0',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let ffts = fft_2d(img)
  let restored = ifft_2d(ffts[0])
  // 检查尺寸
  assert_eq(restored.width, 4)
  assert_eq(restored.height, 4)
  // 检查每个像素恢复（允许舍入误差 ±1）
  for i in 0..<16 {
    let orig = data[i].to_int()
    let rest = restored.data[i].to_int()
    assert_true((rest - orig).abs() <= 1)
  }
}

///|
test "fft: 幅度谱非负且尺寸正确" {
  let data = Bytes::from_array([
    b'\x00', b'\xFF', b'\x00', b'\xFF', b'\xFF', b'\x00', b'\xFF', b'\x00', b'\x00',
    b'\xFF', b'\x00', b'\xFF', b'\xFF', b'\x00', b'\xFF', b'\x00',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let ffts = fft_2d(img)
  let mag = fft_magnitude(ffts[0], false)
  assert_eq(mag.width, 4)
  assert_eq(mag.height, 4)
  assert_eq(mag.channels, 1)
  for i in 0..<16 {
    assert_true(mag.data[i].to_int() >= 0)
    assert_true(mag.data[i].to_int() <= 255)
  }
}

///|
test "fft: 对数幅度谱" {
  let data = Bytes::from_array([
    b'\x10', b'\x20', b'\x30', b'\x40', b'\x50', b'\x60', b'\x70', b'\x80', b'\x90',
    b'\xA0', b'\xB0', b'\xC0', b'\xD0', b'\xE0', b'\xF0', b'\x00',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let ffts = fft_2d(img)
  let mag = fft_magnitude(ffts[0], true)
  assert_eq(mag.width, 4)
  assert_eq(mag.height, 4)
  for i in 0..<16 {
    assert_true(mag.data[i].to_int() >= 0)
    assert_true(mag.data[i].to_int() <= 255)
  }
}

///|
test "fft: fft_shift 移分不变" {
  let data = Bytes::from_array([
    b'\x00', b'\x10', b'\x20', b'\x30', b'\x40', b'\x50', b'\x60', b'\x70', b'\x80',
    b'\x90', b'\xA0', b'\xB0', b'\xC0', b'\xD0', b'\xE0', b'\xF0',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let ffts = fft_2d(img)
  let shifted = fft_shift(ffts[0])
  assert_eq(shifted.width, 4)
  assert_eq(shifted.height, 4)
  // shift 前后所有复数的总和应不变
  let mut sum_before_re = 0.0F
  let mut sum_before_im = 0.0F
  let mut sum_after_re = 0.0F
  let mut sum_after_im = 0.0F
  for i in 0..<16 {
    sum_before_re += ffts[0].data[i].re
    sum_before_im += ffts[0].data[i].im
    sum_after_re += shifted.data[i].re
    sum_after_im += shifted.data[i].im
  }
  assert_true((sum_before_re - sum_after_re).abs() < 1.0F)
  assert_true((sum_before_im - sum_after_im).abs() < 1.0F)
}

///|
test "fft: RGB 图像每通道独立变换" {
  // 2x2 RGB 图像
  let data = Bytes::from_array([
    b'\xFF', b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\x00', b'\xFF',
    b'\xFF', b'\xFF', b'\x00',
  ])
  let img = @types.Image::{ width: 2, height: 2, channels: 3, data }
  let ffts = fft_2d(img)
  assert_eq(ffts.length(), 3)
  for c in 0..<3 {
    assert_eq(ffts[c].width, 2)
    assert_eq(ffts[c].height, 2)
  }
}

///|
test "fft: 非2幂尺寸自动补零" {
  // 3x3 图像，应补零到 4x4
  let data = Bytes::from_array([
    b'\x10', b'\x20', b'\x30', b'\x40', b'\x50', b'\x60', b'\x70', b'\x80', b'\x90',
  ])
  let img = @types.Image::{ width: 3, height: 3, channels: 1, data }
  let ffts = fft_2d(img)
  let fft = ffts[0]
  // 补零到 4x4
  assert_eq(fft.width, 4)
  assert_eq(fft.height, 4)
  assert_eq(fft.data.length(), 16)
}

///|
test "fft: 1x1 图像" {
  let data = Bytes::from_array([b'\x42'])
  let img = @types.Image::{ width: 1, height: 1, channels: 1, data }
  let ffts = fft_2d(img)
  let fft = ffts[0]
  assert_eq(fft.width, 1)
  assert_eq(fft.height, 1)
  // 1x1 FFT 就是原值
  assert_eq(fft.data[0].re, 66.0F)
  assert_eq(fft.data[0].im, 0.0F)
}

///|
test "fft: 通道验证" {
  // channels=2 不支持
  let data = Bytes::from_array([b'\x00', b'\x00'])
  let img = @types.Image::{ width: 1, height: 1, channels: 2, data }
  try {
    let _ = fft_2d(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}
