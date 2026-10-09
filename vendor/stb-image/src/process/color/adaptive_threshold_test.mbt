// 自适应阈值测试

///|
test "adaptive_threshold_mean: 基本二值化" {
  let data = Bytes::from_array([
    b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\xFF', b'\xFF', b'\x00',
    b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let result = adaptive_threshold_mean(img, 3, 5)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 1)
  for i in 0..<16 {
    assert_true(result.data[i] == b'\x00' || result.data[i] == b'\xFF')
  }
}

///|
test "adaptive_threshold_mean: 均匀图像" {
  let data = Bytes::from_array(Array::make(16, b'\x80'))
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let result = adaptive_threshold_mean(img, 3, 5)
  // 均匀图像均值=128，阈值=123，128>123 → 全白
  for i in 0..<16 {
    assert_eq(result.data[i], b'\xFF')
  }
}

///|
test "adaptive_threshold_mean: block_size 验证" {
  let data = Bytes::from_array(Array::make(16, b'\x80'))
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  // 偶数 block_size 应报错
  try {
    let _ = adaptive_threshold_mean(img, 4, 5)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  // 太小 block_size 应报错
  try {
    let _ = adaptive_threshold_mean(img, 1, 5)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "adaptive_threshold_gaussian: 基本二值化" {
  let data = Bytes::from_array([
    b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\xFF', b'\xFF', b'\x00',
    b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\xFF',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let result = adaptive_threshold_gaussian(img, 3, 5)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  for i in 0..<16 {
    assert_true(result.data[i] == b'\x00' || result.data[i] == b'\xFF')
  }
}

///|
test "adaptive_threshold_gaussian: 均匀图像" {
  let data = Bytes::from_array(Array::make(16, b'\x80'))
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let result = adaptive_threshold_gaussian(img, 3, 5)
  for i in 0..<16 {
    assert_eq(result.data[i], b'\xFF')
  }
}

///|
test "threshold_otsu: 双峰直方图" {
  // 左半黑右半白
  let data : Array[Byte] = Array::make(8 * 4, b'\x00')
  for y in 0..<4 {
    for x in 4..<8 {
      data[y * 8 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 8,
    height: 4,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = threshold_otsu(img)
  assert_eq(result.width, 8)
  assert_eq(result.height, 4)
  // 左半应为黑
  for y in 0..<4 {
    for x in 0..<4 {
      assert_eq(result.data[y * 8 + x], b'\x00')
    }
  }
  // 右半应为白
  for y in 0..<4 {
    for x in 4..<8 {
      assert_eq(result.data[y * 8 + x], b'\xFF')
    }
  }
}

///|
test "threshold_otsu: 均匀图像" {
  let data = Bytes::from_array(Array::make(16, b'\x80'))
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let result = threshold_otsu(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  for i in 0..<16 {
    assert_true(result.data[i] == b'\x00' || result.data[i] == b'\xFF')
  }
}

///|
test "threshold_otsu: RGB 图像" {
  let data = Bytes::from_array([
    b'\x00', b'\xFF', b'\x00', b'\xFF', b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00',
    b'\xFF', b'\x00', b'\x00',
  ])
  let img = @types.Image::{ width: 2, height: 2, channels: 3, data }
  let result = threshold_otsu(img)
  assert_eq(result.width, 2)
  assert_eq(result.height, 2)
  assert_eq(result.channels, 3)
}

///|
test "adaptive_threshold_mean: RGB 图像" {
  let data = Bytes::from_array([
    b'\x00', b'\xFF', b'\x00', b'\xFF', b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00',
    b'\xFF', b'\x00', b'\x00',
  ])
  let img = @types.Image::{ width: 2, height: 2, channels: 3, data }
  let result = adaptive_threshold_mean(img, 3, 5)
  assert_eq(result.width, 2)
  assert_eq(result.height, 2)
  assert_eq(result.channels, 3)
}

// ==================== channels=4 (RGBA) 测试 ====================

///|
test "adaptive_threshold_mean: RGBA 图像保留 alpha" {
  let data = Bytes::from_array([
    b'\x00', b'\xFF', b'\x00', b'\x80', b'\xFF', b'\x00', b'\x00', b'\xC0', b'\x00',
    b'\xFF', b'\x00', b'\x40', b'\xFF', b'\x00', b'\x00', b'\xFF',
  ])
  let img = @types.Image::{ width: 2, height: 2, channels: 4, data }
  let result = adaptive_threshold_mean(img, 3, 5)
  assert_eq(result.width, 2)
  assert_eq(result.height, 2)
  assert_eq(result.channels, 4)
  // alpha 通道应原样保留
  assert_eq(result.data[3], b'\x80')
  assert_eq(result.data[7], b'\xC0')
  assert_eq(result.data[11], b'\x40')
  assert_eq(result.data[15], b'\xFF')
}

///|
test "adaptive_threshold_gaussian: RGBA 图像保留 alpha" {
  let data = Bytes::from_array([
    b'\x00', b'\xFF', b'\x00', b'\x80', b'\xFF', b'\x00', b'\x00', b'\xC0', b'\x00',
    b'\xFF', b'\x00', b'\x40', b'\xFF', b'\x00', b'\x00', b'\xFF',
  ])
  let img = @types.Image::{ width: 2, height: 2, channels: 4, data }
  let result = adaptive_threshold_gaussian(img, 3, 5)
  assert_eq(result.width, 2)
  assert_eq(result.height, 2)
  assert_eq(result.channels, 4)
  // alpha 通道应原样保留
  assert_eq(result.data[3], b'\x80')
  assert_eq(result.data[7], b'\xC0')
  assert_eq(result.data[11], b'\x40')
  assert_eq(result.data[15], b'\xFF')
}

///|
test "threshold_otsu: RGBA 图像保留 alpha" {
  let data = Bytes::from_array([
    b'\x00', b'\xFF', b'\x00', b'\x80', b'\xFF', b'\x00', b'\x00', b'\xC0', b'\x00',
    b'\xFF', b'\x00', b'\x40', b'\xFF', b'\x00', b'\x00', b'\xFF',
  ])
  let img = @types.Image::{ width: 2, height: 2, channels: 4, data }
  let result = threshold_otsu(img)
  assert_eq(result.width, 2)
  assert_eq(result.height, 2)
  assert_eq(result.channels, 4)
  // alpha 通道应原样保留
  assert_eq(result.data[3], b'\x80')
  assert_eq(result.data[7], b'\xC0')
  assert_eq(result.data[11], b'\x40')
  assert_eq(result.data[15], b'\xFF')
}

// ==================== 错误路径测试 ====================

///|
test "adaptive_threshold_mean: 无效 channels 报错" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 2,
    data: Bytes::from_array([b'\x00', b'\x00']),
  }
  try {
    let _ = adaptive_threshold_mean(img, 3, 5)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "adaptive_threshold_gaussian: block_size 验证" {
  let data = Bytes::from_array(Array::make(16, b'\x80'))
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  try {
    let _ = adaptive_threshold_gaussian(img, 4, 5)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  try {
    let _ = adaptive_threshold_gaussian(img, 1, 5)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "adaptive_threshold_gaussian: 无效 channels 报错" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 2,
    data: Bytes::from_array([b'\x00', b'\x00']),
  }
  try {
    let _ = adaptive_threshold_gaussian(img, 3, 5)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "threshold_otsu: 无效 channels 报错" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 2,
    data: Bytes::from_array([b'\x00', b'\x00']),
  }
  try {
    let _ = threshold_otsu(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}
