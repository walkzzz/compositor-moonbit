// 示例 25-29：高级算法（图像修复/光流/grabCut/Retinex/去雾）

///|
test "example_25: image inpainting (watermark removal)" {
  let img = @img.load_from_bytes(test_4x4_red_png, req_channels=Some(3))
  let mask_data : Array[Byte] = Array::make(img.width * img.height, b'\x00')
  for y in 1..<3 {
    for x in 1..<3 {
      mask_data[y * img.width + x] = b'\xFF'
    }
  }
  let mask = @types.Image::{
    width: img.width,
    height: img.height,
    channels: 1,
    data: Bytes::from_array(mask_data),
  }
  let restored = @img.inpaint(img, mask, iterations=3)
  assert_eq(restored.width, img.width)
  assert_eq(restored.height, img.height)
  let restored_fast = @img.inpaint_fast(img, mask, radius=3)
  assert_eq(restored_fast.width, img.width)
}

///|
test "example_26: Lucas-Kanade optical flow" {
  let frame1 = make_gradient_image(8, 8)
  let frame2 = make_gradient_image(8, 8)
  let points : Array[(Int, Int)] = [(3, 3), (4, 4), (5, 5)]
  let flow = @img.lucas_kanade(frame1, frame2, points, window_size=5)
  assert_eq(flow.length(), points.length())
  for f in flow {
    if f.found {
      assert_true(f.u * f.u + f.v * f.v < 1.0)
    }
  }
}

///|
test "example_27: grabCut segmentation" {
  let img = @img.load_from_bytes(test_4x4_red_png, req_channels=Some(3))
  let result = @img.grab_cut(img, 0, 0, img.width, img.height)
  assert_eq(result.width, img.width)
  assert_eq(result.height, img.height)
  assert_true(is_binary_image(result))
}

///|
test "example_28: multi-scale Retinex (MSR)" {
  let img = @img.load_from_bytes(test_4x4_red_png, req_channels=Some(3))
  let scales : Array[Float] = [15.0, 80.0, 250.0]
  let result = @img.msr(img, sigmas=scales)
  assert_eq(result.width, img.width)
  assert_eq(result.height, img.height)
  assert_eq(result.channels, img.channels)
  let msrcr_result = @img.msrcr(img, sigmas=scales)
  assert_eq(msrcr_result.width, img.width)
}

///|
test "example_29: dehaze (dark channel prior)" {
  let img = @img.load_from_bytes(test_4x4_red_png, req_channels=Some(3))
  let dehazed = @img.dehaze(img)
  assert_eq(dehazed.width, img.width)
  assert_eq(dehazed.height, img.height)
  assert_eq(dehazed.channels, img.channels)
}
