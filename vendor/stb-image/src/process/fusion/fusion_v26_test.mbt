// v26.0.0 图像融合与配准增强测试 - fusion 模块
// Alpha融合/多焦点融合/曝光融合

///|
fn make_fusion_img(w : Int, h : Int, value : Byte) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(Array::make(w * h, value)),
  }
}

///|
fn make_varied_fusion_img(w : Int, h : Int) -> @types.Image {
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
test "fusion_default_config: 默认配置" {
  let config = fusion_default_config()
  assert_true(config.alpha > 0.0)
  assert_true(config.pyramid_levels > 0)
}

///|
test "fuse_alpha: 基本Alpha融合" {
  let img1 = make_varied_fusion_img(4, 4)
  let img2 = make_fusion_img(4, 4, b'\x80')
  let result = fuse_alpha(img1, img2)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "fuse_alpha: 自定义alpha" {
  let img1 = make_varied_fusion_img(4, 4)
  let img2 = make_fusion_img(4, 4, b'\x80')
  let result = fuse_alpha(img1, img2, alpha=0.3)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "fuse_multifocus: 基本多焦点融合" {
  let img1 = make_varied_fusion_img(4, 4)
  let img2 = make_fusion_img(4, 4, b'\x80')
  let result = fuse_multifocus(img1, img2)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "fuse_exposure: 基本曝光融合" {
  let img1 = make_varied_fusion_img(4, 4)
  let img2 = make_fusion_img(4, 4, b'\x40')
  let img3 = make_fusion_img(4, 4, b'\xC0')
  let result = fuse_exposure([img1, img2, img3])
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "fuse_images: 默认配置" {
  let img1 = make_varied_fusion_img(4, 4)
  let img2 = make_fusion_img(4, 4, b'\x80')
  let result = fuse_images(img1, img2)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}

///|
test "fuse_images: 多焦点方法" {
  let img1 = make_varied_fusion_img(4, 4)
  let img2 = make_fusion_img(4, 4, b'\x80')
  let config = FusionConfig::{
    method_type: "multifocus",
    alpha: 0.5,
    pyramid_levels: 3,
  }
  let result = fuse_images(img1, img2, config~)
  assert_eq(result.width, 4)
  assert_eq(result.height, 4)
}
