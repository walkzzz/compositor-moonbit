// 双边滤波（纯 MoonBit）

///|
/// 双边滤波。保边去噪滤波器，同时考虑空间距离和像素值差异。
/// radius 为滤波半径，sigma_space 为空间高斯标准差，sigma_color 为值域高斯标准差。
/// 仅处理灰度图（channels=1）或 RGB 图（channels=3/4），alpha 通道不变。
pub fn bilateral_filter(
  img : @types.Image,
  radius : Int,
  sigma_space : Float,
  sigma_color : Float,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if radius < 1 {
    raise @types.LoadError::DecodeFailed("bilateral_filter: radius 必须 >= 1")
  }
  if sigma_space <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter: sigma_space必须大于0",
    )
  }
  if sigma_color <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter: sigma_color必须大于0",
    )
  }
  let ch = img.channels
  let color_ch = if ch >= 3 { 3 } else { 1 }
  let w = img.width
  let h = img.height
  let n = w * h
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  let two_sps_sq = 2.0F * sigma_space * sigma_space
  let two_spc_sq = 2.0F * sigma_color * sigma_color
  // 预计算空间权重表（1D 扁平化，提升缓存局部性）
  let sw_size = 2 * radius + 1
  let spatial_weights : Array[Float] = Array::make(sw_size * sw_size, 0.0F)
  for dy in -radius..<=radius {
    for dx in -radius..<=radius {
      let dist_sq = Float::from_int(dx * dx + dy * dy)
      spatial_weights[(dy + radius) * sw_size + (dx + radius)] = @math.expf(
        -dist_sq / two_sps_sq,
      )
    }
  }
  // 预计算像素 Float 数组，避免内层循环重复类型转换
  let src : Array[Float] = Array::make(n * color_ch, 0.0F)
  for i in 0..<n {
    for c in 0..<color_ch {
      src[i * color_ch + c] = Float::from_int(img.data[i * ch + c].to_int())
    }
  }
  // 预计算 color exp 查找表：像素值差 0-255，避免内层循环调用 expf
  let color_lut : Array[Float] = Array::make(256, 0.0F)
  for d in 0..<256 {
    let diff = Float::from_int(d)
    color_lut[d] = @math.expf(-(diff * diff) / two_spc_sq)
  }
  // 分离内部/边界区域：内部区域所有邻居都在图像内，无需边界检查
  let x_inner_start = radius
  let x_inner_end = w - radius
  let y_inner_start = radius
  let y_inner_end = h - radius
  if color_ch == 1 {
    // color_ch=1 特化：消除内层通道循环和乘法
    for y in 0..<h {
      let y_inner = y >= y_inner_start && y < y_inner_end
      for x in 0..<w {
        let center_val = src[y * w + x]
        let mut weight_sum = 0.0F
        let mut value_sum = 0.0F
        if y_inner && x >= x_inner_start && x < x_inner_end {
          for dy in -radius..<=radius {
            let row = (y + dy) * w + x
            let sw_base = (dy + radius) * sw_size
            for dx in -radius..<=radius {
              let neighbor_val = src[row + dx]
              let color_diff = (neighbor_val - center_val).to_int()
              let abs_diff = if color_diff < 0 {
                -color_diff
              } else {
                color_diff
              }
              let weight = spatial_weights[sw_base + dx + radius] *
                color_lut[abs_diff]
              value_sum += neighbor_val * weight
              weight_sum += weight
            }
          }
        } else {
          for dy in -radius..<=radius {
            let ny = y + dy
            if ny < 0 || ny >= h {
              continue
            }
            let sw_base = (dy + radius) * sw_size
            for dx in -radius..<=radius {
              let nx = x + dx
              if nx < 0 || nx >= w {
                continue
              }
              let neighbor_val = src[ny * w + nx]
              let color_diff = (neighbor_val - center_val).to_int()
              let abs_diff = if color_diff < 0 {
                -color_diff
              } else {
                color_diff
              }
              let weight = spatial_weights[sw_base + dx + radius] *
                color_lut[abs_diff]
              value_sum += neighbor_val * weight
              weight_sum += weight
            }
          }
        }
        let v = if weight_sum > 0.0F {
          value_sum / weight_sum
        } else {
          center_val
        }
        let clamped = if v < 0.0F {
          0
        } else if v > 255.0F {
          255
        } else {
          v.to_int()
        }
        out[y * w + x] = clamped.to_byte()
      }
    }
  } else {
    for c in 0..<color_ch {
      for y in 0..<h {
        let y_inner = y >= y_inner_start && y < y_inner_end
        for x in 0..<w {
          let center_idx = (y * w + x) * color_ch + c
          let center_val = src[center_idx]
          let mut weight_sum = 0.0F
          let mut value_sum = 0.0F
          if y_inner && x >= x_inner_start && x < x_inner_end {
            // 内部区域：所有邻居都在图像内
            for dy in -radius..<=radius {
              let row = (y + dy) * w
              let sw_base = (dy + radius) * sw_size
              for dx in -radius..<=radius {
                let neighbor_val = src[(row + x + dx) * color_ch + c]
                let color_diff = (neighbor_val - center_val).to_int()
                let abs_diff = if color_diff < 0 {
                  -color_diff
                } else {
                  color_diff
                }
                let weight = spatial_weights[sw_base + dx + radius] *
                  color_lut[abs_diff]
                value_sum += neighbor_val * weight
                weight_sum += weight
              }
            }
          } else {
            // 边界区域：需要边界检查
            for dy in -radius..<=radius {
              let ny = y + dy
              if ny < 0 || ny >= h {
                continue
              }
              let sw_base = (dy + radius) * sw_size
              for dx in -radius..<=radius {
                let nx = x + dx
                if nx < 0 || nx >= w {
                  continue
                }
                let neighbor_val = src[(ny * w + nx) * color_ch + c]
                let color_diff = (neighbor_val - center_val).to_int()
                let abs_diff = if color_diff < 0 {
                  -color_diff
                } else {
                  color_diff
                }
                let weight = spatial_weights[sw_base + dx + radius] *
                  color_lut[abs_diff]
                value_sum += neighbor_val * weight
                weight_sum += weight
              }
            }
          }
          let v = if weight_sum > 0.0F {
            value_sum / weight_sum
          } else {
            center_val
          }
          let clamped = if v < 0.0F {
            0
          } else if v > 255.0F {
            255
          } else {
            v.to_int()
          }
          out[(y * w + x) * ch + c] = clamped.to_byte()
        }
      }
    }
  }
  if ch == 4 {
    for i in 0..<n {
      out[i * 4 + 3] = img.data[i * 4 + 3]
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 快速双边滤波（使用降采样近似）。适用于大半径场景。
/// downsample 为降采样倍数（1=不降采样，2=降采样到 1/2）。
pub fn bilateral_filter_fast(
  img : @types.Image,
  radius : Int,
  sigma_space : Float,
  sigma_color : Float,
  downsample : Int,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if radius < 1 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast: radius 必须 >= 1",
    )
  }
  if sigma_space <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast: sigma_space必须大于0",
    )
  }
  if sigma_color <= 0.0F {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast: sigma_color必须大于0",
    )
  }
  if downsample < 1 {
    raise @types.LoadError::DecodeFailed(
      "bilateral_filter_fast: downsample必须 >= 1",
    )
  }

  if downsample <= 1 {
    return bilateral_filter(img, radius, sigma_space, sigma_color)
  }
  // 降采样
  let mut small = img
  for _ in 0..<downsample {
    if small.width < 4 || small.height < 4 {
      break
    }
    small = @transform.pyr_down(small)
  }
  // 在小图上做双边滤波
  let small_filtered = bilateral_filter(
    small,
    (radius / downsample).clamp(min=1, max=radius),
    sigma_space,
    sigma_color,
  )
  // 放大回原尺寸
  let mut result = small_filtered
  let target_w = img.width
  let target_h = img.height
  while result.width < target_w || result.height < target_h {
    result = @transform.pyr_up(result)
  }
  // 裁剪到原尺寸
  if result.width != target_w || result.height != target_h {
    crop_bilateral(result, target_w, target_h)
  } else {
    result
  }
}

///|
fn crop_bilateral(img : @types.Image, w : Int, h : Int) -> @types.Image {
  let ch = img.channels
  let out : Array[Byte] = Array::make(w * h * ch, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<ch {
        out[(y * w + x) * ch + c] = img.data[(y * img.width + x) * ch + c]
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
