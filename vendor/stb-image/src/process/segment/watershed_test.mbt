// 分水岭分割测试

///|
test "watershed 基本功能" {
  // 5x1 灰度图：两个区域
  let data = Bytes::from_array([b'\x10', b'\x10', b'\x80', b'\x80', b'\x80'])
  let img = @types.Image::{ width: 5, height: 1, channels: 1, data }
  let markers = [1, 1, 0, 2, 2]
  let labels = watershed(img, markers)
  assert_eq(labels.length(), 5)
  // 左侧应属于标签 1
  assert_eq(labels[0], 1)
  assert_eq(labels[1], 1)
  // 右侧应属于标签 2
  assert_eq(labels[3], 2)
  assert_eq(labels[4], 2)
}

///|
test "watershed 常量图" {
  let data = Bytes::from_array(Array::make(5, b'\x40'))
  let img = @types.Image::{ width: 5, height: 1, channels: 1, data }
  let markers = [1, 0, 0, 0, 2]
  let labels = watershed(img, markers)
  assert_eq(labels[0], 1)
  assert_eq(labels[4], 2)
}

///|
test "watershed 错误参数" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: Bytes::from_array(Array::make(4, b'\x00')),
  }
  try {
    let _ = watershed(img, [1, 0]) // 长度不匹配
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "watershed_auto 基本功能" {
  // 5x1 灰度图：两个谷
  let data = Bytes::from_array([b'\x10', b'\x80', b'\x10', b'\x80', b'\x10'])
  let img = @types.Image::{ width: 5, height: 1, channels: 1, data }
  let (labels, num) = watershed_auto(img)
  assert_eq(labels.length(), 5)
  assert_true(num >= 1)
}

///|
test "watershed_auto 常量图" {
  let data = Bytes::from_array(Array::make(9, b'\x40'))
  let img = @types.Image::{ width: 3, height: 3, channels: 1, data }
  let (labels, num) = watershed_auto(img)
  assert_eq(labels.length(), 9)
  // 常量图应只有 1 个区域
  assert_eq(num, 1)
}

///|
test "watershed 2D 图" {
  // 3x3 图像：左上角和右下角不同
  let data = Bytes::from_array([
    b'\x10', b'\x40', b'\x40', b'\x40', b'\x40', b'\x40', b'\x40', b'\x40', b'\x10',
  ])
  let img = @types.Image::{ width: 3, height: 3, channels: 1, data }
  let markers = [1, 0, 0, 0, 0, 0, 0, 0, 2]
  let labels = watershed(img, markers)
  assert_eq(labels[0], 1)
  assert_eq(labels[8], 2)
}

///|
test "watershed 1x1 输入" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x80']),
  }
  let labels = watershed(img, [1])
  assert_eq(labels.length(), 1)
  assert_eq(labels[0], 1)
}

///|
test "watershed 不支持通道数" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 2,
    data: Bytes::from_array(Array::make(8, b'\x00')),
  }
  try {
    let _ = watershed(img, [1, 0, 0, 0])
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}
