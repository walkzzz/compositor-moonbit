///|
test "erode: uniform image is unchanged" {
  let img = @types.Image::{
    width: 3,
    height: 3,
    channels: 1,
    data: Array::make(9, b'\x80') |> Bytes::from_array,
  }
  let result = erode(img)
  for i in 0..<9 {
    assert_eq(result.data[i].to_int(), 128)
  }
  let _ = img
  let _ = result
}

///|
test "dilate: uniform image is unchanged" {
  let img = @types.Image::{
    width: 3,
    height: 3,
    channels: 1,
    data: Array::make(9, b'\x80') |> Bytes::from_array,
  }
  let result = dilate(img)
  for i in 0..<9 {
    assert_eq(result.data[i].to_int(), 128)
  }
  let _ = img
  let _ = result
}

///|
test "erode: shrinks bright region" {
  // 5x5 图像，中心 3x3 为白，其余为黑
  let data = Array::make(25, b'\x00')
  for y in 1..<=3 {
    for x in 1..<=3 {
      data[y * 5 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = erode(img)
  // 腐蚀后只有中心 (2,2) 保持白色
  assert_eq(result.data[2 * 5 + 2].to_int(), 255)
  // 角落应该变黑
  assert_eq(result.data[1 * 5 + 1].to_int(), 0)
  assert_eq(result.data[1 * 5 + 3].to_int(), 0)
  assert_eq(result.data[3 * 5 + 1].to_int(), 0)
  assert_eq(result.data[3 * 5 + 3].to_int(), 0)
  let _ = img
  let _ = result
}

///|
test "dilate: expands bright region" {
  // 5x5 图像，只有中心为白
  let data = Array::make(25, b'\x00')
  data[2 * 5 + 2] = b'\xFF'
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = dilate(img)
  // 膨胀后 3x3 邻域都应为白
  for dy in -1..<=1 {
    for dx in -1..<=1 {
      assert_eq(result.data[(2 + dy) * 5 + (2 + dx)].to_int(), 255)
    }
  }
  // 远处仍为黑
  assert_eq(result.data[0].to_int(), 0)
  assert_eq(result.data[24].to_int(), 0)
  let _ = img
  let _ = result
}

///|
test "morph_open: removes isolated bright pixel" {
  // 5x5 全黑，中心一个白点
  let data = Array::make(25, b'\x00')
  data[2 * 5 + 2] = b'\xFF'
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = morph_open(img)
  // 开运算去除孤立白点
  for i in 0..<25 {
    assert_eq(result.data[i].to_int(), 0)
  }
  let _ = img
  let _ = result
}

///|
test "morph_close: fills isolated dark pixel" {
  // 5x5 全白，中心一个黑点
  let data = Array::make(25, b'\xFF')
  data[2 * 5 + 2] = b'\x00'
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = morph_close(img)
  // 闭运算填充孤立黑点
  for i in 0..<25 {
    assert_eq(result.data[i].to_int(), 255)
  }
  let _ = img
  let _ = result
}

///|
test "erode: preserves dimensions" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = erode(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "dilate: preserves dimensions" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png, req_channels=Some(3))
  let result = dilate(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "morph_open: idempotent" {
  // 开运算是幂等的：open(open(img)) == open(img)
  let data = Array::make(25, b'\x00')
  for y in 1..<=3 {
    for x in 1..<=3 {
      data[y * 5 + x] = b'\xFF'
    }
  }
  data[2 * 5 + 2] = b'\x00'
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let once = morph_open(img)
  let twice = morph_open(once)
  assert_eq(once.data, twice.data)
  let _ = img
  let _ = once
  let _ = twice
}

///|
test "morph_close: idempotent" {
  // 闭运算是幂等的：close(close(img)) == close(img)
  let data = Array::make(25, b'\xFF')
  data[2 * 5 + 2] = b'\x00'
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let once = morph_close(img)
  let twice = morph_close(once)
  assert_eq(once.data, twice.data)
  let _ = img
  let _ = once
  let _ = twice
}

///|
test "morph_gradient: uniform image is zero" {
  let img = @types.Image::{
    width: 3,
    height: 3,
    channels: 1,
    data: Array::make(9, b'\x80') |> Bytes::from_array,
  }
  let result = morph_gradient(img)
  for i in 0..<9 {
    assert_eq(result.data[i].to_int(), 0)
  }
  let _ = img
  let _ = result
}

///|
test "morph_gradient: detects edges" {
  // 5x5 图像，左半白右半黑
  let data = Array::make(25, b'\x00')
  for y in 0..<5 {
    for x in 0..<2 {
      data[y * 5 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = morph_gradient(img)
  // 边界处应有非零值
  let mut has_nonzero = false
  for i in 0..<25 {
    if result.data[i].to_int() > 0 {
      has_nonzero = true
    }
  }
  assert_true(has_nonzero)
  let _ = img
  let _ = result
}

///|
test "morph_tophat: uniform image is zero" {
  let img = @types.Image::{
    width: 3,
    height: 3,
    channels: 1,
    data: Array::make(9, b'\x80') |> Bytes::from_array,
  }
  let result = morph_tophat(img)
  for i in 0..<9 {
    assert_eq(result.data[i].to_int(), 0)
  }
  let _ = img
  let _ = result
}

///|
test "morph_blackhat: uniform image is zero" {
  let img = @types.Image::{
    width: 3,
    height: 3,
    channels: 1,
    data: Array::make(9, b'\x80') |> Bytes::from_array,
  }
  let result = morph_blackhat(img)
  for i in 0..<9 {
    assert_eq(result.data[i].to_int(), 0)
  }
  let _ = img
  let _ = result
}

///|
test "morph_tophat: isolates bright peak" {
  // 5x5 黑图，中心一个白点
  let data = Array::make(25, b'\x00')
  data[2 * 5 + 2] = b'\xFF'
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = morph_tophat(img)
  // 中心白点应被保留（开运算去除了它）
  assert_eq(result.data[2 * 5 + 2].to_int(), 255)
  let _ = img
  let _ = result
}

///|
test "morph_blackhat: isolates dark hole" {
  // 5x5 白图，中心一个黑点
  let data = Array::make(25, b'\xFF')
  data[2 * 5 + 2] = b'\x00'
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = morph_blackhat(img)
  // 中心黑点应被检测到（闭运算填充了它）
  assert_eq(result.data[2 * 5 + 2].to_int(), 255)
  let _ = img
  let _ = result
}
