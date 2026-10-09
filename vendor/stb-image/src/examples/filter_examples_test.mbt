// 示例 10-12：滤波操作
// 演示模糊、锐化、边缘检测

///|
test "example_10: blur filters (box, gaussian, median)" {
  let img = make_gradient_image(8, 8)
  // Box blur（盒式模糊）
  let box_blurred = @img.box_blur(img, 3)
  assert_eq(box_blurred.width, 8)
  assert_eq(box_blurred.height, 8)
  // Gaussian blur（高斯模糊）
  let gauss_blurred = @img.gaussian_blur(img, 3, 1.0)
  assert_eq(gauss_blurred.width, 8)
  // Median blur（中值模糊）
  let median_blurred = @img.median_blur(img, 3)
  assert_eq(median_blurred.width, 8)
  // 双边滤波（保边去噪）
  let bilateral = @img.bilateral_filter(@img.to_rgb(img), 5, 50.0, 50.0)
  assert_eq(bilateral.width, 8)
  // 快速双边滤波
  let bilateral_fast = @img.bilateral_filter_fast(
    @img.to_rgb(img),
    5,
    50.0,
    50.0,
    2,
  )
  assert_eq(bilateral_fast.width, 8)
}

///|
test "example_11: sharpen image" {
  let img = make_gradient_image(8, 8)
  // 锐化（拉普拉斯锐化）
  let sharpened = @img.sharpen(img, 1.0) catch { _ => img }
  assert_eq(sharpened.width, 8)
  assert_eq(sharpened.height, 8)
  // 自定义卷积核（Sobel X 方向）
  let sobel_x : Array[Float] = [
    -1.0F,
    0.0F,
    1.0F,
    -2.0F,
    0.0F,
    2.0F,
    -1.0F,
    0.0F,
    1.0F,
  ]
  let convolved = @img.convolve(img, sobel_x, 0.0F, 1.0F) catch { _ => img }
  assert_eq(convolved.width, 8)
  // NLM 去噪
  let denoised = @img.nlm_denoise(@img.to_rgb(img))
  assert_eq(denoised.width, 8)
  // 快速 NLM 去噪
  let denoised_fast = @img.nlm_denoise_fast(@img.to_rgb(img))
  assert_eq(denoised_fast.width, 8)
}

///|
test "example_12: edge detection (Sobel, Prewitt, Laplacian, Canny)" {
  // 构造有明显边缘的图像
  let img = make_gray_image(8, 8, [
    0, 0, 0, 0, 255, 255, 255, 255, 0, 0, 0, 0, 255, 255, 255, 255, 0, 0, 0, 0, 255,
    255, 255, 255, 0, 0, 0, 0, 255, 255, 255, 255, 0, 0, 0, 0, 255, 255, 255, 255,
    0, 0, 0, 0, 255, 255, 255, 255, 0, 0, 0, 0, 255, 255, 255, 255, 0, 0, 0, 0, 255,
    255, 255, 255,
  ])
  // Sobel 边缘检测
  let sobel_edges = @img.edge_detect_sobel(img)
  assert_eq(sobel_edges.width, 8)
  // Prewitt 边缘检测
  let prewitt_edges = @img.edge_detect_prewitt(img)
  assert_eq(prewitt_edges.width, 8)
  // Laplacian 边缘检测
  let laplacian_edges = @img.edge_detect_laplacian(img)
  assert_eq(laplacian_edges.width, 8)
  // Canny 边缘检测（双阈值）
  let canny_edges = @img.canny_edge(img, low_threshold=50, high_threshold=100)
  assert_eq(canny_edges.width, 8)
  // 边缘图像中应有非零像素（在 x=3/4 交界处）
  assert_true(has_non_zero_pixel(sobel_edges))
}
