// 图像质量评估（纯 MoonBit）：mse / psnr / ssim

///|
/// 均方误差（MSE）。计算两幅图像对应像素的均方误差。
/// 两幅图像必须具有相同的尺寸和通道数。
/// 返回 Double 类型的 MSE 值。
pub fn mse(
  img1 : @types.Image,
  img2 : @types.Image,
) -> Double raise @types.LoadError {
  // 输入验证
  if img1.width <= 0 || img1.height <= 0 {
    raise @types.LoadError::DecodeFailed("mse: 图像1尺寸必须大于0")
  }
  if img2.width <= 0 || img2.height <= 0 {
    raise @types.LoadError::DecodeFailed("mse: 图像2尺寸必须大于0")
  }
  if img1.channels < 1 || img1.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "mse: 图像1通道数必须在1-4之间",
    )
  }
  if img2.channels < 1 || img2.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "mse: 图像2通道数必须在1-4之间",
    )
  }
  if img1.width != img2.width || img1.height != img2.height {
    raise @types.LoadError::DecodeFailed("mse: 两幅图像尺寸必须相同")
  }
  if img1.channels != img2.channels {
    raise @types.LoadError::DecodeFailed(
      "mse: 两幅图像通道数必须相同",
    )
  }
  let expected_size = img1.width * img1.height * img1.channels
  if img1.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "mse: 图像1数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img1.data.length().to_string(),
    )
  }
  if img2.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "mse: 图像2数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img2.data.length().to_string(),
    )
  }

  let n = img1.data.length()
  let mut sum : Int = 0
  for i in 0..<n {
    let d = img1.data[i].to_int() - img2.data[i].to_int()
    sum += d * d
  }
  sum.to_double() / n.to_double()
}

///|
/// 峰值信噪比（PSNR）。基于 MSE 计算 PSNR（单位 dB）。
/// 若两幅图像完全相同（MSE=0），返回 Infinity。
/// 两幅图像必须具有相同的尺寸和通道数。
pub fn psnr(
  img1 : @types.Image,
  img2 : @types.Image,
) -> Double raise @types.LoadError {
  // 输入验证
  if img1.width <= 0 || img1.height <= 0 {
    raise @types.LoadError::DecodeFailed("psnr: 图像1尺寸必须大于0")
  }
  if img2.width <= 0 || img2.height <= 0 {
    raise @types.LoadError::DecodeFailed("psnr: 图像2尺寸必须大于0")
  }
  if img1.channels < 1 || img1.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "psnr: 图像1通道数必须在1-4之间",
    )
  }
  if img2.channels < 1 || img2.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "psnr: 图像2通道数必须在1-4之间",
    )
  }
  if img1.width != img2.width || img1.height != img2.height {
    raise @types.LoadError::DecodeFailed("psnr: 两幅图像尺寸必须相同")
  }
  if img1.channels != img2.channels {
    raise @types.LoadError::DecodeFailed(
      "psnr: 两幅图像通道数必须相同",
    )
  }
  let expected_size = img1.width * img1.height * img1.channels
  if img1.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "psnr: 图像1数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img1.data.length().to_string(),
    )
  }
  if img2.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "psnr: 图像2数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img2.data.length().to_string(),
    )
  }

  let m = mse(img1, img2)
  if m == 0.0 {
    return 1.0 / 0.0
  }
  10.0 * @math.log10(255.0 * 255.0 / m)
}

///|
/// 结构相似性指数（SSIM）。在 8x8 局部窗口上计算 SSIM 均值。
/// 两幅图像必须具有相同的尺寸和通道数。
/// 返回 Double 类型的 SSIM 值，范围.围 [-1, 1]，越接近 1 越相似。
pub fn ssim(
  img1 : @types.Image,
  img2 : @types.Image,
) -> Double raise @types.LoadError {
  // 输入验证
  if img1.width <= 0 || img1.height <= 0 {
    raise @types.LoadError::DecodeFailed("ssim: 图像1尺寸必须大于0")
  }
  if img2.width <= 0 || img2.height <= 0 {
    raise @types.LoadError::DecodeFailed("ssim: 图像2尺寸必须大于0")
  }
  if img1.channels < 1 || img1.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "ssim: 图像1通道数必须在1-4之间",
    )
  }
  if img2.channels < 1 || img2.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "ssim: 图像2通道数必须在1-4之间",
    )
  }
  if img1.width != img2.width || img1.height != img2.height {
    raise @types.LoadError::DecodeFailed("ssim: 两幅图像尺寸必须相同")
  }
  if img1.channels != img2.channels {
    raise @types.LoadError::DecodeFailed(
      "ssim: 两幅图像通道数必须相同",
    )
  }
  let expected_size = img1.width * img1.height * img1.channels
  if img1.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "ssim: 图像1数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img1.data.length().to_string(),
    )
  }
  if img2.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "ssim: 图像2数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img2.data.length().to_string(),
    )
  }

  let w = img1.width
  let h = img1.height
  let ch = img1.channels
  let n = w * h
  let c1 = 0.01 * 255.0 * (0.01 * 255.0)
  let c2 = 0.03 * 255.0 * (0.03 * 255.0)
  let win = 8
  let half = win / 2
  // 预计算通道求和/平方和/乘积和图像，用于构建积分图
  let sum1 : Array[Double] = Array::make(n, 0.0)
  let sum2 : Array[Double] = Array::make(n, 0.0)
  let sq1 : Array[Double] = Array::make(n, 0.0)
  let sq2 : Array[Double] = Array::make(n, 0.0)
  let s12 : Array[Double] = Array::make(n, 0.0)
  for i in 0..<n {
    let mut a = 0.0
    let mut b = 0.0
    let mut aa = 0.0
    let mut bb = 0.0
    let mut ab = 0.0
    for c in 0..<ch {
      let v1 = img1.data[i * ch + c].to_int().to_double()
      let v2 = img2.data[i * ch + c].to_int().to_double()
      a += v1
      b += v2
      aa += v1 * v1
      bb += v2 * v2
      ab += v1 * v2
    }
    sum1[i] = a
    sum2[i] = b
    sq1[i] = aa
    sq2[i] = bb
    s12[i] = ab
  }
  // 构建积分图 (w+1)*(h+1)，integral[y][x] = sum of img[0..y, 0..x]
  let iw = w + 1
  let ih = h + 1
  let i_sum1 : Array[Double] = Array::make(iw * ih, 0.0)
  let i_sum2 : Array[Double] = Array::make(iw * ih, 0.0)
  let i_sq1 : Array[Double] = Array::make(iw * ih, 0.0)
  let i_sq2 : Array[Double] = Array::make(iw * ih, 0.0)
  let i_s12 : Array[Double] = Array::make(iw * ih, 0.0)
  for y in 1..<=h {
    let mut rs1 = 0.0
    let mut rs2 = 0.0
    let mut rq1 = 0.0
    let mut rq2 = 0.0
    let mut r12 = 0.0
    for x in 1..<=w {
      let idx = (y - 1) * w + (x - 1)
      rs1 += sum1[idx]
      rs2 += sum2[idx]
      rq1 += sq1[idx]
      rq2 += sq2[idx]
      r12 += s12[idx]
      let above = (y - 1) * iw + x
      i_sum1[y * iw + x] = i_sum1[above] + rs1
      i_sum2[y * iw + x] = i_sum2[above] + rs2
      i_sq1[y * iw + x] = i_sq1[above] + rq1
      i_sq2[y * iw + x] = i_sq2[above] + rq2
      i_s12[y * iw + x] = i_s12[above] + r12
    }
  }
  let mut total : Double = 0.0
  let mut count = 0
  let inner_n = win * win * ch
  let inner_n_d = inner_n.to_double()
  // 内部区域：用积分图 O(1) 计算窗口统计量
  for y in half..<(h - half) {
    for x in half..<(w - half) {
      let x0 = x - half
      let y0 = y - half
      let x1 = x0 + win
      let y1 = y0 + win
      let s1 = i_sum1[y1 * iw + x1] -
        i_sum1[y0 * iw + x1] -
        i_sum1[y1 * iw + x0] +
        i_sum1[y0 * iw + x0]
      let s2 = i_sum2[y1 * iw + x1] -
        i_sum2[y0 * iw + x1] -
        i_sum2[y1 * iw + x0] +
        i_sum2[y0 * iw + x0]
      let sq1v = i_sq1[y1 * iw + x1] -
        i_sq1[y0 * iw + x1] -
        i_sq1[y1 * iw + x0] +
        i_sq1[y0 * iw + x0]
      let sq2v = i_sq2[y1 * iw + x1] -
        i_sq2[y0 * iw + x1] -
        i_sq2[y1 * iw + x0] +
        i_sq2[y0 * iw + x0]
      let s12v = i_s12[y1 * iw + x1] -
        i_s12[y0 * iw + x1] -
        i_s12[y1 * iw + x0] +
        i_s12[y0 * iw + x0]
      let mu1 = s1 / inner_n_d
      let mu2 = s2 / inner_n_d
      let var1 = sq1v / inner_n_d - mu1 * mu1
      let var2 = sq2v / inner_n_d - mu2 * mu2
      let cov = s12v / inner_n_d - mu1 * mu2
      let s = (2.0 * mu1 * mu2 + c1) *
        (2.0 * cov + c2) /
        ((mu1 * mu1 + mu2 * mu2 + c1) * (var1 + var2 + c2))
      total += s
      count += 1
    }
  }
  // 边界区域：预计算 Double 数组，用 O(win²) 方法
  let src1 : Array[Double] = Array::make(n * ch, 0.0)
  let src2 : Array[Double] = Array::make(n * ch, 0.0)
  for i in 0..<(n * ch) {
    src1[i] = img1.data[i].to_int().to_double()
    src2[i] = img2.data[i].to_int().to_double()
  }
  for y in 0..<h {
    let y_inner = y >= half && y < h - half
    for x in 0..<w {
      if y_inner && x >= half && x < w - half {
        continue
      }
      let mut mu1 : Double = 0.0
      let mut mu2 : Double = 0.0
      let mut nn = 0
      for dy in 0..<win {
        for dx in 0..<win {
          let sx = clamp_i(x + dx - half, 0, w - 1)
          let sy = clamp_i(y + dy - half, 0, h - 1)
          for c in 0..<ch {
            mu1 += src1[(sy * w + sx) * ch + c]
            mu2 += src2[(sy * w + sx) * ch + c]
            nn += 1
          }
        }
      }
      mu1 /= nn.to_double()
      mu2 /= nn.to_double()
      let mut var1 : Double = 0.0
      let mut var2 : Double = 0.0
      let mut cov : Double = 0.0
      for dy in 0..<win {
        for dx in 0..<win {
          let sx = clamp_i(x + dx - half, 0, w - 1)
          let sy = clamp_i(y + dy - half, 0, h - 1)
          for c in 0..<ch {
            let v1 = src1[(sy * w + sx) * ch + c] - mu1
            let v2 = src2[(sy * w + sx) * ch + c] - mu2
            var1 += v1 * v1
            var2 += v2 * v2
            cov += v1 * v2
          }
        }
      }
      var1 /= nn.to_double()
      var2 /= nn.to_double()
      cov /= nn.to_double()
      let s = (2.0 * mu1 * mu2 + c1) *
        (2.0 * cov + c2) /
        ((mu1 * mu1 + mu2 * mu2 + c1) * (var1 + var2 + c2))
      total += s
      count += 1
    }
  }
  total / count.to_double()
}
