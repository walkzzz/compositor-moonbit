// pixel_ops 测试：threshold / posterize / extract_channel / blend_*

///|
fn make_img(w : Int, h : Int, ch : Int, v : Byte) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Array::make(w * h * ch, v) |> Bytes::from_array,
  }
}

///|
test "threshold: 128 splits values" {
  let img = @types.Image::{
    width: 2,
    height: 1,
    channels: 1,
    data: [b'\x00', b'\xFF'] |> Bytes::from_array,
  }
  let result = threshold(img, 128)
  assert_eq(result.data[0], b'\x00')
  assert_eq(result.data[1], b'\xFF')
  let _ = img
  let _ = result
}

///|
test "threshold: preserves alpha" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 4,
    data: [b'\x40', b'\x40', b'\x40', b'\x80'] |> Bytes::from_array,
  }
  let result = threshold(img, 128)
  assert_eq(result.data[3], b'\x80')
  let _ = img
  let _ = result
}

///|
test "posterize: 2 levels equals binary" {
  let img = @types.Image::{
    width: 4,
    height: 1,
    channels: 1,
    data: [b'\x00', b'\x40', b'\x80', b'\xFF'] |> Bytes::from_array,
  }
  let result = posterize(img, 2)
  assert_eq(result.data[0], b'\x00')
  assert_eq(result.data[3], b'\x80')
  let _ = img
  let _ = result
}

///|
test "posterize: raises on invalid levels" {
  let img = make_img(1, 1, 1, b'\x80')
  try {
    let _ = posterize(img, 1)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "extract_channel: extracts R from RGB" {
  let img = @types.Image::{
    width: 2,
    height: 1,
    channels: 3,
    data: [b'\x10', b'\x20', b'\x30', b'\x40', b'\x50', b'\x60']
    |> Bytes::from_array,
  }
  let r = extract_channel(img, 0)
  assert_eq(r.channels, 1)
  assert_eq(r.data[0], b'\x10')
  assert_eq(r.data[1], b'\x40')
  let g = extract_channel(img, 1)
  assert_eq(g.data[0], b'\x20')
  let b_ch = extract_channel(img, 2)
  assert_eq(b_ch.data[0], b'\x30')
  let _ = img
  let _ = r
  let _ = g
  let _ = b_ch
}

///|
test "extract_channel: raises on out of bounds" {
  let img = make_img(1, 1, 3, b'\x80')
  try {
    let _ = extract_channel(img, 3)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "blend_multiply: white * any = any" {
  let base = make_img(2, 2, 3, b'\xFF')
  let blend = make_img(2, 2, 3, b'\x80')
  let result = blend_multiply(base, blend)
  assert_eq(result.data[0], b'\x80')
  let _ = base
  let _ = blend
  let _ = result
}

///|
test "blend_multiply: black * any = black" {
  let base = make_img(2, 2, 3, b'\x00')
  let blend = make_img(2, 2, 3, b'\x80')
  let result = blend_multiply(base, blend)
  assert_eq(result.data[0], b'\x00')
  let _ = base
  let _ = blend
  let _ = result
}

///|
test "blend_screen: black + any = any" {
  let base = make_img(2, 2, 3, b'\x00')
  let blend = make_img(2, 2, 3, b'\x80')
  let result = blend_screen(base, blend)
  assert_eq(result.data[0], b'\x80')
  let _ = base
  let _ = blend
  let _ = result
}

///|
test "blend_screen: white + any = white" {
  let base = make_img(2, 2, 3, b'\xFF')
  let blend = make_img(2, 2, 3, b'\x80')
  let result = blend_screen(base, blend)
  assert_eq(result.data[0], b'\xFF')
  let _ = base
  let _ = blend
  let _ = result
}

///|
test "blend_overlay: identity with mid-gray" {
  let base = make_img(2, 2, 3, b'\x80')
  let blend = make_img(2, 2, 3, b'\x80')
  let result = blend_overlay(base, blend)
  // overlay(128, 128) should be around 128
  let v = result.data[0].to_int()
  assert_true(v >= 126 && v <= 130)
  let _ = base
  let _ = blend
  let _ = result
}

///|
test "blend: raises on size mismatch" {
  let base = make_img(2, 2, 3, b'\x80')
  let blend = make_img(3, 3, 3, b'\x80')
  try {
    let _ = blend_multiply(base, blend)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = base
  let _ = blend
}

///|
test "blend_color_dodge: white blend gives white" {
  let base = make_img(2, 2, 3, b'\x80')
  let blend = make_img(2, 2, 3, b'\xFF')
  let result = blend_color_dodge(base, blend)
  assert_eq(result.data[0], b'\xFF')
  let _ = base
  let _ = blend
  let _ = result
}

///|
test "blend_color_dodge: zero blend gives base" {
  let base = make_img(2, 2, 3, b'\x80')
  let blend = make_img(2, 2, 3, b'\x00')
  let result = blend_color_dodge(base, blend)
  assert_eq(result.data[0], b'\x80')
  let _ = base
  let _ = blend
  let _ = result
}

///|
test "blend_color_burn: zero blend gives black" {
  let base = make_img(2, 2, 3, b'\x80')
  let blend = make_img(2, 2, 3, b'\x00')
  let result = blend_color_burn(base, blend)
  assert_eq(result.data[0], b'\x00')
  let _ = base
  let _ = blend
  let _ = result
}

///|
test "blend_color_burn: white blend gives base" {
  let base = make_img(2, 2, 3, b'\x80')
  let blend = make_img(2, 2, 3, b'\xFF')
  let result = blend_color_burn(base, blend)
  assert_eq(result.data[0], b'\x80')
  let _ = base
  let _ = blend
  let _ = result
}

///|
test "blend_hard_light: black blend gives black" {
  let base = make_img(2, 2, 3, b'\x80')
  let blend = make_img(2, 2, 3, b'\x00')
  let result = blend_hard_light(base, blend)
  assert_eq(result.data[0], b'\x00')
  let _ = base
  let _ = blend
  let _ = result
}

///|
test "blend_hard_light: white blend gives white" {
  let base = make_img(2, 2, 3, b'\x80')
  let blend = make_img(2, 2, 3, b'\xFF')
  let result = blend_hard_light(base, blend)
  assert_eq(result.data[0], b'\xFF')
  let _ = base
  let _ = blend
  let _ = result
}

///|
test "blend_soft_light: identity with black" {
  let base = make_img(2, 2, 3, b'\x80')
  let blend = make_img(2, 2, 3, b'\x00')
  let result = blend_soft_light(base, blend)
  // soft_light(128, 0) = 128*128/255 ≈ 64
  let v = result.data[0].to_int()
  assert_true(v >= 62 && v <= 66)
  let _ = base
  let _ = blend
  let _ = result
}

///|
test "blend_linear_dodge: adds and clamps" {
  let base = make_img(2, 2, 3, b'\x80')
  let blend = make_img(2, 2, 3, b'\x80')
  let result = blend_linear_dodge(base, blend)
  assert_eq(result.data[0], b'\xFF')
  let _ = base
  let _ = blend
  let _ = result
}

///|
test "blend_linear_burn: subtracts and clamps" {
  let base = make_img(2, 2, 3, b'\x40')
  let blend = make_img(2, 2, 3, b'\x40')
  let result = blend_linear_burn(base, blend)
  assert_eq(result.data[0], b'\x00')
  let _ = base
  let _ = blend
  let _ = result
}

///|
test "posterize: RGBA preserves alpha" {
  // 1x1 RGBA，posterize 应保留 alpha 通道
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 4,
    data: [b'\x80', b'\x40', b'\xC0', b'\xAA'] |> Bytes::from_array,
  }
  let result = posterize(img, 4)
  assert_eq(result.channels, 4)
  // alpha 应被保留
  assert_eq(result.data[3], b'\xAA')
  let _ = img
  let _ = result
}

///|
test "blend_screen: mismatched dimensions raises" {
  let base = make_img(2, 2, 3, b'\x80')
  let blend = make_img(3, 2, 3, b'\x80')
  try {
    let _ = blend_screen(base, blend)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "blend_overlay: mismatched dimensions raises" {
  let base = make_img(2, 2, 3, b'\x80')
  let blend = make_img(3, 2, 3, b'\x80')
  try {
    let _ = blend_overlay(base, blend)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "blend_darken: mismatched dimensions raises" {
  let base = make_img(2, 2, 3, b'\x80')
  let blend = make_img(2, 3, 3, b'\x80')
  try {
    let _ = blend_darken(base, blend)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "blend_lighten: mismatched dimensions raises" {
  let base = make_img(2, 2, 3, b'\x80')
  let blend = make_img(2, 2, 4, b'\x80')
  try {
    let _ = blend_lighten(base, blend)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "blend_difference: mismatched dimensions raises" {
  let base = make_img(2, 2, 3, b'\x80')
  let blend = make_img(3, 2, 3, b'\x00')
  try {
    let _ = blend_difference(base, blend)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "blend_exclusion: mismatched dimensions raises" {
  let base = make_img(1, 1, 3, b'\x80')
  let blend = make_img(1, 2, 3, b'\x00')
  try {
    let _ = blend_exclusion(base, blend)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "blend_color_dodge: mismatched dimensions raises" {
  let base = make_img(1, 1, 3, b'\x80')
  let blend = make_img(2, 1, 3, b'\x00')
  try {
    let _ = blend_color_dodge(base, blend)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "blend_color_burn: mismatched dimensions raises" {
  let base = make_img(1, 1, 3, b'\x80')
  let blend = make_img(1, 1, 4, b'\x00')
  try {
    let _ = blend_color_burn(base, blend)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "blend_hard_light: mismatched dimensions raises" {
  let base = make_img(1, 1, 3, b'\x80')
  let blend = make_img(2, 1, 3, b'\x00')
  try {
    let _ = blend_hard_light(base, blend)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "blend_soft_light: mismatched dimensions raises" {
  let base = make_img(1, 1, 3, b'\x80')
  let blend = make_img(1, 2, 3, b'\x00')
  try {
    let _ = blend_soft_light(base, blend)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "blend_linear_dodge: mismatched dimensions raises" {
  let base = make_img(1, 1, 3, b'\x80')
  let blend = make_img(2, 1, 3, b'\x00')
  try {
    let _ = blend_linear_dodge(base, blend)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}

///|
test "blend_linear_burn: mismatched dimensions raises" {
  let base = make_img(1, 1, 3, b'\x80')
  let blend = make_img(1, 2, 3, b'\x00')
  try {
    let _ = blend_linear_burn(base, blend)
    fail("expected error")
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => fail("wrong error")
  }
}
