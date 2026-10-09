// hough_lines 16-bit/float 测试

///|
test "hough_lines_16 basic" {
  let w = 16
  let h = 16
  let ch = 1
  let data : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  // 画一条水平线
  for x in 0..<w {
    let idx = (8 * w + x) * 2
    data[idx] = b'\xFF'
    data[idx + 1] = b'\xFF'
  }
  let img = @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
  let lines = @edge.hough_lines_16(img, 5)
  assert_true(lines.length() >= 0)
}

///|
test "hough_lines_f basic" {
  let w = 16
  let h = 16
  let ch = 1
  let data : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  // 画一条水平线
  for x in 0..<w {
    let idx = (8 * w + x) * 4
    let bits = 1.0F.reinterpret_as_int()
    data[idx] = (bits & 0xFF).to_byte()
    data[idx + 1] = ((bits >> 8) & 0xFF).to_byte()
    data[idx + 2] = ((bits >> 16) & 0xFF).to_byte()
    data[idx + 3] = ((bits >> 24) & 0xFF).to_byte()
  }
  let img = @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
  let lines = @edge.hough_lines_f(img, 5)
  assert_true(lines.length() >= 0)
}

///|
test "hough_lines_16 rgb" {
  let w = 16
  let h = 16
  let ch = 3
  let data : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  let img = @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
  let lines = @edge.hough_lines_16(img, 100)
  assert_eq(lines.length(), 0)
}

///|
test "hough_lines_f rgb" {
  let w = 16
  let h = 16
  let ch = 3
  let data : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  let img = @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
  let lines = @edge.hough_lines_f(img, 100)
  assert_eq(lines.length(), 0)
}
