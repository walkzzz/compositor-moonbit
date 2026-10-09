// 接缝裁剪（Seam Carving）— 内容感知缩放
// 纯 MoonBit 实现，基于 Avidan & Shamir 2007

///|
/// 计算图像能量图（Sobel 梯度幅值 |Gx| + |Gy|）
pub fn compute_energy(img : @types.Image) -> Array[Double] {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let energy = Array::make(w * h, 0.0)
  for y in 0..<h {
    for x in 0..<w {
      let ym = if y == 0 { 0 } else { y - 1 }
      let yp = if y == h - 1 { h - 1 } else { y + 1 }
      let xm = if x == 0 { 0 } else { x - 1 }
      let xp = if x == w - 1 { w - 1 } else { x + 1 }
      let mut gx = 0.0
      let mut gy = 0.0
      for c in 0..<ch {
        let left = img.data[(y * w + xm) * ch + c].to_int()
        let right = img.data[(y * w + xp) * ch + c].to_int()
        let top = img.data[(ym * w + x) * ch + c].to_int()
        let bottom = img.data[(yp * w + x) * ch + c].to_int()
        gx += (right - left).to_double()
        gy += (bottom - top).to_double()
      }
      let abs_gx = if gx < 0.0 { -gx } else { gx }
      let abs_gy = if gy < 0.0 { -gy } else { gy }
      energy[y * w + x] = abs_gx + abs_gy
    }
  }
  energy
}

///|
/// 找垂直最小能量 seam（返回每行的列索引，长度为 h）
pub fn find_vertical_seam(
  energy : Array[Double],
  w : Int,
  h : Int,
) -> Array[Int] {
  let m = Array::make(w * h, 0.0)
  for j in 0..<w {
    m[j] = energy[j]
  }
  for i in 1..<h {
    for j in 0..<w {
      let mut min_prev = m[(i - 1) * w + j]
      if j > 0 {
        let v = m[(i - 1) * w + j - 1]
        if v < min_prev {
          min_prev = v
        }
      }
      if j < w - 1 {
        let v = m[(i - 1) * w + j + 1]
        if v < min_prev {
          min_prev = v
        }
      }
      m[i * w + j] = energy[i * w + j] + min_prev
    }
  }
  let seam = Array::make(h, 0)
  let mut min_val = m[(h - 1) * w]
  let mut min_j = 0
  for j in 1..<w {
    let v = m[(h - 1) * w + j]
    if v < min_val {
      min_val = v
      min_j = j
    }
  }
  seam[h - 1] = min_j
  for i in 1..<h {
    let row = h - i
    let prev_j = seam[row]
    let mut best_j = prev_j
    let mut best_val = m[(row - 1) * w + prev_j]
    if prev_j > 0 {
      let v = m[(row - 1) * w + prev_j - 1]
      if v < best_val {
        best_val = v
        best_j = prev_j - 1
      }
    }
    if prev_j < w - 1 {
      let v = m[(row - 1) * w + prev_j + 1]
      if v < best_val {
        best_val = v
        best_j = prev_j + 1
      }
    }
    seam[row - 1] = best_j
  }
  seam
}

///|
/// 移除垂直 seam，宽度减 1
pub fn remove_vertical_seam(
  img : @types.Image,
  seam : Array[Int],
) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let new_w = w - 1
  let out : Array[Byte] = Array::make(new_w * h * ch, b'\x00')
  for y in 0..<h {
    let seam_x = seam[y]
    let dst_row = y * new_w * ch
    let src_row = y * w * ch
    for x in 0..<seam_x {
      for c in 0..<ch {
        out[dst_row + x * ch + c] = img.data[src_row + x * ch + c]
      }
    }
    for x in seam_x..<new_w {
      for c in 0..<ch {
        out[dst_row + x * ch + c] = img.data[src_row + (x + 1) * ch + c]
      }
    }
  }
  @types.Image::{
    width: new_w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 找水平最小能量 seam（返回每列的行索引，长度为 w）
pub fn find_horizontal_seam(
  energy : Array[Double],
  w : Int,
  h : Int,
) -> Array[Int] {
  let m = Array::make(w * h, 0.0)
  for i in 0..<h {
    for j in 0..<w {
      m[i * w + j] = energy[i * w + j]
    }
  }
  for j in 1..<w {
    for i in 0..<h {
      let mut min_prev = m[i * w + j - 1]
      if i > 0 {
        let v = m[(i - 1) * w + j - 1]
        if v < min_prev {
          min_prev = v
        }
      }
      if i < h - 1 {
        let v = m[(i + 1) * w + j - 1]
        if v < min_prev {
          min_prev = v
        }
      }
      m[i * w + j] = energy[i * w + j] + min_prev
    }
  }
  let seam = Array::make(w, 0)
  let mut min_val = m[w - 1]
  let mut min_i = 0
  for i in 1..<h {
    let v = m[i * w + w - 1]
    if v < min_val {
      min_val = v
      min_i = i
    }
  }
  seam[w - 1] = min_i
  for j in 1..<w {
    let col = w - j
    let prev_i = seam[col]
    let mut best_i = prev_i
    let mut best_val = m[prev_i * w + col - 1]
    if prev_i > 0 {
      let v = m[(prev_i - 1) * w + col - 1]
      if v < best_val {
        best_val = v
        best_i = prev_i - 1
      }
    }
    if prev_i < h - 1 {
      let v = m[(prev_i + 1) * w + col - 1]
      if v < best_val {
        best_val = v
        best_i = prev_i + 1
      }
    }
    seam[col - 1] = best_i
  }
  seam
}

///|
/// 移除水平 seam，高度减 1
pub fn remove_horizontal_seam(
  img : @types.Image,
  seam : Array[Int],
) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let new_h = h - 1
  let out : Array[Byte] = Array::make(w * new_h * ch, b'\x00')
  for x in 0..<w {
    let seam_y = seam[x]
    for y in 0..<seam_y {
      for c in 0..<ch {
        out[(y * w + x) * ch + c] = img.data[(y * w + x) * ch + c]
      }
    }
    for y in seam_y..<new_h {
      for c in 0..<ch {
        out[(y * w + x) * ch + c] = img.data[((y + 1) * w + x) * ch + c]
      }
    }
  }
  @types.Image::{
    width: w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 插入垂直 seam，宽度加 1
fn insert_vertical_seam(img : @types.Image, seam : Array[Int]) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let new_w = w + 1
  let out : Array[Byte] = Array::make(new_w * h * ch, b'\x00')
  for y in 0..<h {
    let seam_x = seam[y]
    let dst_row = y * new_w * ch
    let src_row = y * w * ch
    for x in 0..<seam_x {
      for c in 0..<ch {
        out[dst_row + x * ch + c] = img.data[src_row + x * ch + c]
      }
    }
    for c in 0..<ch {
      out[dst_row + seam_x * ch + c] = img.data[src_row + seam_x * ch + c]
    }
    for x in seam_x..<w {
      for c in 0..<ch {
        out[dst_row + (x + 1) * ch + c] = img.data[src_row + x * ch + c]
      }
    }
  }
  @types.Image::{
    width: new_w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 插入水平 seam，高度加 1
fn insert_horizontal_seam(
  img : @types.Image,
  seam : Array[Int],
) -> @types.Image {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let new_h = h + 1
  let out : Array[Byte] = Array::make(w * new_h * ch, b'\x00')
  for x in 0..<w {
    let seam_y = seam[x]
    for y in 0..<seam_y {
      for c in 0..<ch {
        out[(y * w + x) * ch + c] = img.data[(y * w + x) * ch + c]
      }
    }
    for c in 0..<ch {
      out[(seam_y * w + x) * ch + c] = img.data[(seam_y * w + x) * ch + c]
    }
    for y in seam_y..<h {
      for c in 0..<ch {
        out[((y + 1) * w + x) * ch + c] = img.data[(y * w + x) * ch + c]
      }
    }
  }
  @types.Image::{
    width: w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 内容感知缩放（Seam Carving）
/// 支持缩小和放大，放大上限为原尺寸 2 倍
pub fn seam_carve_resize(
  img : @types.Image,
  new_w : Int,
  new_h : Int,
) -> @types.Image raise @types.LoadError {
  if new_w <= 0 || new_h <= 0 {
    raise @types.LoadError::DecodeFailed("目标尺寸必须为正数")
  }
  if new_w > img.width * 2 || new_h > img.height * 2 {
    raise @types.LoadError::DecodeFailed("放大不能超过原尺寸的 2 倍")
  }
  let mut result = img
  while result.width > new_w {
    let energy = compute_energy(result)
    let seam = find_vertical_seam(energy, result.width, result.height)
    result = remove_vertical_seam(result, seam)
  }
  while result.width < new_w {
    let energy = compute_energy(result)
    let seam = find_vertical_seam(energy, result.width, result.height)
    result = insert_vertical_seam(result, seam)
  }
  while result.height > new_h {
    let energy = compute_energy(result)
    let seam = find_horizontal_seam(energy, result.width, result.height)
    result = remove_horizontal_seam(result, seam)
  }
  while result.height < new_h {
    let energy = compute_energy(result)
    let seam = find_horizontal_seam(energy, result.width, result.height)
    result = insert_horizontal_seam(result, seam)
  }
  result
}
