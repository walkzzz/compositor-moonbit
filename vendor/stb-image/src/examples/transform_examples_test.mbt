// 示例 4-6：几何变换
// 演示缩放、裁剪、旋转、翻转

///|
test "example_04: resize image with different filters" {
  let img = @img.load_from_bytes(test_4x4_red_png, req_channels=Some(3))
  // 使用默认滤波器缩放
  let resized_default = @img.resize(img, 8, 8)
  assert_eq(resized_default.width, 8)
  assert_eq(resized_default.height, 8)
  // 使用双线性滤波
  let resized_bilinear = @img.resize(
    img,
    8,
    8,
    filter=@types.ResizeFilter::Triangle,
  )
  assert_eq(resized_bilinear.width, 8)
  // 缩小
  let shrunk = @img.resize(img, 2, 2)
  assert_eq(shrunk.width, 2)
  assert_eq(shrunk.height, 2)
  // resize_to_contain: 保持宽高比缩放到指定框内
  let contained = @img.resize_to_contain(img, 10, 6, [b'\x00', b'\x00', b'\x00'])
  assert_true(contained.width <= 10 && contained.height <= 6)
  // resize_to_cover: 覆盖指定尺寸
  let covered = @img.resize_to_cover(img, 10, 6)
  assert_true(covered.width >= 10 || covered.height >= 6)
}

///|
test "example_05: crop and rotate image" {
  let img = make_gradient_image(8, 8)
  // 裁剪中心 4x4 区域
  let cropped = @img.crop(img, 2, 2, 4, 4)
  assert_eq(cropped.width, 4)
  assert_eq(cropped.height, 4)
  // 旋转 90 度：8x8 -> 8x8（正方形不变）
  let r90 = @img.rotate_90(img)
  assert_eq(r90.width, 8)
  assert_eq(r90.height, 8)
  // 非正方形：4x8 -> 8x4
  let non_square = @img.crop(img, 0, 0, 4, 8)
  let rotated = @img.rotate_90(non_square)
  assert_eq(rotated.width, 8)
  assert_eq(rotated.height, 4)
  // 旋转 180 度
  let r180 = @img.rotate_180(img)
  assert_eq(r180.width, 8)
  assert_eq(r180.height, 8)
  // 旋转 270 度
  let r270 = @img.rotate_270(img)
  assert_eq(r270.width, 8)
  assert_eq(r270.height, 8)
  // 任意角度旋转
  let r45 = @img.rotate(img, 45.0)
  assert_true(r45.width > 0 && r45.height > 0)
}

///|
test "example_06: flip horizontal and vertical" {
  // 构造非对称图像：左侧暗、右侧亮
  let img = make_gray_image(4, 2, [0, 50, 200, 255, 0, 50, 200, 255])
  // 水平翻转：左右互换
  let flipped_h = @img.flip_horizontal(img)
  // 原图 (0,0)=0，翻转后 (0,0) 应为原图 (3,0)=255
  assert_eq(flipped_h.data[0].to_int(), 255)
  assert_eq(flipped_h.data[3].to_int(), 0)
  // 垂直翻转：上下互换（此图上下相同，所以不变）
  let flipped_v = @img.flip_vertical(img)
  assert_eq(flipped_v.data[0].to_int(), 0)
  // 二次翻转恢复原图
  let restored = @img.flip_horizontal(flipped_h)
  assert_eq(restored.data, img.data)
}
