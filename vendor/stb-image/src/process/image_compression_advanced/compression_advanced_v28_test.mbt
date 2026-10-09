// v28.0.0 图像压缩高级模块测试
// 覆盖 image_compression_advanced/image_compression_advanced.mbt 的 6 个公开函数

///|
fn create_flat_data(w : Int, h : Int, value : Double) -> Array[Double] {
  let data : Array[Double] = []
  for _ in 0..<(w * h) {
    data.push(value)
  }
  data
}

///|
fn create_gradient_data(w : Int, h : Int) -> Array[Double] {
  let data : Array[Double] = []
  for _ in 0..<h {
    for x in 0..<w {
      data.push((x * 255 / w).to_double())
    }
  }
  data
}

///|
test "create_default_compression_config: 高级默认配置正确" {
  let config = create_default_compression_config()
  assert_true(config.quality > 0)
  assert_true(config.block_size > 0)
  assert_true(config.num_threads > 0)
}

///|
test "compress_image: 压缩平铺数据" {
  let data = create_flat_data(16, 16, 128.0)
  let config = create_default_compression_config()
  let result = compress_image(data, 16, 16, config)
  assert_true(result.original_size_bytes > 0)
  assert_true(result.compressed_size_bytes >= 0)
  assert_true(result.compression_ratio >= 0.0)
  assert_true(result.bits_per_pixel >= 0.0)
}

///|
test "compress_image: 压缩渐变数据" {
  let data = create_gradient_data(16, 16)
  let config = create_default_compression_config()
  let result = compress_image(data, 16, 16, config)
  assert_true(result.original_size_bytes > 0)
  assert_true(result.psnr >= 0.0)
}

///|
test "decompress_image: 解压平铺数据" {
  let flat_data = create_flat_data(16, 16, 128.0)
  let config = create_default_compression_config()
  let compressed = compress_image(flat_data, 16, 16, config)
  let compressed_bytes : Array[Byte] = []
  for i in 0..<compressed.compressed_data.length() {
    compressed_bytes.push(compressed.compressed_data[i])
  }
  let result = decompress_image(compressed_bytes, 16, 16, config)
  assert_true(result.width >= 0)
  assert_true(result.height >= 0)
  assert_true(result.decompression_time_ms >= 0.0)
}

///|
test "evaluate_compression_quality: 相同数据质量" {
  let data = create_gradient_data(16, 16)
  let metrics = evaluate_compression_quality(data, data, 16, 16)
  assert_true(metrics.psnr >= 0.0)
  assert_true(metrics.ssim >= 0.0)
  assert_true(metrics.bits_per_pixel >= 0.0)
}

///|
test "evaluate_compression_quality: 不同数据质量" {
  let original = create_gradient_data(16, 16)
  let compressed = create_flat_data(16, 16, 128.0)
  let metrics = evaluate_compression_quality(original, compressed, 16, 16)
  assert_true(metrics.psnr >= 0.0)
  assert_true(metrics.overall_quality >= 0.0)
}

///|
test "optimize_rate_distortion: 优化平铺数据" {
  let data = create_flat_data(16, 16, 128.0)
  let config = create_default_compression_config()
  let result = optimize_rate_distortion(data, 16, 16, config)
  assert_true(result.optimal_quality >= 0)
  assert_true(result.optimal_bitrate >= 0.0)
  assert_true(result.optimal_psnr >= 0.0)
  assert_true(result.num_points >= 0)
}

///|
test "optimize_rate_distortion: 优化渐变数据" {
  let data = create_gradient_data(16, 16)
  let config = create_default_compression_config()
  let result = optimize_rate_distortion(data, 16, 16, config)
  assert_true(result.optimal_ssim >= 0.0)
  assert_true(result.lambda >= 0.0)
  assert_true(result.optimization_method.length() > 0)
}

///|
test "image_compression_report_to_string: 报告非空" {
  let config = create_default_compression_config()
  let report = image_compression_report_to_string(
    ImageCompressionTaskType::JPEGCompression,
    config,
    "测试压缩任务",
  )
  assert_true(report.length() > 0)
}

///|
test "image_compression_report_to_string: 不同任务类型" {
  let config = create_default_compression_config()
  let report1 = image_compression_report_to_string(
    ImageCompressionTaskType::LosslessCompression,
    config,
    "无损",
  )
  let report2 = image_compression_report_to_string(
    ImageCompressionTaskType::WebPCompression,
    config,
    "WebP",
  )
  assert_true(report1.length() > 0)
  assert_true(report2.length() > 0)
}
