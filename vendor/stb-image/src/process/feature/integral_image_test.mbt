// 积分图像测试

///|
test "integral_image: 基本积分" {
  let data = Bytes::from_array([b'\x01', b'\x02', b'\x03', b'\x04'])
  let img = @types.Image::{ width: 2, height: 2, channels: 1, data }
  let integral = integral_image(img)
  assert_eq(integral.width, 2)
  assert_eq(integral.height, 2)
  // 全图和 = 1+2+3+4 = 10
  assert_eq(integral_sum(integral, 0, 0, 2, 2), 10L)
  // 左上 1x1 = 1
  assert_eq(integral_sum(integral, 0, 0, 1, 1), 1L)
  // 第一行 = 1+2 = 3
  assert_eq(integral_sum(integral, 0, 0, 2, 1), 3L)
  // 第一列 = 1+3 = 4
  assert_eq(integral_sum(integral, 0, 0, 1, 2), 4L)
  // 右下 1x1 = 4
  assert_eq(integral_sum(integral, 1, 1, 1, 1), 4L)
}

///|
test "integral_image: 均匀图像" {
  let data = Bytes::from_array(Array::make(16, b'\x10'))
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let integral = integral_image(img)
  // 全图和 = 16 * 16 = 256
  assert_eq(integral_sum(integral, 0, 0, 4, 4), 256L)
  // 2x2 区域 = 4 * 16 = 64
  assert_eq(integral_sum(integral, 1, 1, 2, 2), 64L)
}

///|
test "integral_image: 均值计算" {
  // 使用十进制值: 10,20,...,90 的十六进制为 0A,14,1E,28,32,3C,46,50,5A
  let data = Bytes::from_array([
    b'\x0A', b'\x14', b'\x1E', b'\x28', b'\x32', b'\x3C', b'\x46', b'\x50', b'\x5A',
  ])
  let img = @types.Image::{ width: 3, height: 3, channels: 1, data }
  let integral = integral_image(img)
  // 全图均值 = (10+20+...+90)/9 = 450/9 = 50
  let mean = integral_mean(integral, 0, 0, 3, 3)
  assert_eq(mean, 50.0F)
}

///|
test "integral_image: 通道验证" {
  let data = Bytes::from_array([b'\x00', b'\x00'])
  let img = @types.Image::{ width: 1, height: 1, channels: 2, data }
  try {
    let _ = integral_image(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "integral_image_sq: 基本平方积分" {
  let data = Bytes::from_array([b'\x01', b'\x02', b'\x03', b'\x04'])
  let img = @types.Image::{ width: 2, height: 2, channels: 1, data }
  let integral_sq = integral_image_sq(img)
  // 全图平方和 = 1+4+9+16 = 30
  assert_eq(integral_sum_sq(integral_sq, 0, 0, 2, 2), 30L)
}

///|
test "integral_variance: 方差计算" {
  let data = Bytes::from_array([
    b'\x00', b'\x00', b'\x00', b'\x00', b'\xFF', b'\xFF', b'\xFF', b'\xFF', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\xFF', b'\xFF', b'\xFF', b'\xFF',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let integral = integral_image(img)
  let integral_sq = integral_image_sq(img)
  let variance = integral_variance(integral, integral_sq, 0, 0, 4, 4)
  // 均值 = 127.5，方差 = (8*127.5^2 + 8*127.5^2)/16 - 127.5^2 = 127.5^2 ≈ 16256.25
  assert_true(variance > 16000.0F && variance < 16500.0F)
}

///|
test "integral_image: RGB 图像取首通道" {
  let data = Bytes::from_array([
    b'\x0A', b'\xFF', b'\xFF', b'\x0B', b'\xFF', b'\xFF', b'\x0C', b'\xFF', b'\xFF',
    b'\x0D', b'\xFF', b'\xFF',
  ])
  let img = @types.Image::{ width: 2, height: 2, channels: 3, data }
  let integral = integral_image(img)
  // 首通道和 = 10+11+12+13 = 46
  assert_eq(integral_sum(integral, 0, 0, 2, 2), 46L)
}

///|
test "integral_image: 空区域" {
  let data = Bytes::from_array([b'\x10', b'\x20', b'\x30', b'\x40'])
  let img = @types.Image::{ width: 2, height: 2, channels: 1, data }
  let integral = integral_image(img)
  assert_eq(integral_mean(integral, 0, 0, 0, 0), 0.0F)
  assert_eq(integral_mean(integral, 0, 0, 1, 0), 0.0F)
}

///|
test "integral_image 1x1 功能测试" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x40']),
  }
  let integral = integral_image(img)
  assert_eq(integral.width, 1)
  assert_eq(integral.height, 1)
  // 1x1 积分图值 = 像素值
  assert_eq(integral_sum(integral, 0, 0, 1, 1), 64L)
  assert_eq(integral_mean(integral, 0, 0, 1, 1), 64.0F)
}
