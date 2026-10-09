// 图像修复（纯 MoonBit）
// 基于扩散法：对掩码区域求解 Laplace 方程
// 已知像素作为 Dirichlet 边界条件，迭代至收敛
// 参考: Bertalmio et al., "Image Inpainting" (2000)

///|
/// 图像修复。
/// mask 为单通道掩码图像：0=已知像素，非0=待修复像素。
/// iterations 控制最大迭代次数（默认100）。
/// 适用于灰度图（channels=1）或 RGB/RGBA 图（channels=3/4）。
pub fn inpaint(
  img : @types.Image,
  mask : @types.Image,
  iterations? : Int = 100,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("inpaint: 图像尺寸必须大于0")
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed("inpaint: 通道数必须在1-4之间")
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "inpaint: 图像数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if img.width != mask.width || img.height != mask.height {
    raise @types.LoadError::DecodeFailed(
      "inpaint: 掩码尺寸必须与图像一致",
    )
  }
  if mask.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "inpaint: 掩码必须为单通道图像",
    )
  }
  let mask_expected_size = mask.width * mask.height
  if mask.data.length() != mask_expected_size {
    raise @types.LoadError::DecodeFailed(
      "inpaint: 掩码数据大小不匹配，期望 " +
      mask_expected_size.to_string() +
      "，实际 " +
      mask.data.length().to_string(),
    )
  }
  if iterations <= 0 {
    raise @types.LoadError::DecodeFailed("inpaint: iterations必须大于0")
  }
  let w = img.width
  let h = img.height
  let ch = img.channels
  let n = w * h
  // 构建待修复标记
  let unknown : Array[Bool] = Array::make(n, false)
  let mut has_unknown = false
  for i in 0..<n {
    if mask.data[i] != b'\x00' {
      unknown[i] = true
      has_unknown = true
    }
  }
  // 若无待修复像素，直接返回原图
  if !has_unknown {
    return img
  }
  // 复制原图数据
  let out : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    out[i] = img.data[i].to_int()
  }
  // Jacobi 迭代求解 Laplace 方程
  for _ in 0..<iterations {
    let prev = out.copy()
    let mut changed = false
    for y in 0..<h {
      for x in 0..<w {
        let idx = y * w + x
        if !unknown[idx] {
          continue
        }
        // 收集 8 邻域中已知/已更新像素
        for c in 0..<ch {
          let mut sum = 0
          let mut count = 0
          for dy in -1..<=1 {
            let ny = y + dy
            if ny < 0 || ny >= h {
              continue
            }
            for dx in -1..<=1 {
              if dx == 0 && dy == 0 {
                continue
              }
              let nx = x + dx
              if nx < 0 || nx >= w {
                continue
              }
              sum += prev[(ny * w + nx) * ch + c]
              count += 1
            }
          }
          if count > 0 {
            let new_val = sum / count
            if new_val != out[idx * ch + c] {
              changed = true
            }
            out[idx * ch + c] = new_val
          }
        }
      }
    }
    // 收敛检测
    if !changed {
      break
    }
  }
  // 转换输出
  let out_data : Array[Byte] = Array::make(n * ch, b'\x00')
  for i in 0..<(n * ch) {
    out_data[i] = out[i].clamp(min=0, max=255).to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 快速图像修复（基于距离加权平均）。
/// 对每个待修复像素，取周围已知像素的加权平均（距离越近权重越大）。
/// 比 inpaint 快但质量略低，适合小面积修复。
pub fn inpaint_fast(
  img : @types.Image,
  mask : @types.Image,
  radius? : Int = 5,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "inpaint_fast: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "inpaint_fast: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "inpaint_fast: 图像数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if img.width != mask.width || img.height != mask.height {
    raise @types.LoadError::DecodeFailed(
      "inpaint_fast: 掩码尺寸必须与图像一致",
    )
  }
  if mask.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "inpaint_fast: 掩码必须为单通道图像",
    )
  }
  let mask_expected_size = mask.width * mask.height
  if mask.data.length() != mask_expected_size {
    raise @types.LoadError::DecodeFailed(
      "inpaint_fast: 掩码数据大小不匹配，期望 " +
      mask_expected_size.to_string() +
      "，实际 " +
      mask.data.length().to_string(),
    )
  }
  if radius <= 0 {
    raise @types.LoadError::DecodeFailed("inpaint_fast: radius必须大于0")
  }
  let w = img.width
  let h = img.height
  let ch = img.channels
  let n = w * h
  let r = radius
  // 复制原图数据
  let out : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    out[i] = img.data[i].to_int()
  }
  // 对每个待修复像素，用已知像素加权平均
  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x
      if mask.data[idx] == b'\x00' {
        continue
      }
      for c in 0..<ch {
        let mut sum = 0.0F
        let mut weight_sum = 0.0F
        for dy in -r..<=r {
          let ny = y + dy
          if ny < 0 || ny >= h {
            continue
          }
          for dx in -r..<=r {
            if dx == 0 && dy == 0 {
              continue
            }
            let nx = x + dx
            if nx < 0 || nx >= w {
              continue
            }
            let nidx = ny * w + nx
            // 只用已知像素
            if mask.data[nidx] != b'\x00' {
              continue
            }
            let dist = Float::from_int(dx * dx + dy * dy).sqrt()
            let weight = 1.0F / (dist + 1.0F)
            sum += weight * Float::from_int(out[nidx * ch + c])
            weight_sum += weight
          }
        }
        if weight_sum > 0.0F {
          out[idx * ch + c] = (sum / weight_sum).to_int()
        }
      }
    }
  }
  // 转换输出
  let out_data : Array[Byte] = Array::make(n * ch, b'\x00')
  for i in 0..<(n * ch) {
    out_data[i] = out[i].clamp(min=0, max=255).to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out_data),
  }
}
