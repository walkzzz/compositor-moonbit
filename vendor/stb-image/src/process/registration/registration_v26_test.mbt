// v26.0.0 图像融合与配准增强测试 - registration 模块
// 仿射变换/平移估计/图像对齐

///|
fn _make_reg_img(w : Int, h : Int, value : Byte) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(Array::make(w * h, value)),
  }
}

///|
fn make_varied_reg_img(w : Int, h : Int) -> @types.Image {
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
test "affine_identity: 恒等变换" {
  let t = affine_identity()
  assert_eq(t.a, 1.0)
  assert_eq(t.e, 1.0)
  assert_eq(t.b, 0.0)
  assert_eq(t.d, 0.0)
}

///|
test "affine_translation: 平移变换" {
  let t = affine_translation(10.0, 20.0)
  assert_eq(t.c, 10.0)
  assert_eq(t.f, 20.0)
}

///|
test "affine_rotation: 旋转变换" {
  let t = affine_rotation(0.5)
  assert_true(t.a > 0.0)
}

///|
test "affine_scale: 缩放变换" {
  let t = affine_scale(2.0, 3.0)
  assert_eq(t.a, 2.0)
  assert_eq(t.e, 3.0)
}

///|
test "affine_compose: 变换复合" {
  let t1 = affine_translation(10.0, 20.0)
  let t2 = affine_translation(5.0, 5.0)
  let t = affine_compose(t1, t2)
  assert_true(t.c > 0.0)
}

///|
test "affine_apply: 应用变换" {
  let t = affine_translation(10.0, 20.0)
  let (x, y) = affine_apply(t, 5.0, 5.0)
  assert_true(x > 0.0)
  assert_true(y > 0.0)
}

///|
test "estimate_translation: 基本平移估计" {
  let img1 = make_varied_reg_img(8, 8)
  let img2 = make_varied_reg_img(8, 8)
  let result = estimate_translation(img1, img2)
  assert_true(result.confidence >= 0.0)
}

///|
test "warp_affine_transform: 基本变换" {
  let img = make_varied_reg_img(8, 8)
  let t = affine_identity()
  let result = warp_affine_transform(img, t)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
}

///|
test "align_images: 基本对齐" {
  let img1 = make_varied_reg_img(8, 8)
  let img2 = make_varied_reg_img(8, 8)
  let (aligned, result) = align_images(img1, img2)
  assert_eq(aligned.width, 8)
  assert_eq(aligned.height, 8)
  assert_true(result.confidence >= 0.0)
}
