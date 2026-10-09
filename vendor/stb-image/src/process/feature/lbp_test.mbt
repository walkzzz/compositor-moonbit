// LBP 测试

///|
test "lbp: 均匀图像" {
  let data = Bytes::from_array(Array::make(16, b'\x80'))
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let result = lbp(img)
  // 内部像素（非边界）：所有邻居 >= 中心，LBP = 0xFF
  for y in 1..<3 {
    for x in 1..<3 {
      assert_eq(result.data[y * 4 + x], b'\xFF')
    }
  }
}

///|
test "lbp: 中心最亮" {
  let data : Array[Byte] = Array::make(9, b'\x00')
  data[4] = b'\xFF' // 中心最亮
  let img = @types.Image::{
    width: 3,
    height: 3,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = lbp(img)
  // 中心：所有邻居 < 中心，LBP = 0
  assert_eq(result.data[4], b'\x00')
}

///|
test "lbp: 中心最暗" {
  let data : Array[Byte] = Array::make(9, b'\xFF')
  data[4] = b'\x00' // 中心最暗
  let img = @types.Image::{
    width: 3,
    height: 3,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = lbp(img)
  // 中心：所有邻居 >= 中心，LBP = 0xFF
  assert_eq(result.data[4], b'\xFF')
}

///|
test "lbp: 输出范围 0-255" {
  let data = Bytes::from_array([
    b'\x10', b'\x20', b'\x30', b'\x40', b'\x50', b'\x60', b'\x70', b'\x80', b'\x90',
    b'\xA0', b'\xB0', b'\xC0', b'\xD0', b'\xE0', b'\xF0', b'\x00',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let result = lbp(img)
  for i in 0..<16 {
    assert_true(result.data[i].to_int() >= 0)
    assert_true(result.data[i].to_int() <= 255)
  }
}

///|
test "lbp_uniform: 输出范围 0-59" {
  let data = Bytes::from_array([
    b'\x10', b'\x20', b'\x30', b'\x40', b'\x50', b'\x60', b'\x70', b'\x80', b'\x90',
    b'\xA0', b'\xB0', b'\xC0', b'\xD0', b'\xE0', b'\xF0', b'\x00',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let result = lbp_uniform(img)
  for i in 0..<16 {
    assert_true(result.data[i].to_int() >= 0)
    assert_true(result.data[i].to_int() <= 59)
  }
}

///|
test "lbp_uniform: 均匀图像" {
  let data = Bytes::from_array(Array::make(16, b'\x80'))
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let result = lbp_uniform(img)
  // 均匀图像：LBP=0xFF=255，跳变次数=0（全1），均匀模式
  // 0xFF 应映射为某个 0~58 的值
  assert_true(result.data[0].to_int() <= 58)
}

///|
test "lbp: RGB 图像" {
  let data = Bytes::from_array([
    b'\x00', b'\xFF', b'\x00', b'\xFF', b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00',
    b'\xFF', b'\x00', b'\x00',
  ])
  let img = @types.Image::{ width: 2, height: 2, channels: 3, data }
  let result = lbp(img)
  assert_eq(result.width, 2)
  assert_eq(result.height, 2)
  assert_eq(result.channels, 3)
}

///|
test "lbp: 通道验证" {
  let data = Bytes::from_array([b'\x00', b'\x00'])
  let img = @types.Image::{ width: 1, height: 1, channels: 2, data }
  try {
    let _ = lbp(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "lbp 1x1 功能测试" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x80']),
  }
  let result = lbp(img)
  assert_eq(result.width, 1)
  assert_eq(result.height, 1)
  // 1x1 图像无邻居，LBP 应为 0
  assert_eq(result.data[0], b'\x00')
}
