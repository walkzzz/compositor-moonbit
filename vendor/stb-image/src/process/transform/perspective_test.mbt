///|
test "get_perspective_transform: identity transform" {
  let src = [(0.0F, 0.0F), (10.0F, 0.0F), (10.0F, 10.0F), (0.0F, 10.0F)]
  let dst = [(0.0F, 0.0F), (10.0F, 0.0F), (10.0F, 10.0F), (0.0F, 10.0F)]
  let m = get_perspective_transform(src, dst)
  assert_true(m is Some(_))
}

///|
test "get_perspective_transform: scaling transform" {
  let src = [(0.0F, 0.0F), (1.0F, 0.0F), (1.0F, 1.0F), (0.0F, 1.0F)]
  let dst = [(0.0F, 0.0F), (2.0F, 0.0F), (2.0F, 2.0F), (0.0F, 2.0F)]
  let m = get_perspective_transform(src, dst)
  match m {
    Some(mat) =>
      // m00 should be ~2 (x scaling)
      assert_true((mat.m00 - 2.0F).abs() < 0.1F)
    None => assert_true(false)
  }
}

///|
test "warp_perspective: identity preserves image" {
  let img = @types.Image::{
    width: 2,
    height: 2,
    channels: 1,
    data: b"\x00\x80\x40\xC0",
  }
  let m = PerspectiveMatrix::{
    m00: 1.0F,
    m01: 0.0F,
    m02: 0.0F,
    m10: 0.0F,
    m11: 1.0F,
    m12: 0.0F,
    m20: 0.0F,
    m21: 0.0F,
    m22: 1.0F,
  }
  let result = warp_perspective(img, m, 2, 2)
  assert_eq(result.data[0], img.data[0])
  assert_eq(result.data[1], img.data[1])
  assert_eq(result.data[2], img.data[2])
  assert_eq(result.data[3], img.data[3])
}

///|
test "get_affine_transform: identity" {
  let src = [(0.0F, 0.0F), (1.0F, 0.0F), (0.0F, 1.0F)]
  let dst = [(0.0F, 0.0F), (1.0F, 0.0F), (0.0F, 1.0F)]
  let m = get_affine_transform(src, dst)
  match m {
    Some(mat) => {
      assert_true((mat.a - 1.0F).abs() < 0.01F)
      assert_true((mat.e - 1.0F).abs() < 0.01F)
    }
    None => assert_true(false)
  }
}

///|
test "get_affine_transform: translation" {
  let src = [(0.0F, 0.0F), (1.0F, 0.0F), (0.0F, 1.0F)]
  let dst = [(5.0F, 3.0F), (6.0F, 3.0F), (5.0F, 4.0F)]
  let m = get_affine_transform(src, dst)
  match m {
    Some(mat) => {
      assert_true((mat.c - 5.0F).abs() < 0.01F)
      assert_true((mat.f - 3.0F).abs() < 0.01F)
    }
    None => assert_true(false)
  }
}

///|
test "get_rotation_matrix_2d: zero angle is identity" {
  let m = get_rotation_matrix_2d((0.0F, 0.0F), 0.0F, 1.0F)
  assert_true((m.a - 1.0F).abs() < 0.001F)
  assert_true(m.b.abs() < 0.001F)
  assert_true(m.d.abs() < 0.001F)
  assert_true((m.e - 1.0F).abs() < 0.001F)
}

///|
test "get_rotation_matrix_2d: 90 degree rotation" {
  let m = get_rotation_matrix_2d((0.0F, 0.0F), 1.5707963F, 1.0F)
  // cos(90°) ≈ 0, sin(90°) ≈ 1
  assert_true(m.a.abs() < 0.01F)
  assert_true((m.b - 1.0F).abs() < 0.01F)
  assert_true((m.d + 1.0F).abs() < 0.01F)
  assert_true(m.e.abs() < 0.01F)
}

///|
test "get_rotation_matrix_2d: scale factor" {
  let m = get_rotation_matrix_2d((0.0F, 0.0F), 0.0F, 2.0F)
  assert_true((m.a - 2.0F).abs() < 0.001F)
  assert_true((m.e - 2.0F).abs() < 0.001F)
}
