// 示例 30-32：频域分析 + 质量评估 + 安全审计

///|
test "example_30: FFT 2D and frequency filtering" {
  let img = make_gradient_image(8, 8)
  // 2D FFT
  let fft_results = @img.fft_2d(img)
  assert_true(fft_results.length() > 0)
  // FFT 幅度谱
  let magnitude = @img.fft_magnitude(fft_results[0], false)
  assert_eq(magnitude.width, 8)
  assert_eq(magnitude.height, 8)
  // FFT 移位（将低频移到中心）
  let shifted = @img.fft_shift(fft_results[0])
  ignore(shifted)
  // 频域高斯低通滤波
  let filtered = @img.freq_filter_gaussian(
    img,
    @img.FreqFilterType::LowPass,
    4.0F,
  )
  assert_eq(filtered.width, img.width)
  assert_eq(filtered.height, img.height)
}

///|
test "example_31: image quality assessment (MSE/PSNR/SSIM)" {
  let img1 = @img.load_from_bytes(test_4x4_red_png, req_channels=Some(3))
  let img2 = @img.load_from_bytes(test_4x4_red_png, req_channels=Some(3))
  // MSE（均方误差）
  let mse_val = @img.mse(img1, img2)
  // 相同图像 MSE 应为 0
  assert_true(mse_val < 1.0)
  // PSNR（峰值信噪比）
  let psnr_val = @img.psnr(img1, img2)
  // 相同图像 PSNR 应很高
  assert_true(psnr_val > 40.0)
  // SSIM（结构相似性）
  let ssim_val = @img.ssim(img1, img2)
  // 相同图像 SSIM 应接近 1
  assert_true(ssim_val > 0.99)
}

///|
test "example_32: safe decoding of corrupted data" {
  // 安全解码：损坏的 PNG 应返回错误而非 panic
  try {
    let _ = @img.load_from_bytes(corrupt_truncated_png)
  } catch {
    @types.LoadError::DecodeFailed(_) => ()
    @types.LoadError::UnsupportedFormat(_) => ()
    @types.LoadError::FileIO(_) => ()
    @types.LoadError::EncodeFailed(_) => ()
  } noraise {
    _ => fail("corrupted data should not decode successfully")
  }
  // 随机二进制数据应返回 UnsupportedFormat
  try {
    let _ = @img.load_from_bytes(corrupt_random_bin)
  } catch {
    @types.LoadError::DecodeFailed(_) => ()
    @types.LoadError::UnsupportedFormat(_) => ()
    @types.LoadError::FileIO(_) => ()
    @types.LoadError::EncodeFailed(_) => ()
  } noraise {
    _ => fail("random data should not decode successfully")
  }
  // 空字节应安全处理
  try {
    let _ = @img.load_from_bytes(b"")
  } catch {
    @types.LoadError::DecodeFailed(_) => ()
    @types.LoadError::UnsupportedFormat(_) => ()
    @types.LoadError::FileIO(_) => ()
    @types.LoadError::EncodeFailed(_) => ()
  } noraise {
    _ => fail("empty data should not decode successfully")
  }
}
