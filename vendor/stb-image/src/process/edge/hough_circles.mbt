// 霍夫圆检测（纯 MoonBit）：hough_circles
// 梯度法：对边缘点沿梯度方向投票

///|
/// 检测到的圆
pub(all) struct Circle {
  x : Int
  y : Int
  radius : Int
  votes : Int
}

///|
/// 霍夫圆检测。
/// dp 为累加器分辨率倒数（1=同分辨率），min_dist 为圆心间最小距离。
/// param1 为 Canny 高阈值，param2 为圆心投票阈值。
pub fn hough_circles(
  img : @types.Image,
  dp? : Int = 1,
  min_dist? : Int = 10,
  param1? : Int = 100,
  param2? : Int = 30,
  min_radius? : Int = 0,
  max_radius? : Int = 0,
) -> Array[Circle] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "hough_circles: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "hough_circles: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "hough_circles: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if dp < 1 {
    raise @types.LoadError::DecodeFailed("hough_circles: dp必须 >= 1")
  }
  if min_dist < 1 {
    raise @types.LoadError::DecodeFailed("hough_circles: min_dist必须 >= 1")
  }
  if param1 <= 0 {
    raise @types.LoadError::DecodeFailed("hough_circles: param1必须大于0")
  }
  if param2 <= 0 {
    raise @types.LoadError::DecodeFailed("hough_circles: param2必须大于0")
  }
  if min_radius < 0 {
    raise @types.LoadError::DecodeFailed("hough_circles: min_radius必须 >= 0")
  }
  if max_radius < 0 {
    raise @types.LoadError::DecodeFailed("hough_circles: max_radius必须 >= 0")
  }
  let w = img.width
  let h = img.height
  let n = w * h
  if n == 0 {
    return []
  }
  ignore(dp)
  // 转灰度
  let gray : Array[Int] = Array::make(n, 0)
  let ch = img.channels
  for i in 0..<n {
    gray[i] = if ch == 1 {
      img.data[i].to_int()
    } else {
      let r = img.data[i * ch].to_int()
      let g = img.data[i * ch + 1].to_int()
      let b = img.data[i * ch + 2].to_int()
      (r * 299 + g * 587 + b * 114) / 1000
    }
  }
  // Sobel 梯度
  let gx : Array[Int] = Array::make(n, 0)
  let gy : Array[Int] = Array::make(n, 0)
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      gx[idx] = gray[(y - 1) * w + (x + 1)] +
        2 * gray[y * w + (x + 1)] +
        gray[(y + 1) * w + (x + 1)] -
        gray[(y - 1) * w + (x - 1)] -
        2 * gray[y * w + (x - 1)] -
        gray[(y + 1) * w + (x - 1)]
      gy[idx] = gray[(y + 1) * w + (x - 1)] +
        2 * gray[(y + 1) * w + x] +
        gray[(y + 1) * w + (x + 1)] -
        gray[(y - 1) * w + (x - 1)] -
        2 * gray[(y - 1) * w + x] -
        gray[(y - 1) * w + (x + 1)]
    }
  }
  // 边缘点（梯度幅值 > param1）
  let r_max = if max_radius > 0 { max_radius } else { (w + h) / 4 }
  let r_min = min_radius
  if r_max <= r_min {
    return []
  }
  // 累加器：3D [w * dp][h * dp][r_max - r_min + 1]
  let acc_w = w
  let acc_h = h
  let num_r = r_max - r_min + 1
  let acc : Array[Int] = Array::make(acc_w * acc_h * num_r, 0)
  // 对每个边缘点投票
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let mag = gx[idx] * gx[idx] + gy[idx] * gy[idx]
      if mag < param1 * param1 {
        continue
      }
      // 沿梯度方向投票
      let dx = gx[idx]
      let dy = gy[idx]
      let mag_sqrt = Float::from_int(mag).sqrt().to_int()
      if mag_sqrt == 0 {
        continue
      }
      for r in r_min..<=r_max {
        let cx_pos = x + dx * r / mag_sqrt
        let cy_pos = y + dy * r / mag_sqrt
        let cx_neg = x - dx * r / mag_sqrt
        let cy_neg = y - dy * r / mag_sqrt
        if cx_pos >= 0 && cx_pos < acc_w && cy_pos >= 0 && cy_pos < acc_h {
          acc[(cy_pos * acc_w + cx_pos) * num_r + (r - r_min)] += 1
        }
        if cx_neg >= 0 && cx_neg < acc_w && cy_neg >= 0 && cy_neg < acc_h {
          acc[(cy_neg * acc_w + cx_neg) * num_r + (r - r_min)] += 1
        }
      }
    }
  }
  // 找峰值
  let candidates : Array[Circle] = []
  for r in r_min..<=r_max {
    for y in 0..<acc_h {
      for x in 0..<acc_w {
        let votes = acc[(y * acc_w + x) * num_r + (r - r_min)]
        if votes >= param2 {
          candidates.push(Circle::{ x, y, radius: r, votes })
        }
      }
    }
  }
  // 按投票数排序（降序）
  candidates.sort_by(fn(a, b) { b.votes.compare(a.votes) })
  // 距离过滤
  let result : Array[Circle] = []
  for c in candidates {
    let mut ok = true
    for r in result {
      let dx = c.x - r.x
      let dy = c.y - r.y
      if dx * dx + dy * dy < min_dist * min_dist {
        ok = false
        break
      }
    }
    if ok {
      result.push(c)
    }
  }
  result
}
