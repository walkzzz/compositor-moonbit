// 光流测试

///|
test "lucas_kanade 零位移" {
  // 两帧相同图像，光流应为零
  let data : Array[Byte] = Array::make(100, b'\x00')
  for y in 0..<10 {
    for x in 0..<10 {
      data[y * 10 + x] = (x * 10).to_byte()
    }
  }
  let img = @types.Image::{
    width: 10,
    height: 10,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let points = [(5, 5)]
  let results = lucas_kanade(img, img, points, window_size=5)
  assert_eq(results.length(), 1)
  // 位移应接近零
  assert_true(results[0].u.abs() < 1.0F)
  assert_true(results[0].v.abs() < 1.0F)
}

///|
test "lucas_kanade 水平位移" {
  // 第一帧：2D 图案（x*y 渐变，两个方向都有梯度）
  let data1 : Array[Byte] = Array::make(100, b'\x00')
  for y in 0..<10 {
    for x in 0..<10 {
      data1[y * 10 + x] = (x * y * 2).clamp(min=0, max=255).to_byte()
    }
  }
  // 第二帧：右移1像素
  let data2 : Array[Byte] = Array::make(100, b'\x00')
  for y in 0..<10 {
    for x in 0..<10 {
      let sx = if x > 0 { x - 1 } else { 0 }
      data2[y * 10 + x] = (sx * y * 2).clamp(min=0, max=255).to_byte()
    }
  }
  let prev = @types.Image::{
    width: 10,
    height: 10,
    channels: 1,
    data: Bytes::from_array(data1),
  }
  let next = @types.Image::{
    width: 10,
    height: 10,
    channels: 1,
    data: Bytes::from_array(data2),
  }
  let points = [(5, 5)]
  let results = lucas_kanade(prev, next, points, window_size=5, max_iter=30)
  assert_eq(results.length(), 1)
  // 应检测到水平位移
  assert_true(results[0].found)
}

///|
test "lucas_kanade 尺寸不一致报错" {
  let img1 = @types.Image::{
    width: 10,
    height: 10,
    channels: 1,
    data: Bytes::from_array(Array::make(100, b'\x00')),
  }
  let img2 = @types.Image::{
    width: 8,
    height: 8,
    channels: 1,
    data: Bytes::from_array(Array::make(64, b'\x00')),
  }
  try {
    let _ = lucas_kanade(img1, img2, [(5, 5)])
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "lucas_kanade 多点" {
  let data : Array[Byte] = Array::make(100, b'\x00')
  for y in 0..<10 {
    for x in 0..<10 {
      data[y * 10 + x] = (x * y * 2).clamp(min=0, max=255).to_byte()
    }
  }
  let img = @types.Image::{
    width: 10,
    height: 10,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let points = [(3, 3), (5, 5), (7, 7)]
  let results = lucas_kanade(img, img, points, window_size=3)
  assert_eq(results.length(), 3)
}

///|
test "lucas_kanade RGB 图" {
  let data : Array[Byte] = Array::make(300, b'\x00')
  for y in 0..<10 {
    for x in 0..<10 {
      let idx = (y * 10 + x) * 3
      data[idx] = (x * 20).clamp(min=0, max=255).to_byte()
    }
  }
  let img = @types.Image::{
    width: 10,
    height: 10,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let points = [(5, 5)]
  let results = lucas_kanade(img, img, points, window_size=3)
  assert_eq(results.length(), 1)
  assert_true(results[0].u.abs() < 1.0F)
}

///|
test "horn_schunck 零位移" {
  let data : Array[Byte] = Array::make(100, b'\x00')
  for y in 0..<10 {
    for x in 0..<10 {
      data[y * 10 + x] = (x * 10).to_byte()
    }
  }
  let img = @types.Image::{
    width: 10,
    height: 10,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let (u, v) = horn_schunck(img, img, alpha=1.0F, iterations=50)
  // 相同帧，光流应接近零
  let mut max_u = 0.0F
  let mut max_v = 0.0F
  for i in 0..<100 {
    if u[i].abs() > max_u {
      max_u = u[i].abs()
    }
    if v[i].abs() > max_v {
      max_v = v[i].abs()
    }
  }
  assert_true(max_u < 1.0F)
  assert_true(max_v < 1.0F)
}

///|
test "horn_schunck 尺寸不一致报错" {
  let img1 = @types.Image::{
    width: 10,
    height: 10,
    channels: 1,
    data: Bytes::from_array(Array::make(100, b'\x00')),
  }
  let img2 = @types.Image::{
    width: 8,
    height: 8,
    channels: 1,
    data: Bytes::from_array(Array::make(64, b'\x00')),
  }
  try {
    let _ = horn_schunck(img1, img2)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "horn_schunck 返回正确大小" {
  let img = @types.Image::{
    width: 10,
    height: 10,
    channels: 1,
    data: Bytes::from_array(Array::make(100, b'\x00')),
  }
  let (u, v) = horn_schunck(img, img, iterations=10)
  assert_eq(u.length(), 100)
  assert_eq(v.length(), 100)
}
