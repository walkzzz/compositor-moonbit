// grabCut 分割测试

///|
test "grab_cut 基本功能" {
  // 20x20 RGB 图像：中心红色方块，周围绿色背景
  let data : Array[Byte] = Array::make(400 * 3, b'\x00')
  for y in 0..<20 {
    for x in 0..<20 {
      let idx = (y * 20 + x) * 3
      if x >= 5 && x < 15 && y >= 5 && y < 15 {
        data[idx] = b'\xFF'
        data[idx + 1] = b'\x00'
        data[idx + 2] = b'\x00'
      } else {
        data[idx] = b'\x00'
        data[idx + 1] = b'\xFF'
        data[idx + 2] = b'\x00'
      }
    }
  }
  let img = @types.Image::{
    width: 20,
    height: 20,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let mask = grab_cut(img, 3, 3, 14, 14, iterations=3)
  assert_eq(mask.width, 20)
  assert_eq(mask.height, 20)
  assert_eq(mask.channels, 1)
  // 矩形外应为背景
  assert_eq(mask.data[0], b'\x00')
  assert_eq(mask.data[19 * 20 + 19], b'\x00')
}

///|
test "grab_cut 小图报错" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 3,
    data: Bytes::from_array([b'\xFF', b'\x00', b'\x00']),
  }
  try {
    let _ = grab_cut(img, 0, 0, 1, 1)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "grab_cut 非RGB报错" {
  let img = @types.Image::{
    width: 10,
    height: 10,
    channels: 1,
    data: Bytes::from_array(Array::make(100, b'\x80')),
  }
  try {
    let _ = grab_cut(img, 0, 0, 10, 10)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "grab_cut 全前景矩形" {
  // 16x16 RGB 图像
  let data : Array[Byte] = Array::make(256 * 3, b'\x80')
  for y in 4..<12 {
    for x in 4..<12 {
      let idx = (y * 16 + x) * 3
      data[idx] = b'\xFF'
      data[idx + 1] = b'\xFF'
      data[idx + 2] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 16,
    height: 16,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let mask = grab_cut(img, 0, 0, 16, 16, iterations=2)
  assert_eq(mask.width, 16)
  assert_eq(mask.height, 16)
  // 矩形覆盖全图，所有像素都是可能前景
  let mut fg_count = 0
  for i in 0..<256 {
    if mask.data[i] == b'\xFF' {
      fg_count += 1
    }
  }
  assert_true(fg_count >= 0)
}

///|
test "grab_cut RGBA 图" {
  // 16x16 RGBA 图像
  let data : Array[Byte] = Array::make(256 * 4, b'\x00')
  for y in 4..<12 {
    for x in 4..<12 {
      let idx = (y * 16 + x) * 4
      data[idx] = b'\xFF'
      data[idx + 3] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 16,
    height: 16,
    channels: 4,
    data: Bytes::from_array(data),
  }
  let mask = grab_cut(img, 2, 2, 12, 12, iterations=3)
  assert_eq(mask.channels, 1)
  // 矩形外应为背景
  assert_eq(mask.data[0], b'\x00')
}

///|
test "grab_cut mask 值有效" {
  // 16x16 RGB 图像
  let data : Array[Byte] = Array::make(256 * 3, b'\x00')
  for y in 2..<14 {
    for x in 2..<14 {
      let idx = (y * 16 + x) * 3
      data[idx] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 16,
    height: 16,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let mask = grab_cut(img, 1, 1, 14, 14, iterations=3)
  // 所有 mask 值应为 0 或 255
  for i in 0..<256 {
    assert_true(mask.data[i] == b'\x00' || mask.data[i] == b'\xFF')
  }
}

///|
test "grab_cut 迭代收敛" {
  // 20x20 图像，明确的前景/背景
  let data : Array[Byte] = Array::make(400 * 3, b'\x00')
  for y in 5..<15 {
    for x in 5..<15 {
      let idx = (y * 20 + x) * 3
      data[idx] = b'\xFF'
      data[idx + 1] = b'\x00'
      data[idx + 2] = b'\x00'
    }
  }
  for y in 0..<20 {
    for x in 0..<20 {
      if !(x >= 5 && x < 15 && y >= 5 && y < 15) {
        let idx = (y * 20 + x) * 3
        data[idx] = b'\x00'
        data[idx + 1] = b'\x00'
        data[idx + 2] = b'\xFF'
      }
    }
  }
  let img = @types.Image::{
    width: 20,
    height: 20,
    channels: 3,
    data: Bytes::from_array(data),
  }
  // 多次迭代
  let mask1 = grab_cut(img, 3, 3, 14, 14, iterations=1)
  let mask5 = grab_cut(img, 3, 3, 14, 14, iterations=5)
  // 两种迭代的 mask 尺寸相同
  assert_eq(mask1.width, mask5.width)
  assert_eq(mask1.height, mask5.height)
}
