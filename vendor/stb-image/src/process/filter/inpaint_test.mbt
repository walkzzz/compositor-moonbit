// 图像修复测试

///|
test "inpaint 基本功能" {
  // 5x5 图像，中心像素缺失
  let data = Bytes::from_array([
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x80', b'\x80', b'\x00',
    b'\x00', b'\x00', b'\x80', b'\xFF', b'\x80', b'\x00', b'\x00', b'\x80', b'\x80',
    b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
  ])
  let img = @types.Image::{ width: 5, height: 5, channels: 1, data }
  // 掩码：仅中心像素待修复
  let mask_arr = Array::make(25, b'\x00')
  mask_arr[12] = b'\xFF'
  let mask = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(mask_arr),
  }
  let result = inpaint(img, mask, iterations=50)
  // 中心像素应被修复为邻域平均值（4个128 + 4个0 = 64）
  let center_val = result.data[12].to_int()
  assert_true(center_val > 40)
  assert_true(center_val < 100)
}

///|
test "inpaint 无掩码返回原图" {
  let data = Bytes::from_array(Array::make(25, b'\x80'))
  let img = @types.Image::{ width: 5, height: 5, channels: 1, data }
  let mask = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(Array::make(25, b'\x00')),
  }
  let result = inpaint(img, mask)
  // 无待修复像素，应返回原图
  for i in 0..<25 {
    assert_eq(result.data[i], b'\x80')
  }
}

///|
test "inpaint RGB 图" {
  // 5x5 RGB 图像
  let data : Array[Byte] = Array::make(75, b'\x00')
  for y in 0..<5 {
    for x in 0..<5 {
      let idx = (y * 5 + x) * 3
      data[idx] = b'\x80'
      data[idx + 1] = b'\x40'
      data[idx + 2] = b'\xC0'
    }
  }
  // 中心像素损坏
  let center = 12 * 3
  data[center] = b'\x00'
  data[center + 1] = b'\x00'
  data[center + 2] = b'\x00'
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let mask_arr = Array::make(25, b'\x00')
  mask_arr[12] = b'\xFF'
  let mask = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(mask_arr),
  }
  let result = inpaint(img, mask, iterations=50)
  // 中心像素应被修复
  assert_true(result.data[center].to_int() > 50)
}

///|
test "inpaint 尺寸不一致报错" {
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(Array::make(25, b'\x00')),
  }
  let mask = @types.Image::{
    width: 3,
    height: 3,
    channels: 1,
    data: Bytes::from_array(Array::make(9, b'\x00')),
  }
  try {
    let _ = inpaint(img, mask)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "inpaint 掩码通道错误" {
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(Array::make(25, b'\x00')),
  }
  let mask = @types.Image::{
    width: 5,
    height: 5,
    channels: 3,
    data: Bytes::from_array(Array::make(75, b'\x00')),
  }
  try {
    let _ = inpaint(img, mask)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "inpaint_fast 基本功能" {
  // 7x7 图像：全白，中心 3x3 区域缺失
  let data : Array[Byte] = Array::make(49, b'\xFF')
  let img = @types.Image::{
    width: 7,
    height: 7,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let mask_arr = Array::make(49, b'\x00')
  for y in 2..<=4 {
    for x in 2..<=4 {
      mask_arr[y * 7 + x] = b'\xFF'
    }
  }
  let mask = @types.Image::{
    width: 7,
    height: 7,
    channels: 1,
    data: Bytes::from_array(mask_arr),
  }
  let result = inpaint_fast(img, mask, radius=3)
  // 修复区域应从周围白色像素填充
  let center_val = result.data[3 * 7 + 3].to_int()
  assert_true(center_val > 200)
}

///|
test "inpaint_fast 无掩码返回原图" {
  let data = Bytes::from_array(Array::make(25, b'\x80'))
  let img = @types.Image::{ width: 5, height: 5, channels: 1, data }
  let mask = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(Array::make(25, b'\x00')),
  }
  let result = inpaint_fast(img, mask)
  for i in 0..<25 {
    assert_eq(result.data[i], b'\x80')
  }
}

///|
test "inpaint 线性渐变修复" {
  // 7x1 水平渐变：0, 40, 80, [缺失], 160, 200, 240
  let data : Array[Byte] = [
    b'\x00', b'\x28', b'\x50', b'\x00', b'\xA0', b'\xC8', b'\xF0',
  ]
  let img = @types.Image::{
    width: 7,
    height: 1,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let mask_arr = Array::make(7, b'\x00')
  mask_arr[3] = b'\xFF'
  let mask = @types.Image::{
    width: 7,
    height: 1,
    channels: 1,
    data: Bytes::from_array(mask_arr),
  }
  let result = inpaint(img, mask, iterations=100)
  // 修复值应介于 80 和 160 之间
  let val = result.data[3].to_int()
  assert_true(val >= 60)
  assert_true(val <= 180)
}
