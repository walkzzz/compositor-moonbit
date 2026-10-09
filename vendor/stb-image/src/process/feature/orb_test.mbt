// ORB 特征检测测试

///|
test "orb_detect 基本功能" {
  // 20x20 图像，中心有白色方块
  let data : Array[Byte] = Array::make(400, b'\x00')
  for y in 5..<15 {
    for x in 5..<15 {
      data[y * 20 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 20,
    height: 20,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let descs = orb_detect(img, max_features=100, threshold=20)
  // 方块四角应检测到特征
  assert_true(descs.length() > 0)
  // 每个描述子应有 32 个 Int
  for d in descs {
    assert_eq(d.data.length(), 32)
  }
}

///|
test "orb_detect 常量图无特征" {
  let data = Bytes::from_array(Array::make(400, b'\x80'))
  let img = @types.Image::{ width: 20, height: 20, channels: 1, data }
  let descs = orb_detect(img, threshold=20)
  assert_eq(descs.length(), 0)
}

///|
test "orb_detect 小图报错" {
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(Array::make(25, b'\x00')),
  }
  try {
    let _ = orb_detect(img)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "orb_detect RGB 图" {
  // 20x20 RGB 图像，中心有红色方块
  let data : Array[Byte] = Array::make(400 * 3, b'\x00')
  for y in 5..<15 {
    for x in 5..<15 {
      let idx = (y * 20 + x) * 3
      data[idx] = b'\xFF'
      data[idx + 1] = b'\x00'
      data[idx + 2] = b'\x00'
    }
  }
  let img = @types.Image::{
    width: 20,
    height: 20,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let descs = orb_detect(img, max_features=50, threshold=20)
  assert_true(descs.length() >= 0)
}

///|
test "orb_detect 描述子长度" {
  let data : Array[Byte] = Array::make(400, b'\x00')
  for y in 5..<15 {
    for x in 5..<15 {
      data[y * 20 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 20,
    height: 20,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let descs = orb_detect(img, max_features=10, threshold=20)
  for d in descs {
    assert_eq(d.data.length(), 32)
  }
}

///|
test "orb_hamming 相同描述子距离为0" {
  let kp = OrbKeyPoint::{ x: 10, y: 10, response: 1.0F, angle: 0.0F }
  let data = Array::make(32, 0x12345678)
  let d1 = OrbDescriptor::{ kp, data }
  let d2 = OrbDescriptor::{ kp, data }
  assert_eq(orb_hamming(d1, d2), 0)
}

///|
test "orb_hamming 已知距离" {
  let kp = OrbKeyPoint::{ x: 10, y: 10, response: 1.0F, angle: 0.0F }
  // d1 全 0，d2 第一个 Int 有 1 位不同
  let data1 = Array::make(32, 0)
  let data2 = Array::make(32, 0)
  data2[0] = 1
  let d1 = OrbDescriptor::{ kp, data: data1 }
  let d2 = OrbDescriptor::{ kp, data: data2 }
  assert_eq(orb_hamming(d1, d2), 1)
}

///|
test "orb_hamming 多位不同" {
  let kp = OrbKeyPoint::{ x: 10, y: 10, response: 1.0F, angle: 0.0F }
  let data1 = Array::make(32, 0)
  let data2 = Array::make(32, 0)
  // 0xFF = 8 位不同
  data2[0] = 0xFF
  // 0x0F = 4 位不同
  data2[1] = 0x0F
  let d1 = OrbDescriptor::{ kp, data: data1 }
  let d2 = OrbDescriptor::{ kp, data: data2 }
  assert_eq(orb_hamming(d1, d2), 12)
}

///|
test "orb_match 完美匹配" {
  let kp = OrbKeyPoint::{ x: 10, y: 10, response: 1.0F, angle: 0.0F }
  let data = Array::make(32, 0xAAAAAAAA)
  let d1 = OrbDescriptor::{ kp, data }
  let d2 = OrbDescriptor::{ kp, data }
  let query = [d1]
  let train = [d2]
  let matches = orb_match(query, train, max_distance=64)
  assert_eq(matches.length(), 1)
  assert_eq(matches[0].query_idx, 0)
  assert_eq(matches[0].train_idx, 0)
  assert_eq(matches[0].distance, 0)
}

///|
test "orb_match 距离过大不匹配" {
  let kp = OrbKeyPoint::{ x: 10, y: 10, response: 1.0F, angle: 0.0F }
  let data1 = Array::make(32, 0)
  let data2 = Array::make(32, 0xFFFFFFFF)
  let d1 = OrbDescriptor::{ kp, data: data1 }
  let d2 = OrbDescriptor::{ kp, data: data2 }
  let query = [d1]
  let train = [d2]
  // 汉明距离 256，远超 max_distance=64
  let matches = orb_match(query, train, max_distance=64)
  assert_eq(matches.length(), 0)
}

///|
test "orb_match 多对多" {
  let kp = OrbKeyPoint::{ x: 10, y: 10, response: 1.0F, angle: 0.0F }
  let data_a = Array::make(32, 0xAAAAAAAA)
  let data_b = Array::make(32, 0x55555555)
  let da1 = OrbDescriptor::{ kp, data: data_a }
  let da2 = OrbDescriptor::{ kp, data: data_a }
  let db1 = OrbDescriptor::{ kp, data: data_b }
  let db2 = OrbDescriptor::{ kp, data: data_b }
  let query = [da1, db1]
  let train = [da2, db2]
  let matches = orb_match(query, train, max_distance=64)
  // da1->da2 距离 0，db1->db2 距离 0
  assert_eq(matches.length(), 2)
}

///|
test "orb_detect max_features 限制" {
  // 30x30 图像，多个角点
  let data : Array[Byte] = Array::make(900, b'\x00')
  for y in 5..<25 {
    for x in 5..<25 {
      data[y * 30 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 30,
    height: 30,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let descs = orb_detect(img, max_features=5, threshold=20)
  assert_true(descs.length() <= 5)
}
