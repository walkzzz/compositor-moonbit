// 霍夫变换（直线检测，纯 MoonBit）

///|
/// 检测到的直线
pub(all) struct HoughLine {
  rho : Float // 极径（原点到直线的垂直距离）
  theta : Float // 极角（弧度）
  votes : Int // 累加器票数
}

///|
/// 霍夫直线变换。对二值图（非零为边缘点）检测直线。
/// theta_resolution 为角度分辨率（度数，默认 1.0），rho_resolution 为极径分辨率（像素，默认 1.0）。
/// threshold 为最小票数阈值，返回票数 >= threshold 的直线，按票数降序排列。
pub fn hough_lines(
  img : @types.Image,
  threshold : Int,
  theta_resolution? : Float = 1.0F,
  rho_resolution? : Float = 1.0F,
) -> Array[HoughLine] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "hough_lines: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "hough_lines: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "hough_lines: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if threshold <= 0 {
    raise @types.LoadError::DecodeFailed("hough_lines: threshold必须大于0")
  }
  if theta_resolution <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "hough_lines: theta_resolution必须大于0",
    )
  }
  if rho_resolution <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "hough_lines: rho_resolution必须大于0",
    )
  }
  let w = img.width
  let h = img.height
  let ch = img.channels
  // 角度范围 0~180 度
  let n_theta = (180.0F / theta_resolution).to_int()
  let diag = Float::from_int(w * w + h * h).sqrt()
  let max_rho = (diag / rho_resolution).to_int() + 1
  let n_rho = 2 * max_rho + 1
  // 累加器（一维数组，提高缓存友好性）
  let accumulator : Array[Int] = Array::make(n_rho * n_theta, 0)
  // 预计算 sin/cos 表
  let cos_table : Array[Float] = Array::make(n_theta, 0.0F)
  let sin_table : Array[Float] = Array::make(n_theta, 0.0F)
  let angle_scale = theta_resolution * 3.141592653589793F / 180.0F
  for t in 0..<n_theta {
    let angle = Float::from_int(t) * angle_scale
    cos_table[t] = @math.cosf(angle)
    sin_table[t] = @math.sinf(angle)
  }
  // 预计算 1/rho_resolution，用乘法替代除法
  let inv_rho_res = 1.0F / rho_resolution
  let rho_max_idx = n_rho - 1
  // 预计算首通道 to_int（只看第一个通道判断边缘）
  let data_int : Array[Int] = Array::make(w * h, 0)
  for i in 0..<(w * h) {
    data_int[i] = img.data[i * ch].to_int()
  }
  // 遍历边缘点
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
        // 内联 clamp，避免方法调用开销
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
  // 收集结果
  let lines : Array[HoughLine] = []
  let max_rho_f = Float::from_int(max_rho)
  for r in 0..<n_rho {
    let row_base = r * n_theta
    for t in 0..<n_theta {
      let votes = accumulator[row_base + t]
      if votes >= threshold {
        lines.push(HoughLine::{
          rho: (Float::from_int(r) - max_rho_f) * rho_resolution,
          theta: Float::from_int(t) * angle_scale,
          votes,
        })
      }
    }
  }
  // 按票数降序排序
  lines.sort_by(fn(a, b) { b.votes - a.votes })
  lines
}

///|
/// 非极大值抑制。对霍夫变换结果做 NMS，去除相近的重复直线。
pub fn hough_lines_nms(
  lines : Array[HoughLine],
  rho_threshold? : Float = 5.0F,
  theta_threshold? : Float = 0.1F,
) -> Array[HoughLine] raise @types.LoadError {
  // 参数验证
  if rho_threshold <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "hough_lines_nms: rho_threshold必须大于0",
    )
  }
  if theta_threshold <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "hough_lines_nms: theta_threshold必须大于0",
    )
  }

  let result : Array[HoughLine] = []
  let suppressed : Array[Bool] = Array::make(lines.length(), false)
  for i in 0..<lines.length() {
    if suppressed[i] {
      continue
    }
    result.push(lines[i])
    for j in (i + 1)..<lines.length() {
      if suppressed[j] {
        continue
      }
      let dr = (lines[i].rho - lines[j].rho).abs()
      let dt = (lines[i].theta - lines[j].theta).abs()
      if dr < rho_threshold && dt < theta_threshold {
        suppressed[j] = true
      }
    }
  }
  result
}
