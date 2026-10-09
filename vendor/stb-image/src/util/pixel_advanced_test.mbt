// pixel_advanced 测试：pixelate / replace_color / swap_channels

///|
test "pixelate: block_size=1 is identity" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: [b'\x10', b'\x20', b'\x30', b'\x40'] |> Bytes::from_array,
  }
  let result = pixelate(img, 1)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "pixelate: block_size=2 averages blocks" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: [
      b'\xFF', b'\xFF', b'\x00', b'\x00', b'\xFF', b'\xFF', b'\x00', b'\x00', b'\xFF',
      b'\xFF', b'\x00', b'\x00', b'\xFF', b'\xFF', b'\x00', b'\x00',
    ]
    |> Bytes::from_array,
  }
  let result = pixelate(img, 2)
  // 左上 2x2 块都取左上角值 0xFF
  assert_eq(result.data[0], b'\xFF')
  // 右上 2x2 块取 (2,0) 处值 0x00
  assert_eq(result.data[2], b'\x00')
  let _ = img
  let _ = result
}

///|
test "pixelate: raises on invalid block_size" {
  let img = make_img(2, 2, 1, b'\x80')
  try {
    let _ = pixelate(img, 0)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "replace_color: exact match" {
  let img = @types.Image::{
    width: 2,
    height: 1,
    channels: 3,
    data: [b'\xFF', b'\x00', b'\x00', b'\x00', b'\xFF', b'\x00']
    |> Bytes::from_array,
  }
  let result = replace_color(
    img,
    [b'\xFF', b'\x00', b'\x00'],
    [b'\x00', b'\x00', b'\xFF'],
    0,
  )
  assert_eq(result.data[0], b'\x00')
  assert_eq(result.data[2], b'\xFF')
  // 第二个像素不变
  assert_eq(result.data[3], b'\x00')
  let _ = img
  let _ = result
}

///|
test "replace_color: with tolerance" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: [b'\x80'] |> Bytes::from_array,
  }
  let result = replace_color(img, [b'\x7F'], [b'\x00'], 2)
  assert_eq(result.data[0], b'\x00')
  let _ = img
  let _ = result
}

///|
test "swap_channels: swap R and B" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 3,
    data: [b'\x10', b'\x20', b'\x30'] |> Bytes::from_array,
  }
  let result = swap_channels(img, 0, 2)
  assert_eq(result.data[0], b'\x30')
  assert_eq(result.data[1], b'\x20')
  assert_eq(result.data[2], b'\x10')
  let _ = img
  let _ = result
}

///|
test "swap_channels: same channel is identity" {
  let img = make_img(2, 2, 3, b'\x80')
  let result = swap_channels(img, 1, 1)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "swap_channels: raises on out of bounds" {
  let img = make_img(1, 1, 3, b'\x80')
  try {
    let _ = swap_channels(img, 0, 3)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "blend_darken: takes minimum" {
  let base = @types.Image::{
    width: 2,
    height: 1,
    channels: 1,
    data: [b'\x80', b'\x40'] |> Bytes::from_array,
  }
  let blend = @types.Image::{
    width: 2,
    height: 1,
    channels: 1,
    data: [b'\x40', b'\x80'] |> Bytes::from_array,
  }
  let result = blend_darken(base, blend)
  assert_eq(result.data[0], b'\x40')
  assert_eq(result.data[1], b'\x40')
  let _ = base
  let _ = blend
  let _ = result
}

///|
test "blend_lighten: takes maximum" {
  let base = @types.Image::{
    width: 2,
    height: 1,
    channels: 1,
    data: [b'\x80', b'\x40'] |> Bytes::from_array,
  }
  let blend = @types.Image::{
    width: 2,
    height: 1,
    channels: 1,
    data: [b'\x40', b'\x80'] |> Bytes::from_array,
  }
  let result = blend_lighten(base, blend)
  assert_eq(result.data[0], b'\x80')
  assert_eq(result.data[1], b'\x80')
  let _ = base
  let _ = blend
  let _ = result
}

///|
test "blend_difference: absolute difference" {
  let base = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: [b'\x80'] |> Bytes::from_array,
  }
  let blend = @types.Image::{
    width: 1,
    height: 1,
    channels: 1,
    data: [b'\x40'] |> Bytes::from_array,
  }
  let result = blend_difference(base, blend)
  assert_eq(result.data[0], b'\x40')
  let _ = base
  let _ = blend
  let _ = result
}

///|
test "blend_exclusion: same values gives mid-gray" {
  let base = make_img(1, 1, 1, b'\x80')
  let blend = make_img(1, 1, 1, b'\x80')
  let result = blend_exclusion(base, blend)
  let v = result.data[0].to_int()
  assert_true(v >= 126 && v <= 130)
  let _ = base
  let _ = blend
  let _ = result
}

///|
test "replace_color: raises on short old_color" {
  let img = make_img(1, 1, 3, b'\xFF')
  try {
    let _ = replace_color(img, [b'\xFF'], [b'\x00', b'\x00', b'\x00'], 0)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "replace_color: raises on short new_color" {
  let img = make_img(1, 1, 3, b'\xFF')
  try {
    let _ = replace_color(img, [b'\xFF', b'\x00', b'\x00'], [b'\x00'], 0)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "replace_color: tolerance match" {
  let img = @types.Image::{
    width: 2,
    height: 1,
    channels: 3,
    data: [b'\x7F', b'\x80', b'\x81', b'\xFF', b'\x00', b'\x00']
    |> Bytes::from_array,
  }
  let result = replace_color(
    img,
    [b'\x80', b'\x80', b'\x80'],
    [b'\x00', b'\xFF', b'\x00'],
    2,
  )
  // First pixel (0x7F,0x80,0x81) is within tolerance of (0x80,0x80,0x80)
  assert_eq(result.data[0], b'\x00')
  assert_eq(result.data[1], b'\xFF')
  assert_eq(result.data[2], b'\x00')
  // Second pixel (0xFF,0x00,0x00) is not within tolerance
  assert_eq(result.data[3], b'\xFF')
  let _ = img
  let _ = result
}
