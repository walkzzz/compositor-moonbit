// 霍夫圆检测 16-bit/float 变体

///|
/// 霍夫圆检测 16-bit 版本。
pub fn hough_circles_16(
  img : @types.Image16,
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
      "hough_circles_16: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "hough_circles_16: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels * 2
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "hough_circles_16: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if dp < 1 {
    raise @types.LoadError::DecodeFailed("hough_circles_16: dp必须 >= 1")
  }
  if min_dist < 1 {
    raise @types.LoadError::DecodeFailed(
      "hough_circles_16: min_dist必须 >= 1",
    )
  }
  if param1 <= 0 {
    raise @types.LoadError::DecodeFailed(
      "hough_circles_16: param1必须大于0",
    )
  }
  if param2 <= 0 {
    raise @types.LoadError::DecodeFailed(
      "hough_circles_16: param2必须大于0",
    )
  }
  if min_radius < 0 {
    raise @types.LoadError::DecodeFailed(
      "hough_circles_16: min_radius必须 >= 0",
    )
  }
  if max_radius < 0 {
    raise @types.LoadError::DecodeFailed(
      "hough_circles_16: max_radius必须 >= 0",
    )
  }
  let w = img.width
  let h = img.height
  let n = w * h
  if n == 0 {
    return []
  }
  ignore(dp)
  let ch = img.channels
  let gray : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    gray[i] = if ch == 1 {
      img.data[i * 2].to_int() | (img.data[i * 2 + 1].to_int() << 8)
    } else {
      let r = img.data[i * ch * 2].to_int() |
        (img.data[i * ch * 2 + 1].to_int() << 8)
      let g = img.data[(i * ch + 1) * 2].to_int() |
        (img.data[(i * ch + 1) * 2 + 1].to_int() << 8)
      let b = img.data[(i * ch + 2) * 2].to_int() |
        (img.data[(i * ch + 2) * 2 + 1].to_int() << 8)
      (r * 299 + g * 587 + b * 114) / 1000
    }
  }
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
  let r_max = if max_radius > 0 { max_radius } else { (w + h) / 4 }
  let r_min = min_radius
  if r_max <= r_min {
    return []
  }
  let acc_w = w
  let acc_h = h
  let num_r = r_max - r_min + 1
  let acc : Array[Int] = Array::make(acc_w * acc_h * num_r, 0)
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let mag = gx[idx] * gx[idx] + gy[idx] * gy[idx]
      if mag < param1 * param1 {
        continue
      }
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
  candidates.sort_by(fn(a, b) { b.votes.compare(a.votes) })
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

///|
/// 霍夫圆检测 float 版本。
pub fn hough_circles_f(
  img : @types.ImageF,
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
      "hough_circles_f: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "hough_circles_f: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels * 4
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "hough_circles_f: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if dp < 1 {
    raise @types.LoadError::DecodeFailed("hough_circles_f: dp必须 >= 1")
  }
  if min_dist < 1 {
    raise @types.LoadError::DecodeFailed("hough_circles_f: min_dist必须 >= 1")
  }
  if param1 <= 0 {
    raise @types.LoadError::DecodeFailed("hough_circles_f: param1必须大于0")
  }
  if param2 <= 0 {
    raise @types.LoadError::DecodeFailed("hough_circles_f: param2必须大于0")
  }
  if min_radius < 0 {
    raise @types.LoadError::DecodeFailed(
      "hough_circles_f: min_radius必须 >= 0",
    )
  }
  if max_radius < 0 {
    raise @types.LoadError::DecodeFailed(
      "hough_circles_f: max_radius必须 >= 0",
    )
  }
  let w = img.width
  let h = img.height
  let n = w * h
  if n == 0 {
    return []
  }
  ignore(dp)
  let ch = img.channels
  let gray : Array[Float] = Array::make(n, 0.0F)
  for i in 0..<n {
    gray[i] = if ch == 1 {
      let bits = img.data[i * 4].to_int() |
        (img.data[i * 4 + 1].to_int() << 8) |
        (img.data[i * 4 + 2].to_int() << 16) |
        (img.data[i * 4 + 3].to_int() << 24)
      Float::reinterpret_from_int(bits)
    } else {
      let bits_r = img.data[i * ch * 4].to_int() |
        (img.data[i * ch * 4 + 1].to_int() << 8) |
        (img.data[i * ch * 4 + 2].to_int() << 16) |
        (img.data[i * ch * 4 + 3].to_int() << 24)
      let bits_g = img.data[(i * ch + 1) * 4].to_int() |
        (img.data[(i * ch + 1) * 4 + 1].to_int() << 8) |
        (img.data[(i * ch + 1) * 4 + 2].to_int() << 16) |
        (img.data[(i * ch + 1) * 4 + 3].to_int() << 24)
      let bits_b = img.data[(i * ch + 2) * 4].to_int() |
        (img.data[(i * ch + 2) * 4 + 1].to_int() << 8) |
        (img.data[(i * ch + 2) * 4 + 2].to_int() << 16) |
        (img.data[(i * ch + 2) * 4 + 3].to_int() << 24)
      Float::reinterpret_from_int(bits_r) * 0.299F +
      Float::reinterpret_from_int(bits_g) * 0.587F +
      Float::reinterpret_from_int(bits_b) * 0.114F
    }
  }
  let gx : Array[Float] = Array::make(n, 0.0F)
  let gy : Array[Float] = Array::make(n, 0.0F)
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      gx[idx] = gray[(y - 1) * w + (x + 1)] +
        2.0F * gray[y * w + (x + 1)] +
        gray[(y + 1) * w + (x + 1)] -
        gray[(y - 1) * w + (x - 1)] -
        2.0F * gray[y * w + (x - 1)] -
        gray[(y + 1) * w + (x - 1)]
      gy[idx] = gray[(y + 1) * w + (x - 1)] +
        2.0F * gray[(y + 1) * w + x] +
        gray[(y + 1) * w + (x + 1)] -
        gray[(y - 1) * w + (x - 1)] -
        2.0F * gray[(y - 1) * w + x] -
        gray[(y - 1) * w + (x + 1)]
    }
  }
  let r_max = if max_radius > 0 { max_radius } else { (w + h) / 4 }
  let r_min = min_radius
  if r_max <= r_min {
    return []
  }
  let acc_w = w
  let acc_h = h
  let num_r = r_max - r_min + 1
  let acc : Array[Int] = Array::make(acc_w * acc_h * num_r, 0)
  let param1_f = Float::from_int(param1) / 255.0F
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let mag = gx[idx] * gx[idx] + gy[idx] * gy[idx]
      if mag < param1_f * param1_f {
        continue
      }
      let dx = gx[idx]
      let dy = gy[idx]
      let mag_sqrt = mag.sqrt()
      if mag_sqrt == 0.0F {
        continue
      }
      for r in r_min..<=r_max {
        let cx_pos = x + (dx * Float::from_int(r) / mag_sqrt).to_int()
        let cy_pos = y + (dy * Float::from_int(r) / mag_sqrt).to_int()
        let cx_neg = x - (dx * Float::from_int(r) / mag_sqrt).to_int()
        let cy_neg = y - (dy * Float::from_int(r) / mag_sqrt).to_int()
        if cx_pos >= 0 && cx_pos < acc_w && cy_pos >= 0 && cy_pos < acc_h {
          acc[(cy_pos * acc_w + cx_pos) * num_r + (r - r_min)] += 1
        }
        if cx_neg >= 0 && cx_neg < acc_w && cy_neg >= 0 && cy_neg < acc_h {
          acc[(cy_neg * acc_w + cx_neg) * num_r + (r - r_min)] += 1
        }
      }
    }
  }
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
  candidates.sort_by(fn(a, b) { b.votes.compare(a.votes) })
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
