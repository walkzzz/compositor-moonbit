// v24.0.0 图像风格迁移增强测试 - stylize 模块
// 油画/素描/水彩/卡通效果

///|
fn _make_stylize_img(w : Int, h : Int, value : Byte) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(Array::make(w * h, value)),
  }
}

///|
fn make_varied_stylize_img(w : Int, h : Int) -> @types.Image {
  let arr : Array[Byte] = []
  for i in 0..<(w * h) {
    arr.push((i % 256).to_byte())
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(arr),
  }
}

///|
test "stylize_default_config: 默认配置" {
  let config = stylize_default_config()
  assert_true(config.oil_paint_radius > 0)
  assert_true(config.oil_paint_intensity > 0)
  assert_true(config.sketch_blend > 0.0)
  assert_true(config.watercolor_blur > 0)
  assert_true(config.cartoon_levels > 0)
  assert_true(config.cartoon_edge_threshold > 0.0)
}

///|
test "oil_paint: 基本油画效果" {
  let img = make_varied_stylize_img(8, 8)
  let result = oil_paint(img)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.channels, 1)
}

///|
test "oil_paint: 自定义参数" {
  let img = make_varied_stylize_img(8, 8)
  let result = oil_paint(img, radius=2, intensity=10)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "sketch: 基本素描效果" {
  let img = make_varied_stylize_img(8, 8)
  let result = sketch(img)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "sketch: 自定义混合比例" {
  let img = make_varied_stylize_img(8, 8)
  let result = sketch(img, blend=0.5)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "watercolor: 基本水彩效果" {
  let img = make_varied_stylize_img(8, 8)
  let result = watercolor(img)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "watercolor: 自定义模糊半径" {
  let img = make_varied_stylize_img(8, 8)
  let result = watercolor(img, blur_radius=3)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "cartoon: 基本卡通效果" {
  let img = make_varied_stylize_img(8, 8)
  let result = cartoon(img)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "cartoon: 自定义参数" {
  let img = make_varied_stylize_img(8, 8)
  let result = cartoon(img, levels=4, edge_threshold=50.0)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "stylize: 油画风格" {
  let img = make_varied_stylize_img(8, 8)
  let result = stylize(img, "oil")
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "stylize: 素描风格" {
  let img = make_varied_stylize_img(8, 8)
  let result = stylize(img, "sketch")
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "stylize: 水彩风格" {
  let img = make_varied_stylize_img(8, 8)
  let result = stylize(img, "watercolor")
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "stylize: 卡通风格" {
  let img = make_varied_stylize_img(8, 8)
  let result = stylize(img, "cartoon")
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "stylize: 自定义配置" {
  let img = make_varied_stylize_img(8, 8)
  let config = stylize_default_config()
  let result = stylize(img, "oil", config~)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}
