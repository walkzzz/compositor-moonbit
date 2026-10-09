// v24.0.0 图像风格迁移增强测试 - style_transfer 模块
// 颜色转移/纹理特征/卡通化/油画/素描/风格迁移流水线

///|
fn make_st_img(w : Int, h : Int, value : Byte) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(Array::make(w * h, value)),
  }
}

///|
fn make_varied_st_img(w : Int, h : Int) -> @types.Image {
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
test "create_default_style_transfer_config: 默认配置" {
  let config = create_default_style_transfer_config()
  assert_true(config.style_strength > 0.0)
  assert_true(config.content_strength > 0.0)
  assert_true(config.iterations > 0)
  assert_true(config.learning_rate > 0.0)
  assert_true(config.resolution > 0)
}

///|
test "calculate_color_statistics: 基本统计" {
  let img = make_varied_st_img(4, 4)
  let stats = calculate_color_statistics(img)
  assert_true(stats.mean_r >= 0.0)
  assert_true(stats.mean_g >= 0.0)
  assert_true(stats.mean_b >= 0.0)
  assert_true(stats.std_r >= 0.0)
}

///|
test "calculate_color_statistics: 常量图像" {
  let img = make_st_img(4, 4, b'\x80')
  let stats = calculate_color_statistics(img)
  assert_true(stats.std_r >= 0.0)
  assert_true(stats.std_r < 1.0)
}

///|
test "color_transfer: 基本颜色转移" {
  let content = make_varied_st_img(4, 4)
  let style = make_st_img(4, 4, b'\xFF')
  let result = color_transfer(content, style, 0.5)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "color_transfer: 零强度" {
  let content = make_varied_st_img(4, 4)
  let style = make_st_img(4, 4, b'\x80')
  let result = color_transfer(content, style, 0.0)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "calculate_texture_features: 基本纹理特征" {
  let img = make_varied_st_img(8, 8)
  let features = calculate_texture_features(img)
  assert_true(features.contrast >= 0.0)
  assert_true(features.homogeneity >= 0.0)
  assert_true(features.energy >= 0.0)
}

///|
test "calculate_texture_features: 常量图像" {
  let img = make_st_img(8, 8, b'\x80')
  let features = calculate_texture_features(img)
  assert_true(features.contrast >= 0.0)
}

///|
test "cartoonize: 基本卡通化" {
  let img = make_varied_st_img(8, 8)
  let result = cartoonize(img, 0.5)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "cartoonize: 零强度" {
  let img = make_varied_st_img(8, 8)
  let result = cartoonize(img, 0.0)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "oil_painting: 基本油画" {
  let img = make_varied_st_img(8, 8)
  let result = oil_painting(img, 2, 8)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "sketch_effect: 基本素描" {
  let img = make_varied_st_img(8, 8)
  let result = sketch_effect(img, 0.5)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "style_transfer: 颜色转移算法" {
  let content = make_varied_st_img(4, 4)
  let style = make_st_img(4, 4, b'\xFF')
  let config = create_default_style_transfer_config()
  let result = style_transfer(content, style, config)
  assert_eq(result.image.width, 4)
  assert_eq(result.image.height, 4)
  assert_true(result.algorithm == StyleTransferAlgorithm::ColorTransfer)
}

///|
test "style_transfer: 卡通算法" {
  let content = make_varied_st_img(4, 4)
  let style = make_st_img(4, 4, b'\x80')
  let config = StyleTransferConfig::{
    algorithm: StyleTransferAlgorithm::Cartoon,
    style_strength: 0.5,
    content_strength: 0.5,
    iterations: 100,
    learning_rate: 0.01,
    use_color_preservation: true,
    resolution: 512,
  }
  let result = style_transfer(content, style, config)
  assert_eq(result.image.width, 4)
  assert_eq(result.image.height, 4)
}

///|
test "style_transfer: 油画算法" {
  let content = make_varied_st_img(4, 4)
  let style = make_st_img(4, 4, b'\x80')
  let config = StyleTransferConfig::{
    algorithm: StyleTransferAlgorithm::OilPainting,
    style_strength: 0.5,
    content_strength: 0.5,
    iterations: 100,
    learning_rate: 0.01,
    use_color_preservation: true,
    resolution: 512,
  }
  let result = style_transfer(content, style, config)
  assert_eq(result.image.width, 4)
  assert_eq(result.image.height, 4)
}

///|
test "style_transfer_report_to_string: 生成报告" {
  let content = make_varied_st_img(4, 4)
  let style = make_st_img(4, 4, b'\xFF')
  let config = create_default_style_transfer_config()
  let result = style_transfer(content, style, config)
  let content_stats = calculate_color_statistics(content)
  let style_stats = calculate_color_statistics(style)
  let texture = calculate_texture_features(content)
  let report = style_transfer_report_to_string(
    result, content_stats, style_stats, texture,
  )
  assert_true(report.length() > 0)
  assert_true(report.contains("图像风格迁移报告"))
}
