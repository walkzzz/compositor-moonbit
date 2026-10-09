// image_compose 测试：hstack / vstack / tile / transpose

///|
fn mk(w : Int, h : Int, ch : Int, v : Byte) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Array::make(w * h * ch, v) |> Bytes::from_array,
  }
}

///|
test "hstack: 2x2 + 2x2 = 4x2" {
  let a = mk(2, 2, 1, b'\x10')
  let b = mk(2, 2, 1, b'\x20')
  let result = hstack(a, b)
  assert_eq(result.width, 4)
  assert_eq(result.height, 2)
  assert_eq(result.data[0], b'\x10')
  assert_eq(result.data[2], b'\x20')
  let _ = a
  let _ = b
  let _ = result
}

///|
test "hstack: raises on height mismatch" {
  let a = mk(2, 2, 1, b'\x10')
  let b = mk(2, 3, 1, b'\x20')
  try {
    let _ = hstack(a, b)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = a
  let _ = b
}

///|
test "vstack: 2x2 + 2x2 = 2x4" {
  let a = mk(2, 2, 1, b'\x10')
  let b = mk(2, 2, 1, b'\x20')
  let result = vstack(a, b)
  assert_eq(result.width, 2)
  assert_eq(result.height, 4)
  assert_eq(result.data[0], b'\x10')
  assert_eq(result.data[4], b'\x20')
  let _ = a
  let _ = b
  let _ = result
}

///|
test "vstack: raises on width mismatch" {
  let a = mk(2, 2, 1, b'\x10')
  let b = mk(3, 2, 1, b'\x20')
  try {
    let _ = vstack(a, b)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = a
  let _ = b
}

///|
test "tile: 2x2 x (2,3) = 4x6" {
  let img = mk(2, 2, 1, b'\x80')
  let result = tile(img, 2, 3)
  assert_eq(result.width, 4)
  assert_eq(result.height, 6)
  assert_eq(result.data[0], b'\x80')
  let _ = img
  let _ = result
}

///|
test "tile: 1x1 x (1,1) is identity" {
  let img = mk(1, 1, 1, b'\xFF')
  let result = tile(img, 1, 1)
  assert_eq(result.data, img.data)
  let _ = img
  let _ = result
}

///|
test "transpose: swaps dimensions" {
  let img = @types.Image::{
    width: 2,
    height: 3,
    channels: 1,
    data: [b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06']
    |> Bytes::from_array,
  }
  let result = transpose(img)
  assert_eq(result.width, 3)
  assert_eq(result.height, 2)
  // (0,0) -> (0,0)
  assert_eq(result.data[0], b'\x01')
  // (1,0) -> (0,1) in transposed: data[1*3+0] = data[3]
  assert_eq(result.data[3], b'\x02')
  let _ = img
  let _ = result
}

///|
test "tile: raises on zero cols" {
  let img = mk(2, 2, 1, b'\x80')
  try {
    let _ = tile(img, 0, 1)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}

///|
test "tile: raises on zero rows" {
  let img = mk(2, 2, 1, b'\x80')
  try {
    let _ = tile(img, 1, 0)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  let _ = img
}
