// 模板匹配测试

///|
test "template_match SqDiff 基本功能" {
  // 10x10 图像，左上角 3x3 区域为白色
  let data : Array[Byte] = Array::make(100, b'\x00')
  for y in 0..<3 {
    for x in 0..<3 {
      data[y * 10 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 10,
    height: 10,
    channels: 1,
    data: Bytes::from_array(data),
  }
  // 3x3 白色模板
  let tpl_data = Bytes::from_array(Array::make(9, b'\xFF'))
  let tpl = @types.Image::{ width: 3, height: 3, channels: 1, data: tpl_data }
  let results = template_match(img, tpl, match_method=SqDiff)
  // 应有 (10-3+1)^2 = 64 个位置
  assert_eq(results.length(), 64)
  // (0,0) 位置 SqDiff 应为 0（完美匹配）
  let best = results[0]
  assert_eq(best.x, 0)
  assert_eq(best.y, 0)
  assert_eq(best.score, 0.0F)
}

///|
test "template_match CCoeffNormed 完美匹配" {
  // 10x10 图像，中心 4x4 区域有图案
  let data : Array[Byte] = Array::make(100, b'\x40')
  for y in 3..<7 {
    for x in 3..<7 {
      data[y * 10 + x] = if (x + y) % 2 == 0 { b'\xFF' } else { b'\x00' }
    }
  }
  let img = @types.Image::{
    width: 10,
    height: 10,
    channels: 1,
    data: Bytes::from_array(data),
  }
  // 4x4 棋盘格模板
  let tpl_data : Array[Byte] = Array::make(16, b'\x00')
  for y in 0..<4 {
    for x in 0..<4 {
      tpl_data[y * 4 + x] = if (x + y) % 2 == 0 { b'\xFF' } else { b'\x00' }
    }
  }
  let tpl = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: Bytes::from_array(tpl_data),
  }
  let best = template_match_best(img, tpl, match_method=CCoeffNormed)
  match best {
    Some(r) => {
      assert_eq(r.x, 3)
      assert_eq(r.y, 3)
      // 归一化相关系数应接近 1.0
      assert_true(r.score > 0.99F)
    }
    None => assert_true(false)
  }
}

///|
test "template_match CCorr 基本功能" {
  let data : Array[Byte] = Array::make(100, b'\x00')
  for y in 2..<5 {
    for x in 2..<5 {
      data[y * 10 + x] = b'\x80'
    }
  }
  let img = @types.Image::{
    width: 10,
    height: 10,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let tpl_data = Bytes::from_array(Array::make(9, b'\x80'))
  let tpl = @types.Image::{ width: 3, height: 3, channels: 1, data: tpl_data }
  let results = template_match(img, tpl, match_method=CCorr)
  assert_eq(results.length(), 64)
  // (2,2) 位置应有最大互相关
  let best = template_match_best(img, tpl, match_method=CCorr)
  match best {
    Some(r) => {
      assert_eq(r.x, 2)
      assert_eq(r.y, 2)
    }
    None => assert_true(false)
  }
}

///|
test "template_match 通道数不一致报错" {
  let img = @types.Image::{
    width: 10,
    height: 10,
    channels: 1,
    data: Bytes::from_array(Array::make(100, b'\x00')),
  }
  let tpl = @types.Image::{
    width: 3,
    height: 3,
    channels: 3,
    data: Bytes::from_array(Array::make(27, b'\x00')),
  }
  try {
    let _ = template_match(img, tpl)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "template_match 模板大于图像报错" {
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(Array::make(25, b'\x00')),
  }
  let tpl = @types.Image::{
    width: 7,
    height: 7,
    channels: 1,
    data: Bytes::from_array(Array::make(49, b'\x00')),
  }
  try {
    let _ = template_match(img, tpl)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "template_match RGB 图" {
  // 10x10 RGB 图像
  let data : Array[Byte] = Array::make(300, b'\x00')
  for y in 2..<5 {
    for x in 2..<5 {
      let idx = (y * 10 + x) * 3
      data[idx] = b'\xFF'
      data[idx + 1] = b'\x00'
      data[idx + 2] = b'\x00'
    }
  }
  let img = @types.Image::{
    width: 10,
    height: 10,
    channels: 3,
    data: Bytes::from_array(data),
  }
  // 3x3 红色模板
  let tpl_data : Array[Byte] = Array::make(27, b'\x00')
  for i in 0..<9 {
    tpl_data[i * 3] = b'\xFF'
  }
  let tpl = @types.Image::{
    width: 3,
    height: 3,
    channels: 3,
    data: Bytes::from_array(tpl_data),
  }
  let best = template_match_best(img, tpl, match_method=SqDiff)
  match best {
    Some(r) => {
      assert_eq(r.x, 2)
      assert_eq(r.y, 2)
    }
    None => assert_true(false)
  }
}

///|
test "template_match_best 空结果" {
  // 模板与图像同大小，只有一个位置
  let img = @types.Image::{
    width: 3,
    height: 3,
    channels: 1,
    data: Bytes::from_array([
      b'\x00', b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00', b'\x00', b'\x00', b'\x00',
    ]),
  }
  let tpl = @types.Image::{
    width: 3,
    height: 3,
    channels: 1,
    data: Bytes::from_array([
      b'\xFF', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00', b'\x00',
    ]),
  }
  let best = template_match_best(img, tpl, match_method=CCoeffNormed)
  match best {
    Some(r) => assert_eq(r.x, 0)
    None => assert_true(false)
  }
}

///|
test "template_match SqDiffNormed 范围" {
  let data : Array[Byte] = Array::make(100, b'\x00')
  for y in 0..<5 {
    for x in 0..<5 {
      data[y * 10 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 10,
    height: 10,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let tpl_data = Bytes::from_array(Array::make(9, b'\xFF'))
  let tpl = @types.Image::{ width: 3, height: 3, channels: 1, data: tpl_data }
  let results = template_match(img, tpl, match_method=SqDiffNormed)
  // 所有分数应非负
  for r in results {
    assert_true(r.score >= 0.0F)
  }
}

///|
test "template_match CCoeffNormed 范围" {
  let data : Array[Byte] = Array::make(100, b'\x00')
  for y in 0..<5 {
    for x in 0..<5 {
      data[y * 10 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 10,
    height: 10,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let tpl_data = Bytes::from_array(Array::make(9, b'\xFF'))
  let tpl = @types.Image::{ width: 3, height: 3, channels: 1, data: tpl_data }
  let results = template_match(img, tpl, match_method=CCoeffNormed)
  // 所有分数应在 [-1, 1] 范围内
  for r in results {
    assert_true(r.score >= -1.0F - 0.001F)
    assert_true(r.score <= 1.0F + 0.001F)
  }
}
