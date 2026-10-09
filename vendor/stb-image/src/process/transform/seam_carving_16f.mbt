// 接缝裁剪（Seam Carving）16-bit/float 变体

///|
/// 计算图像能量图 16-bit 版本
pub fn compute_energy_16(img : @types.Image16) -> Array[Double] {
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
        let left = img.data[((y * w + xm) * ch + c) * 2].to_int() |
          (img.data[((y * w + xm) * ch + c) * 2 + 1].to_int() << 8)
        let right = img.data[((y * w + xp) * ch + c) * 2].to_int() |
          (img.data[((y * w + xp) * ch + c) * 2 + 1].to_int() << 8)
        let top = img.data[((ym * w + x) * ch + c) * 2].to_int() |
          (img.data[((ym * w + x) * ch + c) * 2 + 1].to_int() << 8)
        let bottom = img.data[((yp * w + x) * ch + c) * 2].to_int() |
          (img.data[((yp * w + x) * ch + c) * 2 + 1].to_int() << 8)
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
/// 计算图像能量图 float 版本
pub fn compute_energy_f(img : @types.ImageF) -> Array[Double] {
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
        let left_bits = img.data[((y * w + xm) * ch + c) * 4].to_int() |
          (img.data[((y * w + xm) * ch + c) * 4 + 1].to_int() << 8) |
          (img.data[((y * w + xm) * ch + c) * 4 + 2].to_int() << 16) |
          (img.data[((y * w + xm) * ch + c) * 4 + 3].to_int() << 24)
        let right_bits = img.data[((y * w + xp) * ch + c) * 4].to_int() |
          (img.data[((y * w + xp) * ch + c) * 4 + 1].to_int() << 8) |
          (img.data[((y * w + xp) * ch + c) * 4 + 2].to_int() << 16) |
          (img.data[((y * w + xp) * ch + c) * 4 + 3].to_int() << 24)
        let top_bits = img.data[((ym * w + x) * ch + c) * 4].to_int() |
          (img.data[((ym * w + x) * ch + c) * 4 + 1].to_int() << 8) |
          (img.data[((ym * w + x) * ch + c) * 4 + 2].to_int() << 16) |
          (img.data[((ym * w + x) * ch + c) * 4 + 3].to_int() << 24)
        let bottom_bits = img.data[((yp * w + x) * ch + c) * 4].to_int() |
          (img.data[((yp * w + x) * ch + c) * 4 + 1].to_int() << 8) |
          (img.data[((yp * w + x) * ch + c) * 4 + 2].to_int() << 16) |
          (img.data[((yp * w + x) * ch + c) * 4 + 3].to_int() << 24)
        let left = Float::reinterpret_from_int(left_bits)
        let right = Float::reinterpret_from_int(right_bits)
        let top = Float::reinterpret_from_int(top_bits)
        let bottom = Float::reinterpret_from_int(bottom_bits)
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
/// 移除垂直 seam 16-bit 版本
pub fn remove_vertical_seam_16(
  img : @types.Image16,
  seam : Array[Int],
) -> @types.Image16 {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let new_w = w - 1
  let out : Array[Byte] = Array::make(new_w * h * ch * 2, b'\x00')
  for y in 0..<h {
    let seam_x = seam[y]
    for x in 0..<seam_x {
      for c in 0..<ch {
        out[((y * new_w + x) * ch + c) * 2] = img.data[((y * w + x) * ch + c) *
          2]
        out[((y * new_w + x) * ch + c) * 2 + 1] = img.data[(
            (y * w + x) * ch + c
          ) *
          2 +
          1]
      }
    }
    for x in seam_x..<new_w {
      for c in 0..<ch {
        out[((y * new_w + x) * ch + c) * 2] = img.data[(
            (y * w + x + 1) * ch + c
          ) *
          2]
        out[((y * new_w + x) * ch + c) * 2 + 1] = img.data[(
            (y * w + x + 1) * ch + c
          ) *
          2 +
          1]
      }
    }
  }
  @types.Image16::{
    width: new_w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 移除垂直 seam float 版本
pub fn remove_vertical_seam_f(
  img : @types.ImageF,
  seam : Array[Int],
) -> @types.ImageF {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let new_w = w - 1
  let out : Array[Byte] = Array::make(new_w * h * ch * 4, b'\x00')
  for y in 0..<h {
    let seam_x = seam[y]
    for x in 0..<seam_x {
      for c in 0..<ch {
        for b in 0..<4 {
          out[((y * new_w + x) * ch + c) * 4 + b] = img.data[(
              (y * w + x) * ch + c
            ) *
            4 +
            b]
        }
      }
    }
    for x in seam_x..<new_w {
      for c in 0..<ch {
        for b in 0..<4 {
          out[((y * new_w + x) * ch + c) * 4 + b] = img.data[(
              (y * w + x + 1) * ch + c
            ) *
            4 +
            b]
        }
      }
    }
  }
  @types.ImageF::{
    width: new_w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 移除水平 seam 16-bit 版本
pub fn remove_horizontal_seam_16(
  img : @types.Image16,
  seam : Array[Int],
) -> @types.Image16 {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let new_h = h - 1
  let out : Array[Byte] = Array::make(w * new_h * ch * 2, b'\x00')
  for x in 0..<w {
    let seam_y = seam[x]
    for y in 0..<seam_y {
      for c in 0..<ch {
        out[((y * w + x) * ch + c) * 2] = img.data[((y * w + x) * ch + c) * 2]
        out[((y * w + x) * ch + c) * 2 + 1] = img.data[((y * w + x) * ch + c) *
          2 +
          1]
      }
    }
    for y in seam_y..<new_h {
      for c in 0..<ch {
        out[((y * w + x) * ch + c) * 2] = img.data[(((y + 1) * w + x) * ch + c) *
          2]
        out[((y * w + x) * ch + c) * 2 + 1] = img.data[(
            ((y + 1) * w + x) * ch + c
          ) *
          2 +
          1]
      }
    }
  }
  @types.Image16::{
    width: w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 移除水平 seam float 版本
pub fn remove_horizontal_seam_f(
  img : @types.ImageF,
  seam : Array[Int],
) -> @types.ImageF {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let new_h = h - 1
  let out : Array[Byte] = Array::make(w * new_h * ch * 4, b'\x00')
  for x in 0..<w {
    let seam_y = seam[x]
    for y in 0..<seam_y {
      for c in 0..<ch {
        for b in 0..<4 {
          out[((y * w + x) * ch + c) * 4 + b] = img.data[((y * w + x) * ch + c) *
            4 +
            b]
        }
      }
    }
    for y in seam_y..<new_h {
      for c in 0..<ch {
        for b in 0..<4 {
          out[((y * w + x) * ch + c) * 4 + b] = img.data[(
              ((y + 1) * w + x) * ch + c
            ) *
            4 +
            b]
        }
      }
    }
  }
  @types.ImageF::{
    width: w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 插入垂直 seam 16-bit 版本
fn insert_vertical_seam_16(
  img : @types.Image16,
  seam : Array[Int],
) -> @types.Image16 {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let new_w = w + 1
  let out : Array[Byte] = Array::make(new_w * h * ch * 2, b'\x00')
  for y in 0..<h {
    let seam_x = seam[y]
    for x in 0..<seam_x {
      for c in 0..<ch {
        out[((y * new_w + x) * ch + c) * 2] = img.data[((y * w + x) * ch + c) *
          2]
        out[((y * new_w + x) * ch + c) * 2 + 1] = img.data[(
            (y * w + x) * ch + c
          ) *
          2 +
          1]
      }
    }
    for c in 0..<ch {
      out[((y * new_w + seam_x) * ch + c) * 2] = img.data[(
          (y * w + seam_x) * ch + c
        ) *
        2]
      out[((y * new_w + seam_x) * ch + c) * 2 + 1] = img.data[(
          (y * w + seam_x) * ch + c
        ) *
        2 +
        1]
    }
    for x in seam_x..<w {
      for c in 0..<ch {
        out[((y * new_w + x + 1) * ch + c) * 2] = img.data[(
            (y * w + x) * ch + c
          ) *
          2]
        out[((y * new_w + x + 1) * ch + c) * 2 + 1] = img.data[(
            (y * w + x) * ch + c
          ) *
          2 +
          1]
      }
    }
  }
  @types.Image16::{
    width: new_w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 插入垂直 seam float 版本
fn insert_vertical_seam_f(
  img : @types.ImageF,
  seam : Array[Int],
) -> @types.ImageF {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let new_w = w + 1
  let out : Array[Byte] = Array::make(new_w * h * ch * 4, b'\x00')
  for y in 0..<h {
    let seam_x = seam[y]
    for x in 0..<seam_x {
      for c in 0..<ch {
        for b in 0..<4 {
          out[((y * new_w + x) * ch + c) * 4 + b] = img.data[(
              (y * w + x) * ch + c
            ) *
            4 +
            b]
        }
      }
    }
    for c in 0..<ch {
      for b in 0..<4 {
        out[((y * new_w + seam_x) * ch + c) * 4 + b] = img.data[(
            (y * w + seam_x) * ch + c
          ) *
          4 +
          b]
      }
    }
    for x in seam_x..<w {
      for c in 0..<ch {
        for b in 0..<4 {
          out[((y * new_w + x + 1) * ch + c) * 4 + b] = img.data[(
              (y * w + x) * ch + c
            ) *
            4 +
            b]
        }
      }
    }
  }
  @types.ImageF::{
    width: new_w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 插入水平 seam 16-bit 版本
fn insert_horizontal_seam_16(
  img : @types.Image16,
  seam : Array[Int],
) -> @types.Image16 {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let new_h = h + 1
  let out : Array[Byte] = Array::make(w * new_h * ch * 2, b'\x00')
  for x in 0..<w {
    let seam_y = seam[x]
    for y in 0..<seam_y {
      for c in 0..<ch {
        out[((y * w + x) * ch + c) * 2] = img.data[((y * w + x) * ch + c) * 2]
        out[((y * w + x) * ch + c) * 2 + 1] = img.data[((y * w + x) * ch + c) *
          2 +
          1]
      }
    }
    for c in 0..<ch {
      out[((seam_y * w + x) * ch + c) * 2] = img.data[(
          (seam_y * w + x) * ch + c
        ) *
        2]
      out[((seam_y * w + x) * ch + c) * 2 + 1] = img.data[(
          (seam_y * w + x) * ch + c
        ) *
        2 +
        1]
    }
    for y in seam_y..<h {
      for c in 0..<ch {
        out[(((y + 1) * w + x) * ch + c) * 2] = img.data[((y * w + x) * ch + c) *
          2]
        out[(((y + 1) * w + x) * ch + c) * 2 + 1] = img.data[(
            (y * w + x) * ch + c
          ) *
          2 +
          1]
      }
    }
  }
  @types.Image16::{
    width: w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 插入水平 seam float 版本
fn insert_horizontal_seam_f(
  img : @types.ImageF,
  seam : Array[Int],
) -> @types.ImageF {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let new_h = h + 1
  let out : Array[Byte] = Array::make(w * new_h * ch * 4, b'\x00')
  for x in 0..<w {
    let seam_y = seam[x]
    for y in 0..<seam_y {
      for c in 0..<ch {
        for b in 0..<4 {
          out[((y * w + x) * ch + c) * 4 + b] = img.data[((y * w + x) * ch + c) *
            4 +
            b]
        }
      }
    }
    for c in 0..<ch {
      for b in 0..<4 {
        out[((seam_y * w + x) * ch + c) * 4 + b] = img.data[(
            (seam_y * w + x) * ch + c
          ) *
          4 +
          b]
      }
    }
    for y in seam_y..<h {
      for c in 0..<ch {
        for b in 0..<4 {
          out[(((y + 1) * w + x) * ch + c) * 4 + b] = img.data[(
              (y * w + x) * ch + c
            ) *
            4 +
            b]
        }
      }
    }
  }
  @types.ImageF::{
    width: w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 内容感知缩放 16-bit 版本
pub fn seam_carve_resize_16(
  img : @types.Image16,
  new_w : Int,
  new_h : Int,
) -> @types.Image16 raise @types.LoadError {
  if new_w <= 0 || new_h <= 0 {
    raise @types.LoadError::DecodeFailed("目标尺寸必须为正数")
  }
  if new_w > img.width * 2 || new_h > img.height * 2 {
    raise @types.LoadError::DecodeFailed("放大不能超过原尺寸的 2 倍")
  }
  let mut result = img
  while result.width > new_w {
    let energy = compute_energy_16(result)
    let seam = find_vertical_seam(energy, result.width, result.height)
    result = remove_vertical_seam_16(result, seam)
  }
  while result.width < new_w {
    let energy = compute_energy_16(result)
    let seam = find_vertical_seam(energy, result.width, result.height)
    result = insert_vertical_seam_16(result, seam)
  }
  while result.height > new_h {
    let energy = compute_energy_16(result)
    let seam = find_horizontal_seam(energy, result.width, result.height)
    result = remove_horizontal_seam_16(result, seam)
  }
  while result.height < new_h {
    let energy = compute_energy_16(result)
    let seam = find_horizontal_seam(energy, result.width, result.height)
    result = insert_horizontal_seam_16(result, seam)
  }
  result
}

///|
/// 内容感知缩放 float 版本
pub fn seam_carve_resize_f(
  img : @types.ImageF,
  new_w : Int,
  new_h : Int,
) -> @types.ImageF raise @types.LoadError {
  if new_w <= 0 || new_h <= 0 {
    raise @types.LoadError::DecodeFailed("目标尺寸必须为正数")
  }
  if new_w > img.width * 2 || new_h > img.height * 2 {
    raise @types.LoadError::DecodeFailed("放大不能超过原尺寸的 2 倍")
  }
  let mut result = img
  while result.width > new_w {
    let energy = compute_energy_f(result)
    let seam = find_vertical_seam(energy, result.width, result.height)
    result = remove_vertical_seam_f(result, seam)
  }
  while result.width < new_w {
    let energy = compute_energy_f(result)
    let seam = find_vertical_seam(energy, result.width, result.height)
    result = insert_vertical_seam_f(result, seam)
  }
  while result.height > new_h {
    let energy = compute_energy_f(result)
    let seam = find_horizontal_seam(energy, result.width, result.height)
    result = remove_horizontal_seam_f(result, seam)
  }
  while result.height < new_h {
    let energy = compute_energy_f(result)
    let seam = find_horizontal_seam(energy, result.width, result.height)
    result = insert_horizontal_seam_f(result, seam)
  }
  result
}
