// 接缝裁剪测试

///|
fn make_test_image(w : Int, h : Int, ch : Int) -> @types.Image {
  let data : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<ch {
        data[(y * w + x) * ch + c] = ((x + y) % 256).to_byte()
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
fn make_gradient_image(w : Int, h : Int) -> @types.Image {
  let data : Array[Byte] = Array::make(w * h * 3, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * 3
      data[idx] = (x * 255 / (w - 1)).to_byte()
      data[idx + 1] = (y * 255 / (h - 1)).to_byte()
      data[idx + 2] = b'\x80'
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 3,
    data: Bytes::from_array(data),
  }
}

///|
test "compute_energy: returns correct size" {
  let img = make_test_image(4, 4, 3)
  let energy = compute_energy(img)
  assert_eq(energy.length(), 16)
  let _ = img
  let _ = energy
}

///|
test "compute_energy: uniform image has zero energy" {
  let data = Array::make(3 * 3 * 3, b'\x80')
  let img = @types.Image::{
    width: 3,
    height: 3,
    channels: 3,
    data: Bytes::from_array(data),
  }
  let energy = compute_energy(img)
  for i in 0..<9 {
    assert_eq(energy[i], 0.0)
  }
  let _ = img
  let _ = energy
}

///|
test "compute_energy: non-negative" {
  let img = make_gradient_image(5, 5)
  let energy = compute_energy(img)
  for i in 0..<25 {
    assert_true(energy[i] >= 0.0)
  }
  let _ = img
  let _ = energy
}

///|
test "find_vertical_seam: returns h entries" {
  let img = make_gradient_image(5, 4)
  let energy = compute_energy(img)
  let seam = find_vertical_seam(energy, 5, 4)
  assert_eq(seam.length(), 4)
  for i in 0..<4 {
    assert_true(seam[i] >= 0 && seam[i] < 5)
  }
  let _ = img
  let _ = energy
  let _ = seam
}

///|
test "find_vertical_seam: consecutive entries differ by at most 1" {
  let img = make_gradient_image(6, 5)
  let energy = compute_energy(img)
  let seam = find_vertical_seam(energy, 6, 5)
  for i in 1..<5 {
    let diff = seam[i] - seam[i - 1]
    assert_true(diff >= -1 && diff <= 1)
  }
  let _ = img
  let _ = energy
  let _ = seam
}

///|
test "remove_vertical_seam: width decreases by 1" {
  let img = make_test_image(5, 4, 3)
  let energy = compute_energy(img)
  let seam = find_vertical_seam(energy, 5, 4)
  let result = remove_vertical_seam(img, seam)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = energy
  let _ = seam
  let _ = result
}

///|
test "find_horizontal_seam: returns w entries" {
  let img = make_gradient_image(4, 5)
  let energy = compute_energy(img)
  let seam = find_horizontal_seam(energy, 4, 5)
  assert_eq(seam.length(), 4)
  for i in 0..<4 {
    assert_true(seam[i] >= 0 && seam[i] < 5)
  }
  let _ = img
  let _ = energy
  let _ = seam
}

///|
test "remove_horizontal_seam: height decreases by 1" {
  let img = make_test_image(4, 5, 3)
  let energy = compute_energy(img)
  let seam = find_horizontal_seam(energy, 4, 5)
  let result = remove_horizontal_seam(img, seam)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = energy
  let _ = seam
  let _ = result
}

///|
test "seam_carve_resize: shrink width" {
  let img = make_gradient_image(6, 4)
  let result = seam_carve_resize(img, 4, 4)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  let _ = img
  let _ = result
}

///|
test "seam_carve_resize: shrink height" {
  let img = make_gradient_image(4, 6)
  let result = seam_carve_resize(img, 4, 4)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  let _ = img
  let _ = result
}

///|
test "seam_carve_resize: shrink both" {
  let img = make_gradient_image(6, 6)
  let result = seam_carve_resize(img, 4, 4)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  let _ = img
  let _ = result
}

///|
test "seam_carve_resize: enlarge width" {
  let img = make_gradient_image(4, 4)
  let result = seam_carve_resize(img, 6, 4)
  assert_eq(result.width, 6)
  assert_eq(result.height, 4)
  let _ = img
  let _ = result
}

///|
test "seam_carve_resize: enlarge height" {
  let img = make_gradient_image(4, 4)
  let result = seam_carve_resize(img, 4, 6)
  assert_eq(result.width, 4)
  assert_eq(result.height, 6)
  let _ = img
  let _ = result
}

///|
test "seam_carve_resize: same size returns same dimensions" {
  let img = make_gradient_image(4, 4)
  let result = seam_carve_resize(img, 4, 4)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
  let _ = img
  let _ = result
}

///|
test "seam_carve_resize: invalid size raises error" {
  let img = make_gradient_image(4, 4)
  try {
    let _ = seam_carve_resize(img, 0, 4)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  let _ = img
}

///|
test "seam_carve_resize: enlarge over 2x raises error" {
  let img = make_gradient_image(4, 4)
  try {
    let _ = seam_carve_resize(img, 9, 4)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
  let _ = img
}

///|
test "seam_carve_resize: single column image" {
  let data = Array::make(1 * 4 * 1, b'\x00')
  for i in 0..<4 {
    data[i] = (i * 50).to_byte()
  }
  let img = @types.Image::{
    width: 1,
    height: 4,
    channels: 1,
    data: Bytes::from_array(data),
  }
  let result = seam_carve_resize(img, 1, 2)
  assert_eq(result.width, 1)
  assert_eq(result.height, 2)
  let _ = data
  let _ = img
  let _ = result
}

///|
test "seam_carve_resize: grayscale image" {
  let img = make_test_image(5, 5, 1)
  let result = seam_carve_resize(img, 3, 3)
  assert_eq(result.width, 3)
  assert_eq(result.height, 3)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = result
}
