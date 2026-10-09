// 距离变换测试

///|
test "distance_transform 基本功能" {
  // 5x1 图像，中间为前景
  let data = Bytes::from_array([b'\x00', b'\xFF', b'\xFF', b'\xFF', b'\x00'])
  let img = @types.Image::{ width: 5, height: 1, channels: 1, data }
  let dist = distance_transform(img, distance_type=1)
  assert_eq(dist.length(), 5)
  // 背景像素距离为 0
  assert_eq(dist[0], 0.0F)
  assert_eq(dist[4], 0.0F)
  // 前景像素距离 > 0
  assert_true(dist[1] > 0.0F)
  assert_true(dist[2] > 0.0F)
  assert_true(dist[3] > 0.0F)
  // 中心像素距离最大
  assert_true(dist[2] >= dist[1])
  assert_true(dist[2] >= dist[3])
}

///|
test "distance_transform L1 距离" {
  let data = Bytes::from_array([b'\x00', b'\xFF', b'\xFF', b'\xFF', b'\x00'])
  let img = @types.Image::{ width: 5, height: 1, channels: 1, data }
  let dist = distance_transform(img, distance_type=1)
  // L1 距离：[0, 1, 2, 1, 0]
  assert_eq(dist[0], 0.0F)
  assert_eq(dist[1], 1.0F)
  assert_eq(dist[2], 2.0F)
  assert_eq(dist[3], 1.0F)
  assert_eq(dist[4], 0.0F)
}

///|
test "distance_transform 棋盘距离" {
  let data = Bytes::from_array([b'\x00', b'\xFF', b'\xFF', b'\xFF', b'\x00'])
  let img = @types.Image::{ width: 5, height: 1, channels: 1, data }
  let dist = distance_transform(img, distance_type=3)
  // 一维情况下棋盘距离与 L1 相同
  assert_eq(dist[0], 0.0F)
  assert_eq(dist[1], 1.0F)
  assert_eq(dist[2], 2.0F)
  assert_eq(dist[3], 1.0F)
  assert_eq(dist[4], 0.0F)
}

///|
test "distance_transform 全前景" {
  let data = Bytes::from_array(Array::make(5, b'\xFF'))
  let img = @types.Image::{ width: 5, height: 1, channels: 1, data }
  let dist = distance_transform(img, distance_type=1)
  // 全前景，没有背景，距离应保持很大
  for i in 0..<5 {
    assert_true(dist[i] > 100.0F)
  }
}

///|
test "distance_transform 全背景" {
  let data = Bytes::from_array(Array::make(5, b'\x00'))
  let img = @types.Image::{ width: 5, height: 1, channels: 1, data }
  let dist = distance_transform(img, distance_type=1)
  // 全背景，距离全为 0
  for i in 0..<5 {
    assert_eq(dist[i], 0.0F)
  }
}

///|
test "distance_transform 2D 图" {
  // 3x3 图像，中心为前景
  let data = Bytes::from_array([
    b'\x00', b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\x00', b'\x00',
  ])
  let img = @types.Image::{ width: 3, height: 3, channels: 1, data }
  let dist = distance_transform(img, distance_type=1)
  // 中心距离为 1
  assert_eq(dist[4], 1.0F)
}

///|
test "distance_transform 错误参数" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x00']),
  }
  try {
    let _ = distance_transform(img, distance_type=0)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  try {
    let _ = distance_transform(img, distance_type=4)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "visualize_distance_transform 基本功能" {
  let dist = [0.0F, 1.0F, 2.0F, 1.0F, 0.0F]
  let img = visualize_distance_transform(dist, 5, 1)
  assert_eq(img.width, 5)
  assert_eq(img.height, 1)
  assert_eq(img.channels, 1)
  // 最大距离 2.0 对应 255
  assert_eq(img.data[2], b'\xFF')
  // 距离 0 对应 0
  assert_eq(img.data[0], b'\x00')
}

///|
test "skeletonize 基本功能" {
  // 5x1 图像，中间为前景
  let data = Bytes::from_array([b'\x00', b'\xFF', b'\xFF', b'\xFF', b'\x00'])
  let img = @types.Image::{ width: 5, height: 1, channels: 1, data }
  let out = skeletonize(img)
  assert_eq(out.width, 5)
  assert_eq(out.height, 1)
  assert_eq(out.channels, 1)
}

///|
test "skeletonize 2D 图" {
  // 5x5 矩形
  let data : Array[Byte] = Array::make(25, b'\x00')
  for y in 1..<(5 - 1) {
    for x in 1..<(5 - 1) {
      data[y * 5 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let out = skeletonize(img)
  assert_eq(out.width, 5)
  assert_eq(out.height, 5)
}
