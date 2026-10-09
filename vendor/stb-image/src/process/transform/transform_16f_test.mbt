// transform 16-bit/float 变体测试

///|
fn make_image16(w : Int, h : Int, ch : Int) -> @types.Image16 {
  let data : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<ch {
        let val = (x + y + c) % 256
        let offset = ((y * w + x) * ch + c) * 2
        data[offset] = val.to_byte()
        data[offset + 1] = b'\x00'
      }
    }
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
}

///|
fn make_imagef(w : Int, h : Int, ch : Int) -> @types.ImageF {
  let data : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<ch {
        let val = Float::from_int((x + y + c) % 256) / 255.0F
        let offset = ((y * w + x) * ch + c) * 4
        let bits = val.reinterpret_as_int()
        data[offset] = (bits & 0xFF).to_byte()
        data[offset + 1] = ((bits >> 8) & 0xFF).to_byte()
        data[offset + 2] = ((bits >> 16) & 0xFF).to_byte()
        data[offset + 3] = ((bits >> 24) & 0xFF).to_byte()
      }
    }
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
}

///|
test "rotate_90_16: swaps width and height" {
  let img = make_image16(4, 3, 3)
  let result = rotate_90_16(img)
  assert_eq(result.width, 3)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "rotate_90_f: swaps width and height" {
  let img = make_imagef(4, 3, 3)
  let result = rotate_90_f(img)
  assert_eq(result.width, 3)
  assert_eq(result.height, 4)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = result
}

///|
test "rotate_180_16: preserves dimensions" {
  let img = make_image16(4, 3, 2)
  let result = rotate_180_16(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 3)
  assert_eq(result.channels, 2)
  let _ = img
  let _ = result
}

///|
test "rotate_180_f: preserves dimensions" {
  let img = make_imagef(4, 3, 2)
  let result = rotate_180_f(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 3)
  assert_eq(result.channels, 2)
  let _ = img
  let _ = result
}

///|
test "rotate_270_16: swaps width and height" {
  let img = make_image16(4, 3, 1)
  let result = rotate_270_16(img)
  assert_eq(result.width, 3)
  assert_eq(result.height, 4)
  let _ = img
  let _ = result
}

///|
test "rotate_270_f: swaps width and height" {
  let img = make_imagef(4, 3, 1)
  let result = rotate_270_f(img)
  assert_eq(result.width, 3)
  assert_eq(result.height, 4)
  let _ = img
  let _ = result
}

///|
test "flip_horizontal_16: preserves dimensions" {
  let img = make_image16(4, 3, 3)
  let result = flip_horizontal_16(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 3)
  let _ = img
  let _ = result
}

///|
test "flip_horizontal_f: preserves dimensions" {
  let img = make_imagef(4, 3, 3)
  let result = flip_horizontal_f(img)
  assert_eq(result.width, 4)
  assert_eq(result.height, 3)
  let _ = img
  let _ = result
}

///|
test "rotate_90_16: 4 rotations return to original" {
  let img = make_image16(3, 2, 3)
  let r1 = rotate_90_16(img)
  let r2 = rotate_90_16(r1)
  let r3 = rotate_90_16(r2)
  let r4 = rotate_90_16(r3)
  assert_eq(r4.width, img.width)
  assert_eq(r4.height, img.height)
  assert_eq(r4, img)
  let _ = img
  let _ = r1
  let _ = r2
  let _ = r3
  let _ = r4
}

///|
test "rotate_90_f: 4 rotations return to original" {
  let img = make_imagef(3, 2, 3)
  let r1 = rotate_90_f(img)
  let r2 = rotate_90_f(r1)
  let r3 = rotate_90_f(r2)
  let r4 = rotate_90_f(r3)
  assert_eq(r4.width, img.width)
  assert_eq(r4.height, img.height)
  assert_eq(r4, img)
  let _ = img
  let _ = r1
  let _ = r2
  let _ = r3
  let _ = r4
}

///|
test "flip_horizontal_16: double flip is identity" {
  let img = make_image16(4, 3, 3)
  let r1 = flip_horizontal_16(img)
  let r2 = flip_horizontal_16(r1)
  assert_eq(r2, img)
  let _ = img
  let _ = r1
  let _ = r2
}

///|
test "flip_horizontal_f: double flip is identity" {
  let img = make_imagef(4, 3, 3)
  let r1 = flip_horizontal_f(img)
  let r2 = flip_horizontal_f(r1)
  assert_eq(r2, img)
  let _ = img
  let _ = r1
  let _ = r2
}

///|
test "flip_vertical_16: double flip is identity" {
  let img = make_image16(4, 3, 3)
  let r1 = flip_vertical_16(img)
  let r2 = flip_vertical_16(r1)
  assert_eq(r2, img)
  let _ = img
  let _ = r1
  let _ = r2
}

///|
test "flip_vertical_f: double flip is identity" {
  let img = make_imagef(4, 3, 3)
  let r1 = flip_vertical_f(img)
  let r2 = flip_vertical_f(r1)
  assert_eq(r2, img)
  let _ = img
  let _ = r1
  let _ = r2
}

///|
test "transpose_16: swaps width and height" {
  let img = make_image16(4, 3, 3)
  let r = transpose_16(img)
  assert_eq(r.width, 3)
  assert_eq(r.height, 4)
  assert_eq(r.channels, 3)
  let _ = img
  let _ = r
}

///|
test "transpose_16: double transpose is identity" {
  let img = make_image16(4, 3, 3)
  let r1 = transpose_16(img)
  let r2 = transpose_16(r1)
  assert_eq(r2, img)
  let _ = img
  let _ = r1
  let _ = r2
}

///|
test "transpose_f: swaps width and height" {
  let img = make_imagef(4, 3, 3)
  let r = transpose_f(img)
  assert_eq(r.width, 3)
  assert_eq(r.height, 4)
  assert_eq(r.channels, 3)
  let _ = img
  let _ = r
}

///|
test "transpose_f: double transpose is identity" {
  let img = make_imagef(4, 3, 3)
  let r1 = transpose_f(img)
  let r2 = transpose_f(r1)
  assert_eq(r2, img)
  let _ = img
  let _ = r1
  let _ = r2
}
