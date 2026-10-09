///|
fn tm_make_imagef(
  width : Int,
  height : Int,
  pixels : Array[(Float, Float, Float)],
) -> @types.ImageF {
  let data : Array[Byte] = []
  for p in pixels {
    let rb = p.0.to_le_bytes()
    let gb = p.1.to_le_bytes()
    let bb = p.2.to_le_bytes()
    for i in 0..<4 {
      data.push(rb[i])
    }
    for i in 0..<4 {
      data.push(gb[i])
    }
    for i in 0..<4 {
      data.push(bb[i])
    }
  }
  @types.ImageF::{ width, height, channels: 3, data: Bytes::from_array(data) }
}

///|
test "reinhard_tonemap: produces 8-bit image" {
  let imgf = tm_make_imagef(2, 1, [(0.0F, 0.5F, 1.0F), (2.0F, 4.0F, 8.0F)])
  let result = reinhard_tonemap(imgf)
  assert_eq(result.channels, 3)
  assert_eq(result.width, 2)
  assert_eq(result.height, 1)
  // All values should be in [0, 255]
  for i in 0..<6 {
    assert_true(result.data[i].to_int() >= 0)
    assert_true(result.data[i].to_int() <= 255)
  }
}

///|
test "reinhard_tonemap: zero input produces zero output" {
  let imgf = tm_make_imagef(1, 1, [(0.0F, 0.0F, 0.0F)])
  let result = reinhard_tonemap(imgf)
  assert_eq(result.data[0].to_int(), 0)
  assert_eq(result.data[1].to_int(), 0)
  assert_eq(result.data[2].to_int(), 0)
}

///|
test "gamma_tonemap: gamma=1 is linear normalization" {
  let imgf = tm_make_imagef(1, 1, [(0.0F, 0.5F, 1.0F)])
  let result = gamma_tonemap(imgf, 1.0F)
  // With gamma=1: 0→0, 0.5→128, 1.0→255
  assert_eq(result.data[0].to_int(), 0)
  assert_true((result.data[1].to_int() - 128).abs() <= 1)
  assert_eq(result.data[2].to_int(), 255)
}

///|
test "gamma_tonemap: gamma=2 brightens dark areas" {
  let imgf = tm_make_imagef(1, 1, [(0.0F, 0.25F, 1.0F)])
  let result = gamma_tonemap(imgf, 2.0F)
  // With gamma=2: 0.25^0.5 = 0.5 → ~128
  assert_eq(result.data[0].to_int(), 0)
  assert_true(result.data[1].to_int() > 60)
  assert_eq(result.data[2].to_int(), 255)
}

///|
test "gamma_tonemap: all-zero input" {
  let imgf = tm_make_imagef(1, 1, [(0.0F, 0.0F, 0.0F)])
  let result = gamma_tonemap(imgf, 2.2F)
  assert_eq(result.data[0].to_int(), 0)
  assert_eq(result.data[1].to_int(), 0)
  assert_eq(result.data[2].to_int(), 0)
}

///|
fn tm_make_imagef_rgba(
  width : Int,
  height : Int,
  pixels : Array[(Float, Float, Float, Float)],
) -> @types.ImageF {
  let data : Array[Byte] = []
  for p in pixels {
    let rb = p.0.to_le_bytes()
    let gb = p.1.to_le_bytes()
    let bb = p.2.to_le_bytes()
    let ab = p.3.to_le_bytes()
    for i in 0..<4 {
      data.push(rb[i])
    }
    for i in 0..<4 {
      data.push(gb[i])
    }
    for i in 0..<4 {
      data.push(bb[i])
    }
    for i in 0..<4 {
      data.push(ab[i])
    }
  }
  @types.ImageF::{ width, height, channels: 4, data: Bytes::from_array(data) }
}

///|
test "reinhard_tonemap: RGBA alpha set to 255" {
  let imgf = tm_make_imagef_rgba(1, 1, [(0.5F, 0.5F, 0.5F, 0.3F)])
  let result = reinhard_tonemap(imgf)
  assert_eq(result.channels, 4)
  assert_eq(result.data[3].to_int(), 255)
}

///|
test "gamma_tonemap: RGBA alpha set to 255" {
  let imgf = tm_make_imagef_rgba(1, 1, [(0.5F, 0.5F, 0.5F, 0.3F)])
  let result = gamma_tonemap(imgf, 2.2F)
  assert_eq(result.channels, 4)
  assert_eq(result.data[3].to_int(), 255)
}
