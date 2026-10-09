///|
fn make_gray_2x2() -> @types.Image {
  @types.Image::{ width: 2, height: 2, channels: 1, data: b"\x00\x55\xAA\xFF" }
}

///|
test "apply_colormap: GRAY preserves grayscale" {
  let img = make_gray_2x2()
  let result = apply_colormap(img, Colormap::GRAY)
  assert_eq(result.channels, 3)
  assert_eq(result.width, 2)
  assert_eq(result.height, 2)
  // GRAY: t=t, so R=G=B=gray
  assert_eq(result.data[0].to_int(), 0)
  assert_eq(result.data[3].to_int(), 85)
  assert_eq(result.data[6].to_int(), 170)
  assert_eq(result.data[9].to_int(), 255)
}

///|
test "apply_colormap: JET produces 3-channel output" {
  let img = make_gray_2x2()
  let result = apply_colormap(img, Colormap::JET)
  assert_eq(result.channels, 3)
  assert_eq(result.width * result.height, 4)
  // JET at 0 (t=0): blue dominant
  let b0 = result.data[2].to_int()
  assert_true(b0 > 100)
}

///|
test "apply_colormap: HOT at black is black" {
  let img = @types.Image::{ width: 1, height: 1, channels: 1, data: b"\x00" }
  let result = apply_colormap(img, Colormap::HOT)
  assert_eq(result.data[0].to_int(), 0)
  assert_eq(result.data[1].to_int(), 0)
  assert_eq(result.data[2].to_int(), 0)
}

///|
test "apply_colormap: HOT at white is white" {
  let img = @types.Image::{ width: 1, height: 1, channels: 1, data: b"\xFF" }
  let result = apply_colormap(img, Colormap::HOT)
  assert_eq(result.data[0].to_int(), 255)
  assert_eq(result.data[1].to_int(), 255)
  assert_eq(result.data[2].to_int(), 255)
}

///|
test "apply_colormap: COOL at black is blue" {
  let img = @types.Image::{ width: 1, height: 1, channels: 1, data: b"\x00" }
  let result = apply_colormap(img, Colormap::COOL)
  // COOL: (0, t, 1-t) → at t=0: (0, 0, 255)
  assert_eq(result.data[0].to_int(), 0)
  assert_eq(result.data[1].to_int(), 0)
  assert_eq(result.data[2].to_int(), 255)
}

///|
test "apply_colormap: works on RGB input (converts to gray first)" {
  let img = @types.Image::{
    width: 1,
    height: 1,
    channels: 3,
    data: b"\xFF\xFF\xFF",
  }
  let result = apply_colormap(img, Colormap::GRAY)
  // White → gray=255 → (255,255,255)
  assert_eq(result.data[0].to_int(), 255)
  assert_eq(result.data[1].to_int(), 255)
  assert_eq(result.data[2].to_int(), 255)
}

///|
test "apply_colormap: BONE produces valid output" {
  let img = make_gray_2x2()
  let result = apply_colormap(img, Colormap::BONE)
  assert_eq(result.channels, 3)
  for i in 0..<12 {
    let v = result.data[i].to_int()
    assert_true(v >= 0 && v <= 255)
  }
}

///|
test "apply_colormap: COPPER produces valid output" {
  let img = make_gray_2x2()
  let result = apply_colormap(img, Colormap::COPPER)
  assert_eq(result.channels, 3)
  // COPPER: (t*1.25, t*0.78, t*0.5) — R > G > B for mid-range
  let r = result.data[3].to_int()
  let g = result.data[4].to_int()
  let b = result.data[5].to_int()
  assert_true(r >= g)
  assert_true(g >= b)
}
