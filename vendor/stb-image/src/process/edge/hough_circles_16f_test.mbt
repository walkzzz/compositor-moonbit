// hough_circles 16-bit/float 测试

///|
test "hough_circles_16 basic" {
  let w = 32
  let h = 32
  let ch = 1
  let data : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  let img = @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
  let circles = @edge.hough_circles_16(img, param2=100)
  assert_eq(circles.length(), 0)
}

///|
test "hough_circles_f basic" {
  let w = 32
  let h = 32
  let ch = 1
  let data : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  let img = @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
  let circles = @edge.hough_circles_f(img, param2=100)
  assert_eq(circles.length(), 0)
}

///|
test "hough_circles_16 rgb" {
  let w = 32
  let h = 32
  let ch = 3
  let data : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  let img = @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
  let circles = @edge.hough_circles_16(img, param2=100)
  assert_eq(circles.length(), 0)
}

///|
test "hough_circles_f rgb" {
  let w = 32
  let h = 32
  let ch = 3
  let data : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  let img = @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
  let circles = @edge.hough_circles_f(img, param2=100)
  assert_eq(circles.length(), 0)
}
