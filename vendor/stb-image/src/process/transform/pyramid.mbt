// 图像金字塔（纯 MoonBit）

///|
/// 高斯金字塔下采样。将图像尺寸减半（宽高各 /2），使用 2x2 均值滤波。
pub fn pyr_down(img : @types.Image) -> @types.Image raise @types.LoadError {
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("pyr_down 仅支持 channels=1/3/4")
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let new_w = w / 2
  let new_h = h / 2
  if new_w == 0 || new_h == 0 {
    raise @types.LoadError::DecodeFailed("图像太小，无法下采样")
  }
  let data_int : Array[Int] = Array::make(w * h * ch, 0)
  for i in 0..<(w * h * ch) {
    data_int[i] = img.data[i].to_int()
  }
  let out : Array[Byte] = Array::make(new_w * new_h * ch, b'\x00')
  for y in 0..<new_h {
    for x in 0..<new_w {
      for c in 0..<ch {
        let mut sum = 0
        let mut count = 0
        for dy in 0..<2 {
          for dx in 0..<2 {
            let sx = x * 2 + dx
            let sy = y * 2 + dy
            if sx < w && sy < h {
              sum += data_int[(sy * w + sx) * ch + c]
              count += 1
            }
          }
        }
        out[(y * new_w + x) * ch + c] = (sum / count).to_byte()
      }
    }
  }
  @types.Image::{
    width: new_w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 拉普拉斯金字塔上采样。将图像尺寸加倍（宽高各 *2），使用双线性插值。
pub fn pyr_up(img : @types.Image) -> @types.Image raise @types.LoadError {
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed("pyr_up 仅支持 channels=1/3/4")
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let new_w = w * 2
  let new_h = h * 2
  let data_int : Array[Int] = Array::make(w * h * ch, 0)
  for i in 0..<(w * h * ch) {
    data_int[i] = img.data[i].to_int()
  }
  // 预计算 x 方向插值参数
  let x0_arr : Array[Int] = Array::make(new_w, 0)
  let x1_arr : Array[Int] = Array::make(new_w, 0)
  let wx_arr : Array[Float] = Array::make(new_w, 0.0F)
  for x in 0..<new_w {
    let fx = (Float::from_int(x) - 0.5F) / 2.0F
    let x0 = fx.to_int().clamp(min=0, max=w - 1)
    x0_arr[x] = x0
    x1_arr[x] = (x0 + 1).clamp(min=0, max=w - 1)
    wx_arr[x] = fx - Float::from_int(x0)
  }
  // 预计算 y 方向插值参数
  let y0_arr : Array[Int] = Array::make(new_h, 0)
  let y1_arr : Array[Int] = Array::make(new_h, 0)
  let wy_arr : Array[Float] = Array::make(new_h, 0.0F)
  for y in 0..<new_h {
    let fy = (Float::from_int(y) - 0.5F) / 2.0F
    let y0 = fy.to_int().clamp(min=0, max=h - 1)
    y0_arr[y] = y0
    y1_arr[y] = (y0 + 1).clamp(min=0, max=h - 1)
    wy_arr[y] = fy - Float::from_int(y0)
  }
  let out : Array[Byte] = Array::make(new_w * new_h * ch, b'\x00')
  for y in 0..<new_h {
    let y0 = y0_arr[y]
    let y1 = y1_arr[y]
    let wy = wy_arr[y]
    let wy_inv = 1.0F - wy
    let row0 = y0 * w
    let row1 = y1 * w
    for x in 0..<new_w {
      let x0 = x0_arr[x]
      let x1 = x1_arr[x]
      let wx = wx_arr[x]
      let wx_inv = 1.0F - wx
      for c in 0..<ch {
        let v00 = Float::from_int(data_int[(row0 + x0) * ch + c])
        let v01 = Float::from_int(data_int[(row0 + x1) * ch + c])
        let v10 = Float::from_int(data_int[(row1 + x0) * ch + c])
        let v11 = Float::from_int(data_int[(row1 + x1) * ch + c])
        let top = v00 * wx_inv + v01 * wx
        let bot = v10 * wx_inv + v11 * wx
        let v = top * wy_inv + bot * wy
        let clamped = if v < 0.0F {
          0
        } else if v > 255.0F {
          255
        } else {
          v.to_int()
        }
        out[(y * new_w + x) * ch + c] = clamped.to_byte()
      }
    }
  }
  @types.Image::{
    width: new_w,
    height: new_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 构建高斯金字塔。返回各级图像（从原图到最小级），levels 为最大层数（0=自动到 1x1）。
pub fn build_gaussian_pyramid(
  img : @types.Image,
  levels : Int,
) -> Array[@types.Image] raise @types.LoadError {
  let result : Array[@types.Image] = [img]
  let mut current = img
  let max_levels = if levels == 0 { 100 } else { levels }
  for _ in 1..<max_levels {
    if current.width < 2 || current.height < 2 {
      break
    }
    current = pyr_down(current)
    result.push(current)
  }
  result
}

///|
/// 构建拉普拉斯金字塔。返回各级拉普拉斯图像（高斯金字塔相邻层之差）。
/// 最后一层为高斯金字塔的最小级（不加差）。
pub fn build_laplacian_pyramid(
  img : @types.Image,
  levels : Int,
) -> Array[@types.Image] raise @types.LoadError {
  let gaussian = build_gaussian_pyramid(img, levels)
  let result : Array[@types.Image] = []
  for i in 0..<(gaussian.length() - 1) {
    let upsampled = pyr_up(gaussian[i + 1])
    let lap = laplacian_diff(gaussian[i], upsampled)
    result.push(lap)
  }
  result.push(gaussian[gaussian.length() - 1])
  result
}

///|
fn laplacian_diff(a : @types.Image, b : @types.Image) -> @types.Image {
  let ch = a.channels
  let w = a.width
  let h = a.height
  let a_int : Array[Int] = Array::make(w * h * ch, 0)
  for i in 0..<(w * h * ch) {
    a_int[i] = a.data[i].to_int()
  }
  let bw = b.width
  let bh = b.height
  let b_int : Array[Int] = Array::make(bw * bh * ch, 0)
  for i in 0..<(bw * bh * ch) {
    b_int[i] = b.data[i].to_int()
  }
  let out : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for y in 0..<h {
    let by = y * bh / h
    for x in 0..<w {
      let bx = x * bw / w
      for c in 0..<ch {
        let va = a_int[(y * w + x) * ch + c]
        let vb = b_int[(by * bw + bx) * ch + c]
        let diff = va - vb + 128
        let clamped = if diff < 0 { 0 } else if diff > 255 { 255 } else { diff }
        out[(y * w + x) * ch + c] = clamped.to_byte()
      }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}
