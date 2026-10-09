// 示例 13-14：形态学操作
// 演示腐蚀、膨胀、开闭运算、自定义结构元素

///|
test "example_13: basic morphology operations (erode, dilate, open, close)" {
  // 构造二值图像：中心白色块
  let img = make_gray_image(8, 8, [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 0,
    0, 0, 0, 255, 255, 255, 255, 0, 0, 0, 0, 255, 255, 255, 255, 0, 0, 0, 0, 255,
    255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  ])
  // 腐蚀：白色区域缩小
  let eroded = @img.erode(img)
  assert_eq(eroded.width, 8)
  // 膨胀：白色区域扩大
  let dilated = @img.dilate(img)
  assert_eq(dilated.width, 8)
  // 开运算 = 腐蚀后膨胀（去小噪点）
  let opened = @img.morph_open(img)
  assert_eq(opened.width, 8)
  // 闭运算 = 膨胀后腐蚀（填小孔）
  let closed = @img.morph_close(img)
  assert_eq(closed.width, 8)
  // 形态学梯度 = 膨胀 - 腐蚀（边缘）
  let gradient = @img.morph_gradient(img)
  assert_eq(gradient.width, 8)
  // 顶帽变换
  let tophat = @img.morph_tophat(img)
  assert_eq(tophat.width, 8)
  // 黑帽变换
  let blackhat = @img.morph_blackhat(img)
  assert_eq(blackhat.width, 8)
  // 骨架化
  let skeleton = @img.skeletonize(img)
  assert_eq(skeleton.width, 8)
}

///|
test "example_14: morphology with custom structuring elements" {
  let img = make_gray_image(8, 8, [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 255, 255, 0, 0, 255, 255, 255,
    255, 255, 255, 0, 0, 255, 255, 255, 255, 255, 255, 0, 0, 255, 255, 255, 255,
    255, 255, 0, 0, 255, 255, 255, 255, 255, 255, 0, 0, 255, 255, 255, 255, 255,
    255, 0, 0, 255, 255, 255, 255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  ])
  // 矩形结构元素 3x3
  let se_r = @img.se_rect(3, 3)
  let eroded_r = @img.erode_custom(img, se_r)
  assert_eq(eroded_r.width, 8)
  // 十字形结构元素
  let se_c = @img.se_cross(3)
  let dilated_c = @img.dilate_custom(img, se_c)
  assert_eq(dilated_c.width, 8)
  // 椭圆结构元素
  let se_e = @img.se_ellipse(3)
  let opened_e = @img.morph_open_custom(img, se_e)
  assert_eq(opened_e.width, 8)
  let closed_e = @img.morph_close_custom(img, se_e)
  assert_eq(closed_e.width, 8)
}
