// 绘制函数 16-bit/float 变体测试

///|
fn make_img16_draw(w : Int, h : Int, ch : Int, val : Int) -> @types.Image16 {
  let data : Array[Byte] = Array::make(w * h * ch * 2, b'\x00')
  for i in 0..<(w * h * ch) {
    data[i * 2] = (val & 0xFF).to_byte()
    data[i * 2 + 1] = ((val >> 8) & 0xFF).to_byte()
  }
  @types.Image16::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
}

///|
fn make_imgf_draw(w : Int, h : Int, ch : Int, val : Float) -> @types.ImageF {
  let data : Array[Byte] = Array::make(w * h * ch * 4, b'\x00')
  for i in 0..<(w * h * ch) {
    let bits = val.reinterpret_as_int()
    data[i * 4] = (bits & 0xFF).to_byte()
    data[i * 4 + 1] = ((bits >> 8) & 0xFF).to_byte()
    data[i * 4 + 2] = ((bits >> 16) & 0xFF).to_byte()
    data[i * 4 + 3] = ((bits >> 24) & 0xFF).to_byte()
  }
  @types.ImageF::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(data),
  }
}

// ========== 16-bit 绘制测试 ==========

///|
test "draw_line_16: basic line" {
  let img = make_img16_draw(10, 10, 1, 0)
  let color : Array[Int] = [65535]
  let result = draw_line_16(img, 0, 0, 9, 9, color)
  assert_eq(result.width, 10)
  assert_eq(result.height, 10)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = color
  let _ = result
}

///|
test "draw_rectangle_16: basic rectangle" {
  let img = make_img16_draw(10, 10, 1, 0)
  let color : Array[Int] = [65535]
  let result = draw_rectangle_16(img, 2, 2, 5, 5, color)
  assert_eq(result.width, 10)
  assert_eq(result.height, 10)
  let _ = img
  let _ = color
  let _ = result
}

///|
test "draw_rectangle_16: filled rectangle" {
  let img = make_img16_draw(10, 10, 1, 0)
  let color : Array[Int] = [65535]
  let result = draw_rectangle_16(img, 2, 2, 5, 5, color, fill=true)
  assert_eq(result.width, 10)
  let _ = img
  let _ = color
  let _ = result
}

///|
test "draw_circle_16: basic circle" {
  let img = make_img16_draw(10, 10, 1, 0)
  let color : Array[Int] = [65535]
  let result = draw_circle_16(img, 5, 5, 3, color)
  assert_eq(result.width, 10)
  assert_eq(result.height, 10)
  let _ = img
  let _ = color
  let _ = result
}

///|
test "draw_circle_16: filled circle" {
  let img = make_img16_draw(10, 10, 1, 0)
  let color : Array[Int] = [65535]
  let result = draw_circle_16(img, 5, 5, 3, color, fill=true)
  assert_eq(result.width, 10)
  let _ = img
  let _ = color
  let _ = result
}

///|
test "draw_polygon_16: basic polygon" {
  let img = make_img16_draw(10, 10, 1, 0)
  let color : Array[Int] = [65535]
  let points : Array[(Int, Int)] = [(2, 2), (7, 2), (5, 7)]
  let result = draw_polygon_16(img, points, color)
  assert_eq(result.width, 10)
  let _ = img
  let _ = color
  let _ = points
  let _ = result
}

///|
test "draw_line_16: RGB color" {
  let img = make_img16_draw(10, 10, 3, 0)
  let color : Array[Int] = [65535, 0, 0]
  let result = draw_line_16(img, 0, 0, 9, 9, color)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = color
  let _ = result
}

// ========== float 绘制测试 ==========

///|
test "draw_line_f: basic line" {
  let img = make_imgf_draw(10, 10, 1, 0.0F)
  let color : Array[Float] = [1.0F]
  let result = draw_line_f(img, 0, 0, 9, 9, color)
  assert_eq(result.width, 10)
  assert_eq(result.height, 10)
  assert_eq(result.channels, 1)
  let _ = img
  let _ = color
  let _ = result
}

///|
test "draw_rectangle_f: basic rectangle" {
  let img = make_imgf_draw(10, 10, 1, 0.0F)
  let color : Array[Float] = [1.0F]
  let result = draw_rectangle_f(img, 2, 2, 5, 5, color)
  assert_eq(result.width, 10)
  let _ = img
  let _ = color
  let _ = result
}

///|
test "draw_circle_f: basic circle" {
  let img = make_imgf_draw(10, 10, 1, 0.0F)
  let color : Array[Float] = [1.0F]
  let result = draw_circle_f(img, 5, 5, 3, color)
  assert_eq(result.width, 10)
  let _ = img
  let _ = color
  let _ = result
}

///|
test "draw_polygon_f: basic polygon" {
  let img = make_imgf_draw(10, 10, 1, 0.0F)
  let color : Array[Float] = [1.0F]
  let points : Array[(Int, Int)] = [(2, 2), (7, 2), (5, 7)]
  let result = draw_polygon_f(img, points, color)
  assert_eq(result.width, 10)
  let _ = img
  let _ = color
  let _ = points
  let _ = result
}

///|
test "draw_line_f: RGB color" {
  let img = make_imgf_draw(10, 10, 3, 0.0F)
  let color : Array[Float] = [1.0F, 0.0F, 0.0F]
  let result = draw_line_f(img, 0, 0, 9, 9, color)
  assert_eq(result.channels, 3)
  let _ = img
  let _ = color
  let _ = result
}
