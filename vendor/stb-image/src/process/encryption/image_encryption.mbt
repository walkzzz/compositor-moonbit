// 图像加密（v12.14.0）
// 基于混沌的图像加密、Logistic 映射、加密质量评估

///|
/// 加密配置
pub(all) struct EncryptionConfig {
  method_type : String // "logistic" / "xor"
  key : Double // 混沌系统初始值
  mu : Double // Logistic 映射参数（通常 3.5699456 < mu <= 4）
  iterations : Int // 混沌迭代次数
}

///|
/// 创建默认加密配置
pub fn encryption_default_config() -> EncryptionConfig {
  EncryptionConfig::{
    method_type: "logistic",
    key: 0.123456789,
    mu: 3.99,
    iterations: 1000,
  }
}

///|
/// 简单的伪随机数生成器（线性同余）
fn lcg_next(seed : Int) -> (Int, Int) {
  let a = 1103515245
  let c = 12345
  let m = 1073741824
  let next = ((a * seed + c) % m).abs()
  (next, next)
}

///|
/// Logistic 混沌映射：x(n+1) = mu * x(n) * (1 - x(n))
fn logistic_map(x : Double, mu : Double) -> Double {
  mu * x * (1.0 - x)
}

///|
/// 生成混沌序列
fn generate_chaotic_sequence(
  length : Int,
  key : Double,
  mu : Double,
  warmup? : Int = 100,
) -> Array[Double] {
  let warm = warmup
  let sequence : Array[Double] = []
  let mut x = key
  // 预热（丢弃前 warm 个值）
  for _ in 0..<warm {
    x = logistic_map(x, mu)
  }
  // 生成序列
  for _ in 0..<length {
    x = logistic_map(x, mu)
    sequence.push(x)
  }
  sequence
}

///|
/// 基于 Logistic 混沌映射的图像加密
pub fn encrypt_image_logistic(
  img : @types.Image,
  key? : Double = 0.123456789,
  mu? : Double = 3.99,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "encrypt_image_logistic: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "encrypt_image_logistic: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "encrypt_image_logistic: 数据大小不匹配",
    )
  }
  let k = key
  let m = mu
  let w = img.width
  let h = img.height
  let channels = img.channels
  let total_pixels = w * h * channels
  // 生成混沌序列
  let chaotic = generate_chaotic_sequence(total_pixels, k, m, warmup=100)
  // XOR 加密
  let out_data : Array[Byte] = Array::make(total_pixels, b'\x00')
  for i in 0..<total_pixels {
    // 将混沌值映射到 0-255
    let chaotic_byte = (chaotic[i] * 256.0).to_int().min(255).max(0)
    let original = img.data[i].to_int()
    let encrypted = original ^ chaotic_byte
    out_data[i] = encrypted.to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 基于 Logistic 混沌映射的图像解密（与加密相同，因为 XOR 是对称的）
pub fn decrypt_image_logistic(
  img : @types.Image,
  key? : Double = 0.123456789,
  mu? : Double = 3.99,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "decrypt_image_logistic: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "decrypt_image_logistic: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "decrypt_image_logistic: 数据大小不匹配",
    )
  }
  // XOR 加密是对称的，解密与加密使用相同的操作
  encrypt_image_logistic(img, key~, mu~)
}

///|
/// 简单的 XOR 加密（使用密钥字节序列）
pub fn encrypt_image_xor(
  img : @types.Image,
  key : String,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "encrypt_image_xor: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "encrypt_image_xor: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "encrypt_image_xor: 数据大小不匹配",
    )
  }
  if key.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "encrypt_image_xor: 密钥不能为空",
    )
  }
  let w = img.width
  let h = img.height
  let channels = img.channels
  let total_pixels = w * h * channels
  let key_bytes = @encoding/utf8.encode(key)
  let key_len = key_bytes.length()
  let out_data : Array[Byte] = Array::make(total_pixels, b'\x00')
  for i in 0..<total_pixels {
    let key_byte = key_bytes[i % key_len].to_int()
    let original = img.data[i].to_int()
    let encrypted = original ^ key_byte
    out_data[i] = encrypted.to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 简单的 XOR 解密
pub fn decrypt_image_xor(
  img : @types.Image,
  key : String,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "decrypt_image_xor: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "decrypt_image_xor: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "decrypt_image_xor: 数据大小不匹配",
    )
  }
  if key.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "decrypt_image_xor: 密钥不能为空",
    )
  }
  encrypt_image_xor(img, key)
}

///|
/// 计算图像直方图
fn compute_histogram(img : @types.Image) -> Array[Int] {
  let histogram : Array[Int] = []
  for _ in 0..<256 {
    histogram.push(0)
  }
  let w = img.width
  let h = img.height
  let channels = img.channels
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      for c in 0..<channels {
        let val = img.data[idx + c].to_int()
        histogram[val] += 1
      }
    }
  }
  histogram
}

///|
/// 计算直方图熵（衡量加密质量，熵越高越好）
pub fn histogram_entropy(img : @types.Image) -> Double raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "histogram_entropy: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "histogram_entropy: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "histogram_entropy: 数据大小不匹配",
    )
  }
  let histogram = compute_histogram(img)
  let w = img.width
  let h = img.height
  let channels = img.channels
  let total = (w * h * channels).to_double()
  let mut entropy = 0.0
  for count in histogram {
    if count > 0 {
      let p = count.to_double() / total
      entropy -= p * @math.log2(p)
    }
  }
  entropy
}

///|
/// 计算相邻像素相关性（加密后应接近 0）
pub fn adjacent_correlation(
  img : @types.Image,
  direction? : String = "horizontal",
) -> Double raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "adjacent_correlation: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "adjacent_correlation: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "adjacent_correlation: 数据大小不匹配",
    )
  }
  let dir = direction
  let w = img.width
  let h = img.height
  let channels = img.channels
  // 采样点数量
  let sample_count = if 1000 < w * h { 1000 } else { w * h }
  let mut sum_x = 0.0
  let mut sum_y = 0.0
  let mut sum_xy = 0.0
  let mut sum_x2 = 0.0
  let mut sum_y2 = 0.0
  let mut count = 0
  let mut seed = 12345
  for _ in 0..<sample_count {
    // 随机选择像素位置
    let (next, value) = lcg_next(seed)
    seed = next
    let x = value % w
    let (next2, value2) = lcg_next(seed)
    seed = next2
    let y = value2 % h
    let idx = (y * w + x) * channels
    let pixel1 = img.data[idx].to_double()
    // 相邻像素
    let pixel2 = match dir {
      "horizontal" =>
        if x + 1 < w {
          img.data[(y * w + x + 1) * channels].to_double()
        } else {
          img.data[idx].to_double()
        }
      "vertical" =>
        if y + 1 < h {
          img.data[((y + 1) * w + x) * channels].to_double()
        } else {
          img.data[idx].to_double()
        }
      "diagonal" =>
        if x + 1 < w && y + 1 < h {
          img.data[((y + 1) * w + x + 1) * channels].to_double()
        } else {
          img.data[idx].to_double()
        }
      _ => img.data[idx].to_double()
    }
    sum_x += pixel1
    sum_y += pixel2
    sum_xy += pixel1 * pixel2
    sum_x2 += pixel1 * pixel1
    sum_y2 += pixel2 * pixel2
    count += 1
  }
  if count == 0 {
    return 0.0
  }
  let n = count.to_double()
  let mean_x = sum_x / n
  let mean_y = sum_y / n
  let cov_xy = sum_xy / n - mean_x * mean_y
  let var_x = sum_x2 / n - mean_x * mean_x
  let var_y = sum_y2 / n - mean_y * mean_y
  let denom = (var_x * var_y).sqrt()
  if denom < 0.000001 {
    return 0.0
  }
  cov_xy / denom
}

///|
/// 加密质量评估
pub(all) struct EncryptionQuality {
  entropy : Double // 直方图熵（理想值 8）
  correlation_h : Double // 水平相关性（理想值 0）
  correlation_v : Double // 垂直相关性（理想值 0）
  correlation_d : Double // 对角相关性（理想值 0）
  npcr : Double // 像素变化率（Number of Pixel Change Rate）
  uaci : Double // 统一平均变化强度（Unified Average Changing Intensity）
}

///|
/// 计算 NPCR（像素变化率）
fn compute_npcr(img1 : @types.Image, img2 : @types.Image) -> Double {
  if img1.width != img2.width || img1.height != img2.height {
    return 0.0
  }
  let w = img1.width
  let h = img1.height
  let channels = img1.channels.min(img2.channels)
  let total = w * h * channels
  let mut changed = 0
  for i in 0..<total {
    if img1.data[i] != img2.data[i] {
      changed += 1
    }
  }
  changed.to_double() / total.to_double() * 100.0
}

///|
/// 计算 UACI（统一平均变化强度）
fn compute_uaci(img1 : @types.Image, img2 : @types.Image) -> Double {
  if img1.width != img2.width || img1.height != img2.height {
    return 0.0
  }
  let w = img1.width
  let h = img1.height
  let channels = img1.channels.min(img2.channels)
  let total = w * h * channels
  let mut sum = 0.0
  for i in 0..<total {
    let diff = (img1.data[i].to_int() - img2.data[i].to_int()).abs().to_double()
    sum += diff / 255.0
  }
  sum / total.to_double() * 100.0
}

///|
/// 评估加密质量
pub fn evaluate_encryption_quality(
  original : @types.Image,
  encrypted : @types.Image,
) -> EncryptionQuality raise @types.LoadError {
  // 输入验证
  if original.width <= 0 || original.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "evaluate_encryption_quality: 图像尺寸必须大于0",
    )
  }
  if original.channels < 1 || original.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "evaluate_encryption_quality: 通道数必须在1-4之间",
    )
  }
  let expected_size = original.width * original.height * original.channels
  if original.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "evaluate_encryption_quality: 数据大小不匹配",
    )
  }
  if encrypted.width <= 0 || encrypted.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "evaluate_encryption_quality: 图像尺寸必须大于0",
    )
  }
  if encrypted.channels < 1 || encrypted.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "evaluate_encryption_quality: 通道数必须在1-4之间",
    )
  }
  let expected_size2 = encrypted.width * encrypted.height * encrypted.channels
  if encrypted.data.length() != expected_size2 {
    raise @types.LoadError::DecodeFailed(
      "evaluate_encryption_quality: 数据大小不匹配",
    )
  }
  let entropy = histogram_entropy(encrypted)
  let corr_h = adjacent_correlation(encrypted, direction="horizontal")
  let corr_v = adjacent_correlation(encrypted, direction="vertical")
  let corr_d = adjacent_correlation(encrypted, direction="diagonal")
  let npcr = compute_npcr(original, encrypted)
  let uaci = compute_uaci(original, encrypted)
  EncryptionQuality::{
    entropy,
    correlation_h: corr_h,
    correlation_v: corr_v,
    correlation_d: corr_d,
    npcr,
    uaci,
  }
}

///|
/// 密钥敏感性测试（微小密钥变化导致完全不同的密文）
pub fn key_sensitivity_test(
  img : @types.Image,
  key : Double,
  delta? : Double = 0.0000001,
) -> Double raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "key_sensitivity_test: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "key_sensitivity_test: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "key_sensitivity_test: 数据大小不匹配",
    )
  }
  let d = delta
  let encrypted1 = encrypt_image_logistic(img, key~, mu=3.99)
  let encrypted2 = encrypt_image_logistic(img, key=key + d, mu=3.99)
  compute_npcr(encrypted1, encrypted2)
}

///|
/// 批量加密
pub fn batch_encrypt(
  images : Array[@types.Image],
  key : Double,
) -> Array[@types.Image] raise @types.LoadError {
  // 输入验证
  for img in images {
    if img.width <= 0 || img.height <= 0 {
      raise @types.LoadError::DecodeFailed(
        "batch_encrypt: 图像尺寸必须大于0",
      )
    }
    if img.channels < 1 || img.channels > 4 {
      raise @types.LoadError::DecodeFailed(
        "batch_encrypt: 通道数必须在1-4之间",
      )
    }
    let expected_size = img.width * img.height * img.channels
    if img.data.length() != expected_size {
      raise @types.LoadError::DecodeFailed(
        "batch_encrypt: 数据大小不匹配",
      )
    }
  }
  let result : Array[@types.Image] = []
  for img in images {
    result.push(encrypt_image_logistic(img, key~, mu=3.99))
  }
  result
}
