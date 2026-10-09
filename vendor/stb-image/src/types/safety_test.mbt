// 安全守卫测试：验证 check_dims / safe_mul / safe_mul3 正确工作

///|
test "check_dims: valid dimensions pass" {
  @types.check_dims(100, 100, 3)
  @types.check_dims(1, 1, 1)
  @types.check_dims(65535, 1, 4)
  @types.check_dims(1920, 1080, 3)
}

///|
test "check_dims: zero width rejected" {
  try {
    @types.check_dims(0, 100, 3)
    assert_true(false) // should not reach
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "check_dims: zero height rejected" {
  try {
    @types.check_dims(100, 0, 3)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "check_dims: negative dimensions rejected" {
  try {
    @types.check_dims(-1, 100, 3)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "check_dims: dimensions exceeding MAX_IMAGE_DIMENSION rejected" {
  try {
    @types.check_dims(65536, 100, 3)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
  try {
    @types.check_dims(100, 65536, 3)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "check_dims: overflow in width*height rejected" {
  // 50000 * 50000 = 2,500,000,000 > Int32::MAX (2,147,483,647)
  try {
    @types.check_dims(50000, 50000, 1)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "check_dims: overflow in width*height*channels rejected" {
  // 40000 * 40000 = 1,600,000,000 (fits Int32)
  // 1,600,000,000 * 4 = 6,400,000,000 > Int32::MAX
  try {
    @types.check_dims(40000, 40000, 4)
    assert_true(false)
  } catch {
    @types.LoadError::DecodeFailed(_) => assert_true(true)
    _ => assert_true(false)
  }
}

///|
test "safe_mul: normal multiplication" {
  assert_eq(@types.safe_mul(100, 200), Some(20000))
  assert_eq(@types.safe_mul(0, 100), Some(0))
  assert_eq(@types.safe_mul(1, 1), Some(1))
}

///|
test "safe_mul: overflow returns None" {
  // 100000 * 100000 = 10,000,000,000 > Int32::MAX
  assert_eq(@types.safe_mul(100000, 100000), None)
  // 46341 * 46341 = 2,147,488,281 > Int32::MAX (2,147,483,647)
  assert_eq(@types.safe_mul(46341, 46341), None)
}

///|
test "safe_mul: boundary values" {
  // 46340 * 46340 = 2,147,395,600 < Int32::MAX
  assert_eq(@types.safe_mul(46340, 46340), Some(2147395600))
  // 46340 * 46341 = 2,147,441,940 < Int32::MAX
  assert_eq(@types.safe_mul(46340, 46341), Some(2147441940))
}

///|
test "safe_mul3: normal multiplication" {
  assert_eq(@types.safe_mul3(100, 200, 3), Some(60000))
  assert_eq(@types.safe_mul3(1920, 1080, 3), Some(6220800))
}

///|
test "safe_mul3: overflow returns None" {
  // 10000 * 10000 * 100 = 10,000,000,000 > Int32::MAX
  assert_eq(@types.safe_mul3(10000, 10000, 100), None)
}

///|
test "safe_mul3: overflow in second multiply" {
  // 50000 * 50000 = 2,500,000,000 > Int32::MAX (first mul overflows)
  assert_eq(@types.safe_mul3(50000, 50000, 1), None)
  // 20000 * 20000 = 400,000,000 (fits), * 100 = 40,000,000,000 > Int32::MAX
  assert_eq(@types.safe_mul3(20000, 20000, 100), None)
}

///|
test "MAX_IMAGE_DIMENSION value" {
  assert_eq(@types.MAX_IMAGE_DIMENSION, 65535)
}
