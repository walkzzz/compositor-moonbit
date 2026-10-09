// 霍夫变换测试

///|
test "hough_lines: 检测水平直线" {
  // 4x8 图像，第 2 行为边缘
  let data : Array[Byte] = Array::make(4 * 8, b'\x00')
  for x in 0..<8 {
    data[2 * 8 + x] = b'\xFF'
  }
  let img = @types.Image::{
    width: 8,
    height: 4,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let lines = hough_lines(img, 4)
  assert_true(lines.length() > 0)
  // 票数最高的直线应有 8 票（8 个边缘点）
  assert_eq(lines[0].votes, 8)
}

///|
test "hough_lines: 检测垂直直线" {
  // 4x8 图像，第 3 列为边缘
  let data : Array[Byte] = Array::make(4 * 8, b'\x00')
  for y in 0..<4 {
    data[y * 8 + 3] = b'\xFF'
  }
  let img = @types.Image::{
    width: 8,
    height: 4,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let lines = hough_lines(img, 3)
  assert_true(lines.length() > 0)
  assert_eq(lines[0].votes, 4)
}

///|
test "hough_lines: 空图像无直线" {
  let data = Bytes::from_array(Array::make(16, b'\x00'))
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let lines = hough_lines(img, 1)
  assert_eq(lines.length(), 0)
}

///|
test "hough_lines: 阈值过滤" {
  // 两条直线：一条 8 像素，一条 2 像素
  let data : Array[Byte] = Array::make(8 * 8, b'\x00')
  for x in 0..<8 {
    data[0 * 8 + x] = b'\xFF' // 第 0 行
  }
  data[4 * 8 + 0] = b'\xFF'
  data[5 * 8 + 1] = b'\xFF'
  let img = @types.Image::{
    width: 8,
    height: 8,
    channels: 1,
    data: Bytes::from_array(data),
  }
  // 阈值 5：至少有 8 像素直线
  let lines = hough_lines(img, 5)
  assert_true(lines.length() > 0)
  assert_true(lines[0].votes >= 8)
}

///|
test "hough_lines: 按票数降序" {
  let data : Array[Byte] = Array::make(8 * 8, b'\x00')
  for x in 0..<8 {
    data[0 * 8 + x] = b'\xFF'
  }
  for y in 0..<4 {
    data[y * 8 + 0] = b'\xFF'
  }
  let img = @types.Image::{
    width: 8,
    height: 8,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let lines = hough_lines(img, 3)
  for i in 1..<lines.length() {
    assert_true(lines[i - 1].votes >= lines[i].votes)
  }
}

///|
test "hough_lines_nms: 去除重复直线" {
  let lines : Array[HoughLine] = [
    HoughLine::{ rho: 10.0F, theta: 0.5F, votes: 100 },
    HoughLine::{ rho: 10.1F, theta: 0.51F, votes: 90 },
    HoughLine::{ rho: 50.0F, theta: 1.0F, votes: 80 },
  ]
  let result = hough_lines_nms(lines)
  // 前两个相近，应被合并
  assert_eq(result.length(), 2)
  assert_eq(result[0].votes, 100)
  assert_eq(result[1].votes, 80)
}

///|
test "hough_lines: 通道验证" {
  let data = Bytes::from_array([b'\x00', b'\x00'])
  let img = @types.Image::{ width: 1, height: 1, channels: 2, data }
  try {
    let _ = hough_lines(img, 1)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "hough_lines 1x1 功能测试" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\xFF']),
  }
  let lines = hough_lines(img, 50)
  // 1x1 图像可能检测到 0 或 1 条线，关键是不崩溃
  assert_true(lines.length() >= 0)
}
