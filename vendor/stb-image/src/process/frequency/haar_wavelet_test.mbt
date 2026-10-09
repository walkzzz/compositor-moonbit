// Haar 小波变换测试

///|
test "haar_transform_1d 基本功能" {
  let data = [1.0F, 2.0F, 3.0F, 4.0F]
  let result = haar_transform_1d(data)
  assert_eq(result.length(), 4)
  // 原始数据不应被修改
  assert_eq(data[0], 1.0F)
}

///|
test "haar_transform_1d 逆变换" {
  let data = [1.0F, 2.0F, 3.0F, 4.0F]
  let transformed = haar_transform_1d(data)
  let inversed = ihaar_transform_1d(transformed)
  // 逆变换应恢复原始数据
  for i in 0..<4 {
    assert_true((inversed[i] - data[i]).abs() < 0.001F)
  }
}

///|
test "haar_transform_1d 单元素" {
  let data = [5.0F]
  let result = haar_transform_1d(data)
  assert_eq(result[0], 5.0F)
}

///|
test "haar_transform_1d 常量信号" {
  let data = [3.0F, 3.0F, 3.0F, 3.0F]
  let result = haar_transform_1d(data)
  // 常量信号的细节系数应为 0
  assert_true(result[2].abs() < 0.001F)
  assert_true(result[3].abs() < 0.001F)
}

///|
test "haar_transform_2d 基本功能" {
  let data = Bytes::from_array([
    b'\x10', b'\x20', b'\x30', b'\x40', b'\x50', b'\x60', b'\x70', b'\x80', b'\x90',
    b'\xA0', b'\xB0', b'\xC0', b'\xD0', b'\xE0', b'\xF0', b'\x00',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let result = haar_transform_2d(img, levels=1)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.levels, 1)
  assert_eq(result.coefficients.length(), 16)
}

///|
test "haar_transform_2d 逆变换" {
  let data = Bytes::from_array([
    b'\x10', b'\x20', b'\x30', b'\x40', b'\x50', b'\x60', b'\x70', b'\x80', b'\x90',
    b'\xA0', b'\xB0', b'\xC0', b'\xD0', b'\xE0', b'\xF0', b'\x00',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let result = haar_transform_2d(img, levels=1)
  let reconstructed = haar_inverse_transform_2d(result)
  assert_eq(reconstructed.width, 4)
  assert_eq(reconstructed.height, 4)
  assert_eq(reconstructed.channels, 1)
  // 大部分像素应恢复（可能有舍入误差）
  let mut correct = 0
  for i in 0..<16 {
    if (reconstructed.data[i].to_int() - data[i].to_int()).abs() <= 1 {
      correct += 1
    }
  }
  assert_true(correct >= 12)
}

///|
test "haar_transform_2d 错误参数" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Bytes::from_array(Array::make(16, b'\x00')),
  }
  try {
    let _ = haar_transform_2d(img, levels=0)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  try {
    let _ = haar_transform_2d(img, levels=20)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "haar_denoise 基本功能" {
  let data = Bytes::from_array([
    b'\x40', b'\x41', b'\x3F', b'\x40', b'\x40', b'\x3F', b'\x41', b'\x40', b'\x41',
    b'\x40', b'\x40', b'\x3F', b'\x3F', b'\x40', b'\x41', b'\x40',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let out = haar_denoise(img, threshold=2.0F, soft=true, levels=1)
  assert_eq(out.width, 4)
  assert_eq(out.height, 4)
  assert_eq(out.channels, 1)
  // 去噪后像素应在合理范围
  for i in 0..<16 {
    let v = out.data[i].to_int()
    assert_true(v >= 0 && v <= 255)
  }
}

///|
test "haar_denoise 硬阈值" {
  let data = Bytes::from_array([
    b'\x40', b'\x41', b'\x3F', b'\x40', b'\x40', b'\x3F', b'\x41', b'\x40', b'\x41',
    b'\x40', b'\x40', b'\x3F', b'\x3F', b'\x40', b'\x41', b'\x40',
  ])
  let img = @types.Image::{ width: 4, height: 4, channels: 1, data }
  let out = haar_denoise(img, threshold=5.0F, soft=false, levels=1)
  assert_eq(out.width, 4)
  assert_eq(out.height, 4)
}

///|
test "haar_denoise RGB 图" {
  let data = Bytes::from_array(Array::make(48, b'\x40'))
  let img = @types.Image::{ width: 4, height: 4, channels: 3, data }
  let out = haar_denoise(img, threshold=2.0F, levels=1)
  assert_eq(out.width, 4)
  assert_eq(out.height, 4)
  assert_eq(out.channels, 1)
}

///|
test "ihaar_transform_1d 单元素" {
  let data = [5.0F]
  let result = ihaar_transform_1d(data)
  assert_eq(result[0], 5.0F)
}

///|
test "ihaar_transform_1d 空数组" {
  let data : Array[Float] = []
  let result = ihaar_transform_1d(data)
  assert_eq(result.length(), 0)
}
