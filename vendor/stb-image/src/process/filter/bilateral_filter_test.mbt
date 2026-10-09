// 双边滤波测试

///|
test "bilateral_filter: 均匀图像不变" {
  let data = Bytes::from_array(Array::make(8 * 8, b'\x80'))
  let img = @types.Image::{ width: 8, height: 8, channels: 1, data }
  let result = bilateral_filter(img, 2, 2.0F, 30.0F)
  for i in 0..<64 {
    assert_eq(result.data[i], b'\x80')
  }
}

///|
test "bilateral_filter: 保边去噪" {
  // 左半黑右半白，边界应被保留
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
  let result = bilateral_filter(img, 2, 2.0F, 30.0F)
  assert_eq(result.width, 8)
  assert_eq(result.height, 4)
  // 远离边界的区域应接近原值
  assert_eq(result.data[0], b'\x00')
  assert_true(result.data[31].to_int() >= 250)
}

///|
test "bilateral_filter: 输出范围 0-255" {
  let data = Bytes::from_array([
    b'\x00', b'\xFF', b'\x00', b'\xFF', b'\x00', b'\xFF', b'\x00', b'\xFF', b'\xFF',
    b'\x00', b'\xFF', b'\x00', b'\xFF', b'\x00', b'\xFF', b'\x00', b'\x00', b'\xFF',
    b'\x00', b'\xFF', b'\x00', b'\xFF', b'\x00', b'\xFF', b'\xFF', b'\x00', b'\xFF',
    b'\x00', b'\xFF', b'\x00', b'\xFF', b'\x00',
  ])
  let img = @types.Image::{ width: 8, height: 4, channels: 1, data }
  let result = bilateral_filter(img, 2, 2.0F, 30.0F)
  for i in 0..<32 {
    assert_true(result.data[i].to_int() >= 0)
    assert_true(result.data[i].to_int() <= 255)
  }
}

///|
test "bilateral_filter: RGB 图像" {
  let data = Bytes::from_array([
    b'\xFF', b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\x00', b'\xFF',
    b'\xFF', b'\xFF', b'\x00',
  ])
  let img = @types.Image::{ width: 2, height: 2, channels: 3, data }
  let result = bilateral_filter(img, 1, 1.0F, 30.0F)
  assert_eq(result.width, 2)
  assert_eq(result.height, 2)
  assert_eq(result.channels, 3)
}

///|
test "bilateral_filter: radius 验证" {
  let data = Bytes::from_array([b'\x80', b'\x80'])
  let img = @types.Image::{ width: 1, height: 2, channels: 1, data }
  try {
    let _ = bilateral_filter(img, 0, 1.0F, 30.0F)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "bilateral_filter: 通道验证" {
  let data = Bytes::from_array([b'\x00', b'\x00'])
  let img = @types.Image::{ width: 1, height: 1, channels: 2, data }
  try {
    let _ = bilateral_filter(img, 1, 1.0F, 30.0F)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "bilateral_filter_fast: downsample=1 等价于普通双边滤波" {
  let data = Bytes::from_array(Array::make(8 * 8, b'\x80'))
  let img = @types.Image::{ width: 8, height: 8, channels: 1, data }
  let result = bilateral_filter_fast(img, 2, 2.0F, 30.0F, 1)
  for i in 0..<64 {
    assert_eq(result.data[i], b'\x80')
  }
}

///|
test "bilateral_filter 1x1 功能测试" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x80']),
  }
  let result = bilateral_filter(img, 2, 3.0F, 30.0F)
  assert_eq(result.width, 1)
  assert_eq(result.height, 1)
  assert_eq(result.data[0], b'\x80')
}

///|
test "bilateral_filter: RGBA alpha 不变" {
  // 8x8 RGBA 常量图
  let n = 8 * 8
  let data : Array[Byte] = Array::make(n * 4, b'\x80')
  // 设置不同的 alpha 值
  for i in 0..<n {
    data[i * 4 + 3] = (i % 256).to_byte()
  }
  let img = @types.Image::{
    width: 8,
    height: 8,
    channels: 4,
    data: Bytes::from_array(data),
  }
  let result = bilateral_filter(img, 2, 2.0F, 30.0F)
  // alpha 通道应保持不变
  for i in 0..<n {
    assert_eq(result.data[i * 4 + 3], (i % 256).to_byte())
  }
}

///|
test "bilateral_filter: RGB 内部区域" {
  // 10x10 RGB 图，radius=2 -> 内部区域 6x6
  let n = 10 * 10
  let data = Bytes::from_array(Array::make(n * 3, b'\x80'))
  let img = @types.Image::{ width: 10, height: 10, channels: 3, data }
  let result = bilateral_filter(img, 2, 2.0F, 30.0F)
  // 常量图应保持不变
  for i in 0..<(n * 3) {
    assert_eq(result.data[i], b'\x80')
  }
}

///|
test "bilateral_filter_fast: downsample=2 降采样" {
  // 16x16 灰度图，downsample=2
  let n = 16 * 16
  let data = Bytes::from_array(Array::make(n, b'\x80'))
  let img = @types.Image::{ width: 16, height: 16, channels: 1, data }
  let result = bilateral_filter_fast(img, 2, 2.0F, 30.0F, 2)
  assert_eq(result.width, 16)
  assert_eq(result.height, 16)
  assert_eq(result.channels, 1)
}

///|
test "bilateral_filter_fast: downsample=3 降采样" {
  // 32x32 灰度图，downsample=3
  let n = 32 * 32
  let data = Bytes::from_array(Array::make(n, b'\x40'))
  let img = @types.Image::{ width: 32, height: 32, channels: 1, data }
  let result = bilateral_filter_fast(img, 3, 2.0F, 30.0F, 3)
  assert_eq(result.width, 32)
  assert_eq(result.height, 32)
}

///|
test "bilateral_filter: 灰度内部区域" {
  // 10x10 灰度图，radius=2 -> 内部区域 6x6
  let n = 10 * 10
  let data = Bytes::from_array(Array::make(n, b'\x80'))
  let img = @types.Image::{ width: 10, height: 10, channels: 1, data }
  let result = bilateral_filter(img, 2, 2.0F, 30.0F)
  for i in 0..<n {
    assert_eq(result.data[i], b'\x80')
  }
}
