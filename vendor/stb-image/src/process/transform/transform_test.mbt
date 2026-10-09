///|
test "crop: 4x4 → 2x2 from (1,1)" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png)
  let cropped = crop(img, 1, 1, 2, 2)
  assert_eq(cropped.width, 2)
  assert_eq(cropped.height, 2)
  assert_eq(cropped.channels, img.channels)
  let _ = img
  let _ = cropped
}

///|
test "crop: full image crop is identity" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png)
  let cropped = crop(img, 0, 0, 4, 4)
  assert_eq(cropped.width, 4)
  assert_eq(cropped.height, 4)
  assert_eq(cropped.data, img.data)
  let _ = img
  let _ = cropped
}

///|
test "crop: out of bounds raises" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png)
  try {
    let _ = crop(img, 3, 3, 2, 2)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "rotate_90: 4x4 → 4x4 dimensions" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png)
  let r = rotate_90(img)
  assert_eq(r.width, 4)
  assert_eq(r.height, 4)
  let _ = img
  let _ = r
}

///|
test "rotate_90: non-square 2x4 → 4x2" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png)
  let cropped = crop(img, 0, 0, 2, 4)
  let r = rotate_90(cropped)
  assert_eq(r.width, 4)
  assert_eq(r.height, 2)
  let _ = img
  let _ = cropped
  let _ = r
}

///|
test "rotate_180: 4x4 dimensions preserved" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png)
  let r = rotate_180(img)
  assert_eq(r.width, 4)
  assert_eq(r.height, 4)
  let _ = img
  let _ = r
}

///|
test "rotate_270: non-square 2x4 → 4x2" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png)
  let cropped = crop(img, 0, 0, 2, 4)
  let r = rotate_270(cropped)
  assert_eq(r.width, 4)
  assert_eq(r.height, 2)
  let _ = img
  let _ = cropped
  let _ = r
}

///|
test "rotate: 4 rotations = identity" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png)
  let r = rotate_90(rotate_90(rotate_90(rotate_90(img))))
  assert_eq(r.width, 4)
  assert_eq(r.height, 4)
  assert_eq(r.data, img.data)
  let _ = img
  let _ = r
}

///|
test "flip_horizontal: 4x4 dimensions preserved" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png)
  let r = flip_horizontal(img)
  assert_eq(r.width, 4)
  assert_eq(r.height, 4)
  let _ = img
  let _ = r
}

///|
test "flip_horizontal: double flip = identity" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png)
  let r = flip_horizontal(flip_horizontal(img))
  assert_eq(r.data, img.data)
  let _ = img
  let _ = r
}

///|
test "flip_vertical: reverses rows" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: [b'\x01', b'\x02', b'\x03', b'\x04'] |> Bytes::from_array,
  }
  let result = flip_vertical(img)
  assert_eq(result.data[0], b'\x03')
  assert_eq(result.data[1], b'\x04')
  assert_eq(result.data[2], b'\x01')
  assert_eq(result.data[3], b'\x02')
  let _ = img
  let _ = result
}

///|
test "flip_vertical: double flip is identity" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: [b'\x01', b'\x02', b'\x03', b'\x04'] |> Bytes::from_array,
  }
  let result = flip_vertical(flip_vertical(img))
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "rotate_180: double rotation = identity" {
  let img = @lib.load_from_bytes_auto(test_4x4_red_png)
  let r = rotate_180(rotate_180(img))
  assert_eq(r.data, img.data)
  let _ = img
  let _ = r
}

///|
test "crop_16: 4x4 → 2x2" {
  let img = @lib.load_16_from_bytes_auto(test_4x4_red_png)
  let cropped = crop_16(img, 1, 1, 2, 2)
  assert_eq(cropped.width, 2)
  assert_eq(cropped.height, 2)
  let _ = img
  let _ = cropped
}

///|
test "crop_16: out of bounds raises" {
  let img = @lib.load_16_from_bytes_auto(test_4x4_red_png)
  try {
    let _ = crop_16(img, 3, 3, 2, 2)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}
