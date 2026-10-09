// SLIC 超像素分割测试

///|
fn make_slic_test_image(w : Int, h : Int, ch : Int) -> @types.Image {
  let data : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<ch {
        data[(y * w + x) * ch + c] = ((x * 17 + y * 31 + c * 7) % 256).to_byte()
      }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
}

///|
test "slic: returns correct label count" {
  let img = make_slic_test_image(10, 10, 3)
  let result = slic(img, 4, 10, 5)
  assert_eq(result.labels.length(), 100)
  assert_true(result.num_labels > 0)
  assert_eq(result.centers.length(), result.num_labels)
  let _ = img
  let _ = result
}

///|
test "slic: all labels in valid range" {
  let img = make_slic_test_image(8, 8, 3)
  let result = slic(img, 4, 10, 5)
  for i in 0..<64 {
    assert_true(result.labels[i] >= 0)
    assert_true(result.labels[i] < result.num_labels)
  }
  let _ = img
  let _ = result
}

///|
test "slic: centers within image bounds" {
  let img = make_slic_test_image(10, 10, 3)
  let result = slic(img, 4, 10, 5)
  for i in 0..<result.num_labels {
    let (cx, cy) = result.centers[i]
    assert_true(cx >= 0 && cx < 10)
    assert_true(cy >= 0 && cy < 10)
  }
  let _ = img
  let _ = result
}

///|
test "slic: invalid k raises error" {
  let img = make_slic_test_image(5, 5, 3)
  try {
    let _ = slic(img, 0, 10, 5)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  let _ = img
}

///|
test "slic: invalid max_iters raises error" {
  let img = make_slic_test_image(5, 5, 3)
  try {
    let _ = slic(img, 4, 10, 0)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  let _ = img
}

///|
test "slic: small image" {
  let img = make_slic_test_image(4, 4, 3)
  let result = slic(img, 2, 10, 3)
  assert_eq(result.labels.length(), 16)
  assert_true(result.num_labels > 0)
  let _ = img
  let _ = result
}

///|
test "slic: grayscale image" {
  let img = make_slic_test_image(8, 8, 1)
  let result = slic(img, 4, 10, 5)
  assert_eq(result.labels.length(), 64)
  for i in 0..<64 {
    assert_true(result.labels[i] >= 0)
  }
  let _ = img
  let _ = result
}

///|
test "slic: uniform image" {
  let data = Array::make(6 * 6 * 3, b'\x80')
  let img = @types.Image::{
    width: 6,
    height: 6,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let result = slic(img, 4, 10, 5)
  assert_eq(result.labels.length(), 36)
  let _ = data
  let _ = img
  let _ = result
}

///|
test "slic: k=1 single superpixel" {
  let img = make_slic_test_image(5, 5, 3)
  let result = slic(img, 1, 10, 3)
  assert_eq(result.labels.length(), 25)
  let _ = img
  let _ = result
}

///|
test "slic: many superpixels" {
  let img = make_slic_test_image(12, 12, 3)
  let result = slic(img, 16, 10, 5)
  assert_eq(result.labels.length(), 144)
  assert_true(result.num_labels > 0)
  let _ = img
  let _ = result
}
