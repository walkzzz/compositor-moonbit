// 示例 15-16：绘图操作
// 演示线条、矩形、圆、多边形绘制

///|
test "example_15: draw line, rectangle, circle, polygon" {
  // 创建黑色 16x16 RGB 画布
  let canvas = make_rgb_image(16, 16, Array::make(256, (0, 0, 0)))
  let red = [b'\xFF', b'\x00', b'\x00']
  let green = [b'\x00', b'\xFF', b'\x00']
  let blue = [b'\x00', b'\x00', b'\xFF']
  // 画对角线
  let with_line = @img.draw_line(canvas, 0, 0, 15, 15, red, thickness=1)
  assert_eq(with_line.data[0].to_int(), 255) // (0,0) 红色 R 分量
  // 画矩形边框
  let with_rect = @img.draw_rectangle(canvas, 2, 2, 6, 6, green, thickness=1)
  // (2,2) 位置应为绿色 G=255
  let idx = (2 * 16 + 2) * 3
  assert_eq(with_rect.data[idx + 1].to_int(), 255)
  // 画圆
  let with_circle = @img.draw_circle(canvas, 8, 8, 5, blue, thickness=1)
  assert_eq(with_circle.width, 16)
  // 画多边形（三角形）
  let with_poly = @img.draw_polygon(
    canvas,
    [(4, 2), (2, 8), (8, 8)],
    red,
    thickness=1,
  )
  assert_eq(with_poly.width, 16)
}

///|
test "example_16: draw filled shapes and composite" {
  let canvas = make_rgb_image(16, 16, Array::make(256, (0, 0, 0)))
  let white = [b'\xFF', b'\xFF', b'\xFF']
  let yellow = [b'\xFF', b'\xFF', b'\x00']
  // 填充矩形
  let filled_rect = @img.draw_rectangle(
    canvas,
    2,
    2,
    8,
    8,
    white,
    thickness=1,
    fill=true,
  )
  // 内部点 (4,4) 应为白色
  let idx = (4 * 16 + 4) * 3
  assert_eq(filled_rect.data[idx].to_int(), 255)
  // 填充圆
  let filled_circle = @img.draw_circle(
    canvas,
    8,
    8,
    4,
    yellow,
    thickness=1,
    fill=true,
  )
  // 圆心 (8,8) 应为黄色
  let cidx = (8 * 16 + 8) * 3
  assert_eq(filled_circle.data[cidx].to_int(), 255) // R
  assert_eq(filled_circle.data[cidx + 1].to_int(), 255) // G
  assert_eq(filled_circle.data[cidx + 2].to_int(), 0) // B
  // 填充多边形
  let filled_poly = @img.draw_polygon(
    canvas,
    [(8, 2), (2, 14), (14, 14)],
    white,
    thickness=1,
    fill=true,
  )
  assert_eq(filled_poly.width, 16)
  // 图像叠加：draw_copy 将小图复制到大图指定位置
  let small = make_rgb_image(4, 4, Array::make(16, (255, 0, 0)))
  let composed = @img.draw_copy(canvas, small, 6, 6)
  let cidx2 = (6 * 16 + 6) * 3
  assert_eq(composed.data[cidx2].to_int(), 255) // 红色 R
}
