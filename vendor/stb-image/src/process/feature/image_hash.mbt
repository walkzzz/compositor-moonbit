// 感知哈希（纯 MoonBit）：ahash / dhash / phash / hamming_distance

///|
/// 均值哈希（aHash）。将图像缩放至 8×8 灰度，与均值比较生成 64 位哈希。
pub fn ahash(img : @types.Image) -> Array[Int] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("ahash: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed("ahash: 通道数必须在1-4之间")
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "ahash: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  // 缩放到 8x8 灰度
  let small = resize_to_gray_8x8(img)
  let mut sum = 0
  for i in 0..<64 {
    sum += small[i]
  }
  let mean = sum / 64
  let hash : Array[Int] = Array::make(64, 0)
  for i in 0..<64 {
    hash[i] = if small[i] > mean { 1 } else { 0 }
  }
  hash
}

///|
/// 差值哈希（dHash）。将图像缩放至 9×8 灰度，比较水平相邻像素差。
pub fn dhash(img : @types.Image) -> Array[Int] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("dhash: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed("dhash: 通道数必须在1-4之间")
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "dhash: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let small = resize_to_gray_9x8(img)
  let hash : Array[Int] = Array::make(64, 0)
  for row in 0..<8 {
    for col in 0..<8 {
      hash[row * 8 + col] = if small[row * 9 + col] > small[row * 9 + col + 1] {
        1
      } else {
        0
      }
    }
  }
  hash
}

///|
/// 感知哈希（pHash 简化版）。将图像缩放至 8×8 灰度，用 DCT 近似：取每行均值与全局均值比较。
/// 完整 pHash 需 2D DCT，此处用简化版本（行列均值差分），足以满足去重需求。
pub fn phash(img : @types.Image) -> Array[Int] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("phash: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed("phash: 通道数必须在1-4之间")
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "phash: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let small = resize_to_gray_8x8(img)
  // 简化 DCT：计算行均值和列均值
  let row_means : Array[Int] = Array::make(8, 0)
  let col_means : Array[Int] = Array::make(8, 0)
  for r in 0..<8 {
    let mut s = 0
    for c in 0..<8 {
      s += small[r * 8 + c]
    }
    row_means[r] = s / 8
  }
  for c in 0..<8 {
    let mut s = 0
    for r in 0..<8 {
      s += small[r * 8 + c]
    }
    col_means[c] = s / 8
  }
  // 全局均值
  let mut total = 0
  for i in 0..<8 {
    total += row_means[i]
  }
  let global_mean = total / 8
  // 生成哈希：行均值和列均值与全局均值比较
  let hash : Array[Int] = Array::make(64, 0)
  for i in 0..<8 {
    hash[i] = if row_means[i] > global_mean { 1 } else { 0 }
  }
  for i in 0..<8 {
    hash[8 + i] = if col_means[i] > global_mean { 1 } else { 0 }
  }
  // 填充剩余 48 位用像素级比较
  for i in 0..<48 {
    hash[16 + i] = if small[i + 16] > global_mean { 1 } else { 0 }
  }
  hash
}

///|
/// 汉明距离。计算两个哈希的差异位数。
pub fn hamming_distance(
  h1 : Array[Int],
  h2 : Array[Int],
) -> Int raise @types.LoadError {
  // 参数验证
  if h1.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "hamming_distance: h1数组不能为空",
    )
  }
  if h2.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "hamming_distance: h2数组不能为空",
    )
  }
  if h1.length() != h2.length() {
    raise @types.LoadError::DecodeFailed(
      "hamming_distance: h1和h2长度必须相同",
    )
  }

  let n = h1.length()
  let mut dist = 0
  for i in 0..<n {
    if h1[i] != h2[i] {
      dist += 1
    }
  }
  dist
}

///|
fn resize_to_gray_8x8(img : @types.Image) -> Array[Int] {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let out : Array[Int] = Array::make(64, 0)
  for y in 0..<8 {
    for x in 0..<8 {
      // 最近邻采样
      let sx = x * w / 8
      let sy = y * h / 8
      let v = if ch == 1 {
        img.data[sy * w + sx].to_int()
      } else {
        let r = img.data[(sy * w + sx) * ch].to_int()
        let g = img.data[(sy * w + sx) * ch + 1].to_int()
        let b = img.data[(sy * w + sx) * ch + 2].to_int()
        (r * 299 + g * 587 + b * 114) / 1000
      }
      out[y * 8 + x] = v
    }
  }
  out
}

///|
fn resize_to_gray_9x8(img : @types.Image) -> Array[Int] {
  let ch = img.channels
  let w = img.width
  let h = img.height
  let out : Array[Int] = Array::make(72, 0)
  for y in 0..<8 {
    for x in 0..<9 {
      let sx = x * w / 9
      let sy = y * h / 8
      let v = if ch == 1 {
        img.data[sy * w + sx].to_int()
      } else {
        let r = img.data[(sy * w + sx) * ch].to_int()
        let g = img.data[(sy * w + sx) * ch + 1].to_int()
        let b = img.data[(sy * w + sx) * ch + 2].to_int()
        (r * 299 + g * 587 + b * 114) / 1000
      }
      out[y * 9 + x] = v
    }
  }
  out
}
