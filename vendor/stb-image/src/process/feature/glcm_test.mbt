// GLCM 纹理分析测试

///|
test "compute_glcm 基本功能" {
  // 3x1 灰度图
  let data = Bytes::from_array([b'\x00', b'\x01', b'\x02'])
  let img = @types.Image::{ width: 3, height: 1, channels: 1, data }
  let glcm = compute_glcm(img, 1, 0, levels=256)
  assert_eq(glcm.length(), 256)
  // (0,1) 和 (1,2) 各出现一次
  assert_eq(glcm[0][1], 1)
  assert_eq(glcm[1][2], 1)
}

///|
test "compute_glcm 垂直方向" {
  // 1x3 灰度图
  let data = Bytes::from_array([b'\x00', b'\x01', b'\x02'])
  let img = @types.Image::{ width: 1, height: 3, channels: 1, data }
  let glcm = compute_glcm(img, 0, 1, levels=256)
  assert_eq(glcm.length(), 256)
  assert_eq(glcm[0][1], 1)
  assert_eq(glcm[1][2], 1)
}

///|
test "compute_glcm 量化" {
  let data = Bytes::from_array([b'\x00', b'\x40', b'\x80', b'\xC0'])
  let img = @types.Image::{ width: 4, height: 1, channels: 1, data }
  let glcm = compute_glcm(img, 1, 0, levels=4)
  assert_eq(glcm.length(), 4)
  // 0/64=0, 64/64=1, 128/64=2, 192/64=3
  assert_eq(glcm[0][1], 1)
  assert_eq(glcm[1][2], 1)
  assert_eq(glcm[2][3], 1)
}

///|
test "compute_glcm 错误参数" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x00']),
  }
  try {
    let _ = compute_glcm(img, 1, 0, levels=1)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  try {
    let _ = compute_glcm(img, 1, 0, levels=300)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "glcm_features 基本功能" {
  let data = Bytes::from_array([b'\x00', b'\x40', b'\x80', b'\xC0'])
  let img = @types.Image::{ width: 4, height: 1, channels: 1, data }
  let glcm = compute_glcm(img, 1, 0, levels=256)
  let features = glcm_features(glcm)
  // 对比度应 > 0（因为相邻像素不同）
  assert_true(features.contrast > 0.0F)
  // 能量应 > 0
  assert_true(features.energy > 0.0F)
  // 同质性应 > 0
  assert_true(features.homogeneity > 0.0F)
}

///|
test "glcm_features 常量图" {
  let data = Bytes::from_array(Array::make(4, b'\x80'))
  let img = @types.Image::{ width: 4, height: 1, channels: 1, data }
  let glcm = compute_glcm(img, 1, 0, levels=256)
  let features = glcm_features(glcm)
  // 常量图对比度应为 0
  assert_true(features.contrast < 0.001F)
  // 能量应为 1（所有概率集中在对角线一个点）
  assert_true(features.energy > 0.99F)
}

///|
test "glcm_features 空矩阵" {
  let glcm : Array[Array[Int]] = []
  let features = glcm_features(glcm)
  assert_eq(features.contrast, 0.0F)
  assert_eq(features.energy, 0.0F)
}

///|
test "glcm_features_multi_direction 基本功能" {
  // 3x3 灰度图
  let data = Bytes::from_array([
    b'\x00', b'\x01', b'\x02', b'\x01', b'\x02', b'\x03', b'\x02', b'\x03', b'\x04',
  ])
  let img = @types.Image::{ width: 3, height: 3, channels: 1, data }
  let features = glcm_features_multi_direction(img, levels=8)
  assert_eq(features.length(), 4)
  // 每个方向都应有有效特征
  for f in features {
    assert_true(f.energy >= 0.0F)
    assert_true(f.contrast >= 0.0F)
  }
}

///|
test "compute_glcm 1x1 功能测试" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: Bytes::from_array([b'\x80']),
  }
  let glcm = compute_glcm(img, 1, 0, levels=4)
  // 1x1 图像无相邻像素，GLCM 应全零
  assert_eq(glcm.length(), 4)
  for y in 0..<4 {
    for x in 0..<4 {
      assert_eq(glcm[y][x], 0)
    }
  }
}
