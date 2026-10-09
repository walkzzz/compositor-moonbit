// color_map 测试：apply_lut / gradient_map / set_alpha / fill_alpha

///|
test "apply_lut: identity lut" {
  let img = @types.Image::{
    width: 3,
    height: 1,
    channels: 1,
    data: [b'\x00', b'\x80', b'\xFF'] |> Bytes::from_array,
  }
  let lut = Array::make(256, b'\x00')
  for i in 0..<256 {
    lut[i] = i.to_byte()
  }
  let result = apply_lut(img, lut)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "apply_lut: invert lut" {
  let img = @types.Image::{
    width: 2,
    height: 1,
    channels: 1,
    data: [b'\x00', b'\xFF'] |> Bytes::from_array,
  }
  let lut = Array::make(256, b'\x00')
  for i in 0..<256 {
    lut[i] = (255 - i).to_byte()
  }
  let result = apply_lut(img, lut)
  assert_eq(result.data[0], b'\xFF')
  assert_eq(result.data[1], b'\x00')
  let _ = img
  let _ = result
}

///|
test "apply_lut: raises on short lut" {
  let img = mk(1, 1, 1, b'\x80')
  try {
    let _ = apply_lut(img, Array::make(10, b'\x00'))
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "gradient_map: two color stops" {
  let img = mk(2, 1, 3, b'\x00')
  let stops = [(0, b'\x00', b'\x00', b'\x00'), (255, b'\xFF', b'\xFF', b'\xFF')]
  let result = gradient_map(img, stops)
  assert_eq(result.channels, 3)
  assert_eq(result.data[0], b'\x00')
  let _ = img
  let _ = result
}

///|
test "gradient_map: raises on insufficient stops" {
  let img = mk(1, 1, 1, b'\x80')
  try {
    let _ = gradient_map(img, [(0, b'\x00', b'\x00', b'\x00')])
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "set_alpha: sets all alpha to value" {
  let img = mk(2, 2, 4, b'\x80')
  let result = set_alpha(img, b'\xFF')
  for i in 0..<4 {
    assert_eq(result.data[i * 4 + 3], b'\xFF')
  }
  let _ = img
  let _ = result
}

///|
test "set_alpha: raises on non-RGBA" {
  let img = mk(1, 1, 3, b'\x80')
  try {
    let _ = set_alpha(img, b'\xFF')
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "fill_alpha: fills transparent pixels" {
  let img = @types.Image::{
    width: 2,
    height: 1,
    channels: 4,
    data: [
      b'\xFF', b'\x00', b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00', b'\xFF',
    ]
    |> Bytes::from_array,
  }
  let result = fill_alpha(img, 128, b'\x00', b'\x00', b'\x00')
  // 第一个像素 alpha=0 < 128，填充为黑色
  assert_eq(result.data[0], b'\x00')
  assert_eq(result.data[1], b'\x00')
  assert_eq(result.data[2], b'\x00')
  // 第二个像素 alpha=255 >= 128，保持原样
  assert_eq(result.data[4], b'\x00')
  assert_eq(result.data[5], b'\xFF')
  let _ = img
  let _ = result
}

///|
test "fill_alpha: raises on non-RGBA" {
  let img = mk(1, 1, 3, b'\x80')
  try {
    let _ = fill_alpha(img, 128, b'\x00', b'\x00', b'\x00')
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "apply_lut: RGBA preserves alpha channel" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 4,
    data: [b'\x10', b'\x20', b'\x30', b'\x88'] |> Bytes::from_array,
  }
  let lut = Array::make(256, b'\x00')
  for i in 0..<256 {
    lut[i] = (255 - i).to_byte()
  }
  let result = apply_lut(img, lut)
  assert_eq(result.data[0], b'\xEF')
  assert_eq(result.data[1], b'\xDF')
  assert_eq(result.data[2], b'\xCF')
  assert_eq(result.data[3], b'\x88')
  let _ = img
  let _ = result
}

///|
test "gradient_map: single channel image" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: [b'\x80'] |> Bytes::from_array,
  }
  let stops = [(0, b'\x00', b'\x00', b'\x00'), (255, b'\xFF', b'\x00', b'\x00')]
  let result = gradient_map(img, stops)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}
