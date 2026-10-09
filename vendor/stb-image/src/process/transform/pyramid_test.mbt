// 图像金字塔测试

///|
test "pyr_down: 尺寸减半" {
  let data = Bytes::from_array(Array::make(8 * 8, b'\x80'))
  let img = @types.Image::{ width: 8, height: 8, channels: 1, data }
  let result = pyr_down(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "pyr_down: 均值采样" {
  let data = Bytes::from_array([
    b'\x00', b'\x10', b'\x20', b'\x30', b'\x40', b'\x50', b'\x60', b'\x70', b'\x80',
    b'\x90', b'\xA0', b'\xB0', b'\xC0', b'\xD0', b'\xE0', b'\xF0',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let result = pyr_down(img)
  assert_eq(result.width, 2)
  assert_eq(result.height, 2)
  // 左上 2x2 均值 = (0+16+64+80)/4 = 40 = 0x28
  assert_eq(result.data[0], b'\x28')
}

///|
test "pyr_up: 尺寸加倍" {
  let data = Bytes::from_array(Array::make(4 * 4, b'\x80'))
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let result = pyr_up(img)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "pyr_up: 均匀图像保持不变" {
  let data = Bytes::from_array(Array::make(2 * 2, b'\x80'))
  let img = @types.Image::{ width: 2, height: 2, channels: 1, data }
  let result = pyr_up(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  for i in 0..<16 {
    assert_eq(result.data[i], b'\x80')
  }
}

///|
test "build_gaussian_pyramid: 自动层数" {
  let data = Bytes::from_array(Array::make(16 * 16, b'\x80'))
  let img = @types.Image::{ width: 16, height: 16, channels: 1, data }
  let pyramid = build_gaussian_pyramid(img, 0)
  // 16→8→4→2→1，共 5 层
  assert_eq(pyramid.length(), 5)
  assert_eq(pyramid[0].width, 16)
  assert_eq(pyramid[1].width, 8)
  assert_eq(pyramid[2].width, 4)
  assert_eq(pyramid[3].width, 2)
  assert_eq(pyramid[4].width, 1)
}

///|
test "build_gaussian_pyramid: 指定层数" {
  let data = Bytes::from_array(Array::make(16 * 16, b'\x80'))
  let img = @types.Image::{ width: 16, height: 16, channels: 1, data }
  let pyramid = build_gaussian_pyramid(img, 3)
  assert_eq(pyramid.length(), 3)
}

///|
test "build_laplacian_pyramid: 层数正确" {
  let data = Bytes::from_array(Array::make(8 * 8, b'\x80'))
  let img = @types.Image::{ width: 8, height: 8, channels: 1, data }
  let pyramid = build_laplacian_pyramid(img, 0)
  // 8→4→2→1，高斯 4 层，拉普拉斯 4 层
  assert_eq(pyramid.length(), 4)
}

///|
test "pyr_down: 通道验证" {
  let data = Bytes::from_array([b'\x00', b'\x00'])
  let img = @types.Image::{ width: 1, height: 1, channels: 2, data }
  try {
    let _ = pyr_down(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "pyr_down: 太小图像报错" {
  let data = Bytes::from_array([b'\x80'])
  let img = @types.Image::{ width: 1, height: 1, channels: 1, data }
  try {
    let _ = pyr_down(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}
