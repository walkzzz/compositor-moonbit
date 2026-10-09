// 连通域标记测试

///|
test "connected_components: 单个连通域" {
  let data = Bytes::from_array([
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\xFF', b'\xFF', b'\x00', b'\x00',
    b'\xFF', b'\xFF', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let (label_img, comps) = connected_components(img, 4)
  assert_eq(comps.length(), 1)
  assert_eq(comps[0].label, 1)
  assert_eq(comps[0].area, 4)
  assert_eq(comps[0].bbox_x, 1)
  assert_eq(comps[0].bbox_y, 1)
  assert_eq(comps[0].bbox_w, 2)
  assert_eq(comps[0].bbox_h, 2)
  assert_eq(label_img.width, 4)
  assert_eq(label_img.height, 4)
}

///|
test "connected_components: 两个独立连通域" {
  let data = Bytes::from_array([
    b'\xFF', b'\x00', b'\x00', b'\xFF', b'\xFF', b'\x00', b'\x00', b'\xFF', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let (_, comps) = connected_components(img, 4)
  assert_eq(comps.length(), 2)
  assert_eq(comps[0].area, 2)
  assert_eq(comps[1].area, 2)
}

///|
test "connected_components: 四连通 vs 八连通" {
  // 对角线连接的两个像素
  let data = Bytes::from_array([b'\xFF', b'\x00', b'\x00', b'\xFF'])
  let img = @types.Image::{ width: 2, height: 2, channels: 1, data }
  // 四连通：两个独立域
  let (_, comps4) = connected_components(img, 4)
  assert_eq(comps4.length(), 2)
  // 八连通：一个连通域
  let (_, comps8) = connected_components(img, 8)
  assert_eq(comps8.length(), 1)
  assert_eq(comps8[0].area, 2)
}

///|
test "connected_components: 全背景" {
  let data = Bytes::from_array(Array::make(16, b'\x00'))
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let (_, comps) = connected_components(img, 4)
  assert_eq(comps.length(), 0)
}

///|
test "connected_components: 全前景" {
  let data = Bytes::from_array(Array::make(16, b'\xFF'))
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let (_, comps) = connected_components(img, 4)
  assert_eq(comps.length(), 1)
  assert_eq(comps[0].area, 16)
}

///|
test "connected_components: 质心计算" {
  let data = Bytes::from_array([
    b'\x00', b'\x00', b'\x00', b'\xFF', b'\xFF', b'\xFF', b'\x00', b'\x00', b'\x00',
  ])
  let img = @types.Image::{ width: 3, height: 3, channels: 1, data }
  let (_, comps) = connected_components(img, 4)
  assert_eq(comps.length(), 1)
  // 质心 x = (0+1+2)/3 = 1.0
  assert_eq(comps[0].centroid_x, 1.0F)
  // 质心 y = (1+1+1)/3 = 1.0
  assert_eq(comps[0].centroid_y, 1.0F)
}

///|
test "connected_components: connectivity 验证" {
  let data = Bytes::from_array([b'\xFF'])
  let img = @types.Image::{ width: 1, height: 1, channels: 1, data }
  try {
    let _ = connected_components(img, 6)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "connected_components: 多个连通域" {
  // 4 个角各一个像素
  let data = Bytes::from_array([
    b'\xFF', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\xFF',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let (_, comps) = connected_components(img, 4)
  assert_eq(comps.length(), 4)
  for i in 0..<4 {
    assert_eq(comps[i].area, 1)
  }
}

///|
test "connected_components: RGB 图" {
  // 3x3 RGB，中心十字为前景
  let data : Array[Byte] = Array::make(27, b'\x00')
  // 中心列
  for y in 0..<3 {
    data[(y * 3 + 1) * 3] = b'\xFF'
  }
  // 中心行
  for x in 0..<3 {
    data[(1 * 3 + x) * 3] = b'\xFF'
  }
  let img = @types.Image::{
    width: 3,
    height: 3,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let (_, comps) = connected_components(img, 4)
  assert_eq(comps.length(), 1)
  assert_eq(comps[0].area, 5)
}

///|
test "connected_components: RGBA 图" {
  let data : Array[Byte] = Array::make(16, b'\x00')
  // 2x2 前景
  data[0] = b'\xFF'
  data[4] = b'\xFF'
  data[8] = b'\xFF'
  data[12] = b'\xFF'
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 4,
    data: Bytes::from_array(data),
  }
  let (_, comps) = connected_components(img, 4)
  assert_eq(comps.length(), 1)
  assert_eq(comps[0].area, 4)
}

///|
test "connected_components: 无效通道" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 2,
    data: Bytes::from_array(Array::make(8, b'\x00')),
  }
  try {
    let _ = connected_components(img, 4)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "connected_components: 八连通复杂场景" {
  // L 形 + 对角线，测试八连通合并
  let data = Bytes::from_array([
    b'\xFF', b'\xFF', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\x00', b'\xFF',
    b'\x00', b'\x00', b'\x00', b'\xFF', b'\xFF', b'\xFF', b'\xFF',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let (_, comps4) = connected_components(img, 4)
  let (_, comps8) = connected_components(img, 8)
  // 八连通应合并更多域
  assert_true(comps8.length() <= comps4.length())
}

///|
test "connected_components: 边界框验证" {
  // 5x5 图，前景在 (1,1) 到 (3,3)
  let data : Array[Byte] = Array::make(25, b'\x00')
  for y in 1..<4 {
    for x in 1..<4 {
      data[y * 5 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let (_, comps) = connected_components(img, 4)
  assert_eq(comps.length(), 1)
  assert_eq(comps[0].bbox_x, 1)
  assert_eq(comps[0].bbox_y, 1)
  assert_eq(comps[0].bbox_w, 3)
  assert_eq(comps[0].bbox_h, 3)
  assert_eq(comps[0].area, 9)
}
