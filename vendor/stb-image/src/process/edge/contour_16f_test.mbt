// contour 16-bit/float 测试

///|
test "find_contours_16 basic" {
  let w = 16
  let h = 16
  let ch = 1
  let data : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  // 画一个白色方块
  for y in 4..<12 {
    for x in 4..<12 {
      let idx = (y * w + x) * 2
      data[idx] = b'\xFF'
      data[idx + 1] = b'\xFF'
    }
  }
  let img = @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
  let contours = @edge.find_contours_16(img)
  assert_true(contours.length() >= 1)
}

///|
test "find_contours_f basic" {
  let w = 16
  let h = 16
  let ch = 1
  let data : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  // 画一个白色方块
  for y in 4..<12 {
    for x in 4..<12 {
      let idx = (y * w + x) * 4
      let bits = 1.0F.reinterpret_as_int()
      data[idx] = (bits & 0xFF).to_byte()
      data[idx + 1] = ((bits >> 8) & 0xFF).to_byte()
      data[idx + 2] = ((bits >> 16) & 0xFF).to_byte()
      data[idx + 3] = ((bits >> 24) & 0xFF).to_byte()
    }
  }
  let img = @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
  let contours = @edge.find_contours_f(img)
  assert_true(contours.length() >= 1)
}

///|
test "draw_contours_16 basic" {
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
  let contours : Array[@edge.Contour] = []
  let color : Array[Int] = [65535, 0, 0]
  let out = @edge.draw_contours_16(img, contours, color)
  assert_eq(out.width, w)
  assert_eq(out.height, h)
  assert_eq(out.channels, ch)
}

///|
test "draw_contours_f basic" {
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
  let contours : Array[@edge.Contour] = []
  let color : Array[Float] = [1.0F, 0.0F, 0.0F]
  let out = @edge.draw_contours_f(img, contours, color)
  assert_eq(out.width, w)
  assert_eq(out.height, h)
  assert_eq(out.channels, ch)
}
