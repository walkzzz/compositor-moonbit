///|
test "good_features_to_track: finds corners in square" {
  // 7x7 image with a white square on black background
  let data : Array[Byte] = Array::make(49, b'\x00')
  for y in 2..<5 {
    for x in 2..<5 {
      data[y * 7 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 7,
    height: 7,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let corners = good_features_to_track(img, 10, 0.01F, min_distance=2)
  assert_true(corners.length() > 0)
  // All corners should be within image bounds
  for c in corners {
    assert_true(c.x >= 0 && c.x < 7)
    assert_true(c.y >= 0 && c.y < 7)
  }
}

///|
test "good_features_to_track: flat image has no corners" {
  let img = @types.Image::{
    width: 5,
    height: 5,
    channels: 1,
    data: Bytes::from_array(Array::make(25, b'\x80')),
  }
  let corners = good_features_to_track(img, 10, 0.01F)
  assert_eq(corners.length(), 0)
}

///|
test "good_features_to_track: respects max_corners" {
  // Create a pattern with multiple corners
  let data : Array[Byte] = Array::make(81, b'\x00')
  for y in 0..<9 {
    for x in 0..<9 {
      if (x / 3 + y / 3) % 2 == 0 {
        data[y * 9 + x] = b'\xFF'
      }
    }
  }
  let img = @types.Image::{
    width: 9,
    height: 9,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let corners = good_features_to_track(img, 3, 0.01F, min_distance=1)
  assert_true(corners.length() <= 3)
}

///|
test "good_features_to_track: quality_level filters weak corners" {
  let data : Array[Byte] = Array::make(49, b'\x00')
  for y in 2..<5 {
    for x in 2..<5 {
      data[y * 7 + x] = b'\xFF'
    }
  }
  let img = @types.Image::{
    width: 7,
    height: 7,
    channels: 1,
    data: Bytes::from_array(data),
  }
  // Very high quality level → few or no corners
  let strict = good_features_to_track(img, 10, 0.99F)
  // Very low quality level → more corners
  let loose = good_features_to_track(img, 10, 0.001F)
  assert_true(loose.length() >= strict.length())
}
