// 图像分割测试：kmeans_segment / region_growing_segment / flood_fill / segment_to_color

///|
test "kmeans_segment 基本功能" {
  // 2x2 图像：4 种不同颜色
  let data = Bytes::from_array([
    b'\xFF', b'\x00', b'\x00', // 红
     b'\x00', b'\xFF', b'\x00', // 绿
     b'\x00', b'\x00', b'\xFF', // 蓝
     b'\xFF', b'\xFF', b'\x00', // 黄
  ])
  let img = @types.Image::{ width: 2, height: 2, channels: 3, data }
  let (seg, regions) = kmeans_segment(img, 4, max_iters=10)
  assert_eq(seg.width, 2)
  assert_eq(seg.height, 2)
  assert_eq(seg.num_regions, 4)
  assert_eq(regions.length(), 4)
  // 每个区域面积应为 1
  for region in regions {
    assert_true(region.area >= 1)
  }
}

///|
test "kmeans_segment k=1" {
  let data = Bytes::from_array([
    b'\x80', b'\x80', b'\x80', b'\x80', b'\x80', b'\x80',
  ])
  let img = @types.Image::{ width: 2, height: 1, channels: 3, data }
  let (seg, regions) = kmeans_segment(img, 1)
  assert_eq(seg.num_regions, 1)
  assert_eq(regions.length(), 1)
  assert_eq(regions[0].area, 2)
}

///|
test "kmeans_segment 错误参数" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x00']),
  }
  try {
    let _ = kmeans_segment(img, 2)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "region_growing_segment 基本功能" {
  // 3x1 图像：左两个红色，右一个蓝色
  let data = Bytes::from_array([
    b'\xFF', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\x00', b'\x00', b'\xFF',
  ])
  let img = @types.Image::{ width: 3, height: 1, channels: 3, data }
  let (seg, regions) = region_growing_segment(
    img,
    [(0, 0), (2, 0)],
    threshold=10,
  )
  assert_eq(seg.num_regions, 2)
  assert_eq(regions.length(), 2)
  // 第一个区域应包含 2 个像素
  assert_true(regions[0].area >= 1)
}

///|
test "region_growing_segment 单种子" {
  // 2x2 纯色图
  let data = Bytes::from_array([
    b'\x40', b'\x40', b'\x40', b'\x40', b'\x40', b'\x40', b'\x40', b'\x40', b'\x40',
    b'\x40', b'\x40', b'\x40',
  ])
  let img = @types.Image::{ width: 2, height: 2, channels: 3, data }
  let (seg, regions) = region_growing_segment(img, [(0, 0)], threshold=0)
  assert_eq(seg.num_regions, 1)
  assert_eq(regions[0].area, 4)
}

///|
test "region_growing_segment 种子越界" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 3,
    data: Bytes::from_array(Array::make(12, b'\x00')),
  }
  let (seg, regions) = region_growing_segment(img, [(10, 10)], threshold=10)
  assert_eq(seg.num_regions, 0)
  assert_eq(regions.length(), 0)
}

///|
test "flood_fill 基本功能" {
  // 3x1 图像：红红蓝
  let data = Bytes::from_array([
    b'\xFF', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\x00', b'\x00', b'\xFF',
  ])
  let img = @types.Image::{ width: 3, height: 1, channels: 3, data }
  let filled = flood_fill(img, 0, 0, [b'\x00', b'\xFF', b'\x00'], threshold=0)
  // 像素 0 和 1 应被填充为绿色
  assert_eq(filled.data[0], b'\x00')
  assert_eq(filled.data[1], b'\xFF')
  assert_eq(filled.data[2], b'\x00')
  assert_eq(filled.data[3], b'\x00')
  assert_eq(filled.data[4], b'\xFF')
  assert_eq(filled.data[5], b'\x00')
  // 像素 2 应保持蓝色
  assert_eq(filled.data[6], b'\x00')
  assert_eq(filled.data[7], b'\x00')
  assert_eq(filled.data[8], b'\xFF')
}

///|
test "flood_fill 带阈值" {
  // 3x1 图像：颜色相近的三个像素
  let data = Bytes::from_array([
    b'\x80', b'\x80', b'\x80', b'\x82', b'\x82', b'\x82', b'\xFF', b'\xFF', b'\xFF',
  ])
  let img = @types.Image::{ width: 3, height: 1, channels: 3, data }
  let filled = flood_fill(img, 0, 0, [b'\x00', b'\x00', b'\x00'], threshold=5)
  // 像素 0 和 1 应被填充（差异 2 <= 5）
  assert_eq(filled.data[0], b'\x00')
  assert_eq(filled.data[3], b'\x00')
  // 像素 2 不应被填充
  assert_eq(filled.data[6], b'\xFF')
}

///|
test "flood_fill 种子越界" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 3,
    data: Bytes::from_array(Array::make(12, b'\x00')),
  }
  try {
    let _ = flood_fill(img, 10, 10, [b'\xFF', b'\x00', b'\x00'])
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "segment_to_color 基本功能" {
  let labels = [0, 1, 0, 1]
  let seg = SegmentLabelImage::{ width: 2, height: 2, labels, num_regions: 2 }
  let out = segment_to_color(seg)
  assert_eq(out.width, 2)
  assert_eq(out.height, 2)
  assert_eq(out.channels, 3)
  // 标签 0 和标签 1 应有不同颜色
  let r0 = out.data[0].to_int()
  let r1 = out.data[3].to_int()
  assert_true(
    r0 != r1 ||
    out.data[1].to_int() != out.data[4].to_int() ||
    out.data[2].to_int() != out.data[5].to_int(),
  )
}

///|
test "segment_to_color 空标签" {
  let seg = SegmentLabelImage::{
    width: 1,
    height: 1,
    labels: [0],
    num_regions: 0,
  }
  let out = segment_to_color(seg)
  // 标签 0 越界（num_regions=0），应保持黑色
  assert_eq(out.data[0], b'\x00')
}

///|
test "kmeans_segment k 超范围" {
  let img = @types.Image::{
    width: 2,
    height: 1,
    channels: 3,
    data: Bytes::from_array(Array::make(6, b'\x80')),
  }
  try {
    let _ = kmeans_segment(img, 0)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  try {
    let _ = kmeans_segment(img, 300)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "kmeans_segment 空图像" {
  let img = @types.Image::{ width: 0, height: 0, channels: 3, data: b"" }
  let (seg, regions) = kmeans_segment(img, 2)
  assert_eq(seg.width, 0)
  assert_eq(regions.length(), 0)
}
