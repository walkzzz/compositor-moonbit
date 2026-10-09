///|
test "dct_2d: constant image has only DC component" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: b"\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80\x80",
  }
  let coeffs = dct_2d(img)
  // DC component (0,0) = cu*cv*sum = 0.5*0.5*16*128 = 512
  assert_true((coeffs[0][0] - 512.0).abs() < 2.0)
  assert_true(coeffs[0][1].abs() < 1.0)
  assert_true(coeffs[1][0].abs() < 1.0)
  assert_true(coeffs[1][1].abs() < 1.0)
}

///|
test "dct_2d + idct_2d: roundtrip recovers original" {
  let img = @types.Image::{
    width: 4,
    height: 4,
    channels: 1,
    data: b"\x00\x40\x80\xC0\x10\x50\x90\xD0\x20\x60\xA0\xE0\x30\x70\xB0\xF0",
  }
  let coeffs = dct_2d(img)
  let recovered = idct_2d(coeffs)
  // Should recover original within rounding tolerance
  let mut max_diff = 0
  for i in 0..<16 {
    let diff = (recovered.data[i].to_int() - img.data[i].to_int()).abs()
    if diff > max_diff {
      max_diff = diff
    }
  }
  assert_true(max_diff <= 2)
}

///|
test "dct_2d: output dimensions match input" {
  let img = @types.Image::{
    width: 3,
    height: 2,
    channels: 1,
    data: b"\x00\x80\xFF\x40\xC0\x20",
  }
  let coeffs = dct_2d(img)
  assert_eq(coeffs.length(), 2)
  assert_eq(coeffs[0].length(), 3)
}

///|
test "idct_2d: output dimensions match input" {
  let coeffs : Array[Array[Double]] = [[100.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
  let result = idct_2d(coeffs)
  assert_eq(result.width, 3)
  assert_eq(result.height, 2)
  assert_eq(result.channels, 1)
}
