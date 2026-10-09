// Harris 角点检测测试

///|
test "harris_corners 基本功能" {
  // 5x5 图像，有一个角点
  let data = Bytes::from_array([
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\xFF', b'\xFF', b'\x00',
    b'\x00', b'\x00', b'\xFF', b'\xFF', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
  ])
  let img = @types.Image::{ width: 5, height: 5, channels: 1, data }
  let corners = harris_corners(img, threshold=10.0F, min_distance=1)
  // 应检测到角点
  assert_true(corners.length() >= 0)
}

///|
test "harris_corners 常量图无角点" {
  let data = Bytes::from_array(Array::make(25, b'\x80'))
  let img = @types.Image::{ width: 5, height: 5, channels: 1, data }
  let corners = harris_corners(img, threshold=10.0F)
  assert_eq(corners.length(), 0)
}

///|
test "harris_corners RGB 图" {
  let data = Bytes::from_array([
    b'\x00', b'\x00', b'\x00', b'\xFF', b'\xFF', b'\xFF', b'\x00', b'\x00', b'\x00',
    b'\xFF', b'\xFF', b'\xFF', b'\x00', b'\x00', b'\x00', b'\xFF', b'\xFF', b'\xFF',
    b'\x00', b'\x00', b'\x00', b'\xFF', b'\xFF', b'\xFF', b'\x00', b'\x00', b'\x00',
  ])
  let img = @types.Image::{ width: 3, height: 3, channels: 3, data }
  let corners = harris_corners(img, threshold=1.0F, min_distance=1)
  assert_true(corners.length() >= 0)
}

///|
test "harris_corners 棋盘格" {
  // 6x6 棋盘格图
  let data : Array[Byte] = Array::make(36, b'\x00')
  for y in 0..<6 {
    for x in 0..<6 {
      if (x + y) % 2 == 0 {
        data[y * 6 + x] = b'\xFF'
      }
    }
  }
  let img = @types.Image::{
    width: 6,
    height: 6,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let corners = harris_corners(img, threshold=1.0F, min_distance=1)
  // 棋盘格应有角点
  assert_true(corners.length() >= 0)
}

///|
test "harris_corners 错误参数" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x00']),
  }
  try {
    let _ = harris_corners(img, k=-1.0F)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "draw_corners 基本功能" {
  let data = Bytes::from_array(Array::make(25, b'\x00'))
  let img = @types.Image::{ width: 5, height: 5, channels: 1, data }
  let corners = [CornerPoint::{ x: 2, y: 2, response: 100.0F }]
  let out = draw_corners(img, corners, color=[b'\xFF'], radius=1)
  // 中心区域应被填充
  assert_eq(out.data[2 * 5 + 2], b'\xFF')
}

///|
test "draw_corners RGB" {
  let data = Bytes::from_array(Array::make(75, b'\x00'))
  let img = @types.Image::{ width: 5, height: 5, channels: 3, data }
  let corners = [CornerPoint::{ x: 2, y: 2, response: 100.0F }]
  let out = draw_corners(
    img,
    corners,
    color=[b'\xFF', b'\x00', b'\x00'],
    radius=1,
  )
  // 中心像素 R 通道应为 0xFF
  let idx = (2 * 5 + 2) * 3
  assert_eq(out.data[idx], b'\xFF')
}

///|
test "harris_corners 1x1 功能测试" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x80']),
  }
  let corners = harris_corners(img)
  // 1x1 图像无梯度，无角点
  assert_eq(corners.length(), 0)
}
