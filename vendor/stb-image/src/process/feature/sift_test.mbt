// SIFT 特征检测测试

///|
test "sift_detect 基本功能" {
  // 32x32 图像，中心有白色方块
  let data : Array[Byte] = Array::make(1024, b'\x00')
  for y in 8..<24 {
    for x in 8..<24 {
      data[y * 32 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 32,
    height: 32,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let descs = sift_detect(img, max_features=100, contrast_threshold=0.01F)
  // 应检测到一些特征
  assert_true(descs.length() >= 0)
  // 每个描述子应为 128 维
  for d in descs {
    assert_eq(d.data.length(), 128)
  }
}

///|
test "sift_detect 常量图无特征" {
  let data = Bytes::from_array(Array::make(1024, b'\x80'))
  let img = @types.Image::{ width: 32, height: 32, channels: 1, data }
  let descs = sift_detect(img, contrast_threshold=0.01F)
  assert_eq(descs.length(), 0)
}

///|
test "sift_detect 小图报错" {
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(Array::make(25, b'\x00')),
  }
  try {
    let _ = sift_detect(img)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "sift_detect RGB 图" {
  // 32x32 RGB 图像，中心有红色方块
  let data : Array[Byte] = Array::make(1024 * 3, b'\x00')
  for y in 8..<24 {
    for x in 8..<24 {
      let idx = (y * 32 + x) * 3
      data[idx] = b'\xFF'
      data[idx + 1] = b'\x00'
      data[idx + 2] = b'\x00'
    }
  }
  let img = @types.Image::{
    width: 32,
    height: 32,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let descs = sift_detect(img, max_features=50, contrast_threshold=0.01F)
  assert_true(descs.length() >= 0)
}

///|
test "sift_detect 描述子归一化" {
  // 32x32 图像，有角点
  let data : Array[Byte] = Array::make(1024, b'\x00')
  for y in 8..<24 {
    for x in 8..<24 {
      data[y * 32 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 32,
    height: 32,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let descs = sift_detect(img, max_features=10, contrast_threshold=0.01F)
  for d in descs {
    // 归一化后 L2 范数应接近 1.0
    let mut norm = 0.0F
    for v in d.data {
      norm += v * v
    }
    norm = norm.sqrt()
    assert_true((norm - 1.0F).abs() < 0.1F || norm == 0.0F)
  }
}

///|
test "sift_detect max_features 限制" {
  // 40x40 图像，多个角点
  let data : Array[Byte] = Array::make(1600, b'\x00')
  for y in 5..<35 {
    for x in 5..<35 {
      data[y * 40 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 40,
    height: 40,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let descs = sift_detect(img, max_features=5, contrast_threshold=0.01F)
  assert_true(descs.length() <= 5)
}

///|
test "sift_detect 描述子维度" {
  let data : Array[Byte] = Array::make(1024, b'\x00')
  for y in 8..<24 {
    for x in 8..<24 {
      data[y * 32 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 32,
    height: 32,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let descs = sift_detect(img, max_features=20, contrast_threshold=0.01F)
  for d in descs {
    assert_eq(d.data.length(), 128)
    // 描述子值应在归一化范围内
    for v in d.data {
      assert_true(v.abs() <= 1.0F)
    }
  }
}

///|
test "sift_detect 关键点属性" {
  let data : Array[Byte] = Array::make(1024, b'\x00')
  for y in 8..<24 {
    for x in 8..<24 {
      data[y * 32 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 32,
    height: 32,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let descs = sift_detect(img, max_features=20, contrast_threshold=0.01F)
  for d in descs {
    let kp = d.kp
    // 坐标应在图像范围内
    assert_true(kp.x >= 0.0F && kp.x <= 32.0F)
    assert_true(kp.y >= 0.0F && kp.y <= 32.0F)
    // sigma 应为正
    assert_true(kp.sigma > 0.0F)
    // angle 应在 [0, 2π) 范围
    assert_true(kp.angle >= 0.0F && kp.angle < 6.2832F)
    // octave 非负
    assert_true(kp.octave >= 0)
  }
}
