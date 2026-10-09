// 轮廓提取测试

///|
test "find_contours: 单个矩形" {
  let data : Array[Byte] = Array::make(6 * 6, b'\x00')
  for y in 1..<5 {
    for x in 1..<5 {
      data[y * 6 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 6,
    height: 6,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let contours = find_contours(img)
  assert_true(contours.length() >= 1)
  assert_true(contours[0].points.length() > 0)
}

///|
test "find_contours: 两个独立区域" {
  let data : Array[Byte] = Array::make(8 * 4, b'\x00')
  // 左方块
  data[1 * 8 + 1] = b'\xFF'
  data[1 * 8 + 2] = b'\xFF'
  data[2 * 8 + 1] = b'\xFF'
  data[2 * 8 + 2] = b'\xFF'
  // 右方块
  data[1 * 8 + 5] = b'\xFF'
  data[1 * 8 + 6] = b'\xFF'
  data[2 * 8 + 5] = b'\xFF'
  data[2 * 8 + 6] = b'\xFF'
  let img = @types.Image::{
    width: 8,
    height: 4,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let contours = find_contours(img)
  assert_true(contours.length() >= 2)
}

///|
test "find_contours: 空图像" {
  let data = Bytes::from_array(Array::make(16, b'\x00'))
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let contours = find_contours(img)
  assert_eq(contours.length(), 0)
}

///|
test "find_contours: 全前景" {
  let data = Bytes::from_array(Array::make(16, b'\xFF'))
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let contours = find_contours(img)
  assert_true(contours.length() >= 1)
}

///|
test "draw_contours: 绘制到图像" {
  let data : Array[Byte] = Array::make(6 * 6, b'\x00')
  for y in 1..<5 {
    for x in 1..<5 {
      data[y * 6 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 6,
    height: 6,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let contours = find_contours(img)
  let result = draw_contours(img, contours, [b'\x80'])
  assert_eq(result.width, 6)
  assert_eq(result.height, 6)
}

///|
test "contour_perimeter: 正方形周长" {
  let contour = Contour::{
    points: [
      ContourPoint::{ x: 0, y: 0 },
      ContourPoint::{ x: 3, y: 0 },
      ContourPoint::{ x: 3, y: 3 },
      ContourPoint::{ x: 0, y: 3 },
    ],
    is_outer: true,
  }
  let p = contour_perimeter(contour)
  assert_eq(p, 12.0F)
}

///|
test "contour_area: 正方形面积" {
  let contour = Contour::{
    points: [
      ContourPoint::{ x: 0, y: 0 },
      ContourPoint::{ x: 4, y: 0 },
      ContourPoint::{ x: 4, y: 4 },
      ContourPoint::{ x: 0, y: 4 },
    ],
    is_outer: true,
  }
  let a = contour_area(contour)
  assert_eq(a, 16.0F)
}

///|
test "contour_area: 三角形面积" {
  let contour = Contour::{
    points: [
      ContourPoint::{ x: 0, y: 0 },
      ContourPoint::{ x: 6, y: 0 },
      ContourPoint::{ x: 0, y: 6 },
    ],
    is_outer: true,
  }
  let a = contour_area(contour)
  assert_eq(a, 18.0F)
}

///|
test "find_contours: 通道验证" {
  let data = Bytes::from_array([b'\x00', b'\x00'])
  let img = @types.Image::{ width: 1, height: 1, channels: 2, data }
  try {
    let _ = find_contours(img)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "find_contours: 孤立点" {
  // 1x3 图像，只有中间像素为前景
  let data = Bytes::from_array([b'\x00', b'\xFF', b'\x00'])
  let img = @types.Image::{ width: 3, height: 1, channels: 1, data }
  let contours = find_contours(img)
  // 孤立点应该产生至少一个轮廓
  assert_true(contours.length() >= 1)
}
