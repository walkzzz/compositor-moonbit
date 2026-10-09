// 霍夫变换 16-bit/float 变体
// hough_lines / hough_circles

///|
/// 霍夫直线变换 16-bit 版本。
pub fn hough_lines_16(
  img : @types.Image16,
  threshold : Int,
  theta_resolution? : Float = 1.0F,
  rho_resolution? : Float = 1.0F,
) -> Array[HoughLine] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "hough_lines_16: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "hough_lines_16: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "hough_lines_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if threshold <= 0 {
    raise @types.LoadError::DecodeFailed(
      "hough_lines_16: threshold必须大于0",
    )
  }
  if theta_resolution <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "hough_lines_16: theta_resolution必须大于0",
    )
  }
  if rho_resolution <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "hough_lines_16: rho_resolution必须大于0",
    )
  }
  let w = img.width
  let h = img.height
  let ch = img.channels
  let n_theta = (180.0F / theta_resolution).to_int()
  let diag = Float::from_int(w * w + h * h).sqrt()
  let max_rho = (diag / rho_resolution).to_int() + 1
  let n_rho = 2 * max_rho + 1
  let accumulator : Array[Int] = Array::make(n_rho * n_theta, 0)
  let cos_table : Array[Float] = Array::make(n_theta, 0.0F)
  let sin_table : Array[Float] = Array::make(n_theta, 0.0F)
  let angle_scale = theta_resolution * 3.141592653589793F / 180.0F
  for t in 0..<n_theta {
    let angle = Float::from_int(t) * angle_scale
    cos_table[t] = @math.cosf(angle)
    sin_table[t] = @math.sinf(angle)
  }
  let inv_rho_res = 1.0F / rho_resolution
  let rho_max_idx = n_rho - 1
  let data_int : Array[Int] = Array::make(w * h, 0)
  for i in 0..<(w * h) {
    data_int[i] = img.data[i * ch * 2].to_int() |
      (img.data[i * ch * 2 + 1].to_int() << 8)
  }
  for y in 0..<h {
    let fy = Float::from_int(y)
    let row_base = y * w
    for x in 0..<w {
      if data_int[row_base + x] == 0 {
        continue
      }
      let fx = Float::from_int(x)
      for t in 0..<n_theta {
        let rho = fx * cos_table[t] + fy * sin_table[t]
        let raw_idx = (rho * inv_rho_res).to_int() + max_rho
        let rho_idx = if raw_idx < 0 {
          0
        } else if raw_idx > rho_max_idx {
          rho_max_idx
        } else {
          raw_idx
        }
        accumulator[rho_idx * n_theta + t] += 1
      }
    }
  }
  let lines : Array[HoughLine] = []
  let max_rho_f = Float::from_int(max_rho)
  for r in 0..<n_rho {
    let row_base = r * n_theta
    for t in 0..<n_theta {
      let votes = accumulator[row_base + t]
      if votes >= threshold {
        let rho = (Float::from_int(r) - max_rho_f) * rho_resolution
        let theta = Float::from_int(t) * angle_scale
        lines.push(HoughLine::{ rho, theta, votes })
      }
    }
  }
  lines.sort_by(fn(a, b) { b.votes.compare(a.votes) })
  lines
}

///|
/// 霍夫直线变换 float 版本。
pub fn hough_lines_f(
  img : @types.ImageF,
  threshold : Int,
  theta_resolution? : Float = 1.0F,
  rho_resolution? : Float = 1.0F,
) -> Array[HoughLine] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "hough_lines_f: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "hough_lines_f: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "hough_lines_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if threshold <= 0 {
    raise @types.LoadError::DecodeFailed(
      "hough_lines_f: threshold必须大于0",
    )
  }
  if theta_resolution <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "hough_lines_f: theta_resolution必须大于0",
    )
  }
  if rho_resolution <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "hough_lines_f: rho_resolution必须大于0",
    )
  }
  let w = img.width
  let h = img.height
  let ch = img.channels
  let n_theta = (180.0F / theta_resolution).to_int()
  let diag = Float::from_int(w * w + h * h).sqrt()
  let max_rho = (diag / rho_resolution).to_int() + 1
  let n_rho = 2 * max_rho + 1
  let accumulator : Array[Int] = Array::make(n_rho * n_theta, 0)
  let cos_table : Array[Float] = Array::make(n_theta, 0.0F)
  let sin_table : Array[Float] = Array::make(n_theta, 0.0F)
  let angle_scale = theta_resolution * 3.141592653589793F / 180.0F
  for t in 0..<n_theta {
    let angle = Float::from_int(t) * angle_scale
    cos_table[t] = @math.cosf(angle)
    sin_table[t] = @math.sinf(angle)
  }
  let inv_rho_res = 1.0F / rho_resolution
  let rho_max_idx = n_rho - 1
  let data_f : Array[Float] = Array::make(w * h, 0.0F)
  for i in 0..<(w * h) {
    let bits = img.data[i * ch * 4].to_int() |
      (img.data[i * ch * 4 + 1].to_int() << 8) |
      (img.data[i * ch * 4 + 2].to_int() << 16) |
      (img.data[i * ch * 4 + 3].to_int() << 24)
    data_f[i] = Float::reinterpret_from_int(bits)
  }
  for y in 0..<h {
    let fy = Float::from_int(y)
    let row_base = y * w
    for x in 0..<w {
      if data_f[row_base + x] == 0.0F {
        continue
      }
      let fx = Float::from_int(x)
      for t in 0..<n_theta {
        let rho = fx * cos_table[t] + fy * sin_table[t]
        let raw_idx = (rho * inv_rho_res).to_int() + max_rho
        let rho_idx = if raw_idx < 0 {
          0
        } else if raw_idx > rho_max_idx {
          rho_max_idx
        } else {
          raw_idx
        }
        accumulator[rho_idx * n_theta + t] += 1
      }
    }
  }
  let lines : Array[HoughLine] = []
  let max_rho_f = Float::from_int(max_rho)
  for r in 0..<n_rho {
    let row_base = r * n_theta
    for t in 0..<n_theta {
      let votes = accumulator[row_base + t]
      if votes >= threshold {
        let rho = (Float::from_int(r) - max_rho_f) * rho_resolution
        let theta = Float::from_int(t) * angle_scale
        lines.push(HoughLine::{ rho, theta, votes })
      }
    }
  }
  lines.sort_by(fn(a, b) { b.votes.compare(a.votes) })
  lines
}
