// v21.0.0 图像加密与水印增强测试 - image_encryption_advanced 模块

///|
fn make_double_data(n : Int) -> Array[Double] {
  let arr : Array[Double] = []
  for i in 0..<n {
    arr.push((i % 256).to_double())
  }
  arr
}

///|
test "create_default_encryption_config: 返回有效配置" {
  let config = create_default_encryption_config()
  assert_true(config.key_size > 0)
  assert_true(config.num_chaotic_iterations > 0)
}

///|
test "encrypt_image: 基本加密" {
  let config = create_default_encryption_config()
  let image = make_double_data(16)
  let key = [b'\xAA', b'\x55', b'\xFF']
  let result = encrypt_image(image, 4, 4, key, config)
  assert_true(result.encrypted_data.length() > 0)
}

///|
test "decrypt_image: 基本解密" {
  let config = create_default_encryption_config()
  let image = make_double_data(16)
  let key = [b'\xAA', b'\x55', b'\xFF']
  let enc = encrypt_image(image, 4, 4, key, config)
  let dec = decrypt_image(enc.encrypted_data, 4, 4, key, config)
  assert_eq(dec.width, 4)
  assert_eq(dec.height, 4)
}

///|
test "chaotic_encrypt: 基本加密" {
  let config = create_default_encryption_config()
  let image = make_double_data(16)
  let result = chaotic_encrypt(image, 4, 4, config)
  assert_true(result.encrypted_data.length() > 0)
}

///|
test "embed_steganography: 基本嵌入" {
  let config = create_default_encryption_config()
  let image = make_double_data(64)
  let hidden = [b'\x41', b'\x42', b'\x43']
  let result = embed_steganography(image, 8, 8, hidden, config)
  assert_eq(result.stego_image.length(), 64)
}

///|
test "embed_watermark: 基本嵌入" {
  let config = create_default_encryption_config()
  let image = make_double_data(64)
  let watermark = [b'\x41', b'\x42']
  let result = embed_watermark(image, 8, 8, watermark, config)
  assert_eq(result.watermarked_image.length(), 64)
}

///|
test "image_encryption_report_to_string: 报告生成" {
  let config = create_default_encryption_config()
  let report = image_encryption_report_to_string(
    ImageEncryptionTaskType::SymmetricEncryption,
    config,
    "加密完成",
  )
  assert_true(report.length() > 0)
}
