// 非局部均值去噪 NLM（纯 MoonBit）

///|
/// 非局部均值去噪（Non-Local Means）。
/// 通过搜索窗口内相似像素块的加权平均来去噪。
/// 适用于灰度图（channels=1）或 RGB/RGBA 图（channels=3/4）。
/// patch_size 为相似性比较的块半径（默认 3，即 7x7 块）。
/// search_size 为搜索窗口半径（默认 7，即 15x15 窗口）。
/// h 为滤波强度参数（默认 10），越大平滑越强。
pub fn nlm_denoise(
  img : @types.Image,
  patch_size? : Int = 3,
  search_size? : Int = 7,
  h? : Int = 10,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if patch_size < 1 || patch_size > 10 {
    raise @types.LoadError::DecodeFailed("patch_size 必须在 1..10 之间")
  }
  if search_size < 1 || search_size > 20 {
    raise @types.LoadError::DecodeFailed("search_size 必须在 1..20 之间")
  }
  if h < 1 {
    raise @types.LoadError::DecodeFailed("h 必须 >= 1")
  }
  let ch = img.channels
  let w = img.width
  let h_img = img.height
  let n = w * h_img
  if n == 0 {
    return img
  }
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  let h_sq = h * h
  let patch_d = patch_size
  let search_d = search_size
  // 预计算常数
  let patch_area = (2 * patch_d + 1) * (2 * patch_d + 1)
  // 预计算像素 Int 数组，避免重复 .to_int() 转换
  let pixels : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    pixels[i] = img.data[i].to_int()
  }
  let denom = Float::from_int(h_sq * patch_area)
  let early_term = (denom * 6.907755278982137F).to_int()
  let inner_start = search_d + patch_d
  // 内部区域：搜索窗口和块都完全在图像内
  for y in inner_start..<(h_img - inner_start) {
    for x in inner_start..<(w - inner_start) {
      for c in 0..<ch {
        if ch == 4 && c == 3 {
          out[(y * w + x) * ch + 3] = img.data[(y * w + x) * ch + 3]
          continue
        }
        let mut weight_sum = 0.0F
        let mut value_sum = 0.0F
        for sy in (y - search_d)..<=(y + search_d) {
          let row_sy = sy * w
          for sx in (x - search_d)..<=(x + search_d) {
            let dist = patch_distance_inner(
              pixels, x, y, sx, sy, w, ch, c, patch_d, early_term,
            )
            if dist >= early_term {
              continue
            }
            let weight = @math.expf(Float::from_int(-dist) / denom)
            weight_sum += weight
            value_sum += weight *
              Float::from_int(pixels[(row_sy + sx) * ch + c])
          }
        }
        let val = if weight_sum > 0.0F {
          (value_sum / weight_sum).to_int()
        } else {
          pixels[(y * w + x) * ch + c]
        }
        out[(y * w + x) * ch + c] = val.clamp(min=0, max=255).to_byte()
      }
    }
  }
  // 边界区域
  for y in 0..<h_img {
    let y_inner = y >= inner_start && y < h_img - inner_start
    for x in 0..<w {
      if y_inner && x >= inner_start && x < w - inner_start {
        continue
      }
      for c in 0..<ch {
        if ch == 4 && c == 3 {
          out[(y * w + x) * ch + 3] = img.data[(y * w + x) * ch + 3]
          continue
        }
        let mut weight_sum = 0.0F
        let mut value_sum = 0.0F
        let sy_start = if y - search_d < 0 { 0 } else { y - search_d }
        let sy_end = if y + search_d > h_img - 1 {
          h_img - 1
        } else {
          y + search_d
        }
        let sx_start = if x - search_d < 0 { 0 } else { x - search_d }
        let sx_end = if x + search_d > w - 1 { w - 1 } else { x + search_d }
        for sy in sy_start..<=sy_end {
          for sx in sx_start..<=sx_end {
            let dist = patch_distance_fast(
              pixels, x, y, sx, sy, w, h_img, ch, c, patch_d, early_term,
            )
            if dist >= early_term {
              continue
            }
            let weight = @math.expf(Float::from_int(-dist) / denom)
            weight_sum += weight
            value_sum += weight *
              Float::from_int(pixels[(sy * w + sx) * ch + c])
          }
        }
        let val = if weight_sum > 0.0F {
          (value_sum / weight_sum).to_int()
        } else {
          pixels[(y * w + x) * ch + c]
        }
        out[(y * w + x) * ch + c] = val.clamp(min=0, max=255).to_byte()
      }
    }
  }
  @types.Image::{
    width: w,
    height: h_img,
    channels: ch,
    data: Bytes::from_array(out),
  }
}

///|
/// 计算两个像素块之间的平方距离（内部区域，无边界检查）
fn patch_distance_inner(
  pixels : Array[Int],
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  w : Int,
  ch : Int,
  c : Int,
  patch_d : Int,
  early_term : Int,
) -> Int {
  let mut dist = 0
  for dy in -patch_d..<=patch_d {
    let row1 = (y1 + dy) * w
    let row2 = (y2 + dy) * w
    for dx in -patch_d..<=patch_d {
      let v1 = pixels[(row1 + x1 + dx) * ch + c]
      let v2 = pixels[(row2 + x2 + dx) * ch + c]
      let diff = v1 - v2
      dist += diff * diff
      if dist >= early_term {
        return dist
      }
    }
  }
  dist
}

///|
/// 计算两个像素块之间的平方距离（使用预计算 Int 数组，内联边界检查）
fn patch_distance_fast(
  pixels : Array[Int],
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  w : Int,
  h : Int,
  ch : Int,
  c : Int,
  patch_d : Int,
  early_term : Int,
) -> Int {
  let mut dist = 0
  let w_max = w - 1
  let h_max = h - 1
  for dy in -patch_d..<=patch_d {
    for dx in -patch_d..<=patch_d {
      // 内联边界检查，避免 clamp 方法调用
      let raw1x = x1 + dx
      let raw1y = y1 + dy
      let raw2x = x2 + dx
      let raw2y = y2 + dy
      let px1 = if raw1x < 0 {
        0
      } else if raw1x > w_max {
        w_max
      } else {
        raw1x
      }
      let py1 = if raw1y < 0 {
        0
      } else if raw1y > h_max {
        h_max
      } else {
        raw1y
      }
      let px2 = if raw2x < 0 {
        0
      } else if raw2x > w_max {
        w_max
      } else {
        raw2x
      }
      let py2 = if raw2y < 0 {
        0
      } else if raw2y > h_max {
        h_max
      } else {
        raw2y
      }
      let v1 = pixels[(py1 * w + px1) * ch + c]
      let v2 = pixels[(py2 * w + px2) * ch + c]
      let diff = v1 - v2
      dist += diff * diff
      if dist >= early_term {
        return dist
      }
    }
  }
  dist
}

///|

///|
/// 快速 NLM 去噪（降采样搜索）。
/// 使用积分图加速块距离计算，搜索步长 > 1 以加速。
/// 适用于灰度图（channels=1）或 RGB/RGBA 图（channels=3/4）。
pub fn nlm_denoise_fast(
  img : @types.Image,
  patch_size? : Int = 3,
  search_size? : Int = 7,
  h? : Int = 10,
  step? : Int = 2,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_fast: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 && img.channels != 3 && img.channels != 4 {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_fast: 仅支持 channels=1/3/4",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "nlm_denoise_fast: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if patch_size < 1 || patch_size > 10 {
    raise @types.LoadError::DecodeFailed("patch_size 必须在 1..10 之间")
  }
  if search_size < 1 || search_size > 20 {
    raise @types.LoadError::DecodeFailed("search_size 必须在 1..20 之间")
  }
  if h < 1 {
    raise @types.LoadError::DecodeFailed("h 必须 >= 1")
  }
  if step < 1 || step > 5 {
    raise @types.LoadError::DecodeFailed("step 必须在 1..5 之间")
  }
  let ch = img.channels
  let w = img.width
  let h_img = img.height
  let n = w * h_img
  if n == 0 {
    return img
  }
  let out : Array[Byte] = Array::make(n * ch, b'\x00')
  let h_sq = h * h
  let patch_d = patch_size
  let search_d = search_size
  let patch_area = (2 * patch_d + 1) * (2 * patch_d + 1)
  // 预计算像素 Int 数组
  let pixels : Array[Int] = Array::make(n * ch, 0)
  for i in 0..<(n * ch) {
    pixels[i] = img.data[i].to_int()
  }
  let denom = Float::from_int(h_sq * patch_area)
  let early_term = (denom * 6.907755278982137F).to_int()
  let inner_start = search_d + patch_d
  // 内部区域：搜索窗口和块都完全在图像内
  for y in inner_start..<(h_img - inner_start) {
    for x in inner_start..<(w - inner_start) {
      for c in 0..<ch {
        if ch == 4 && c == 3 {
          out[(y * w + x) * ch + 3] = img.data[(y * w + x) * ch + 3]
          continue
        }
        let mut weight_sum = 0.0F
        let mut value_sum = 0.0F
        let mut sy = y - search_d
        let sy_end = y + search_d
        while sy <= sy_end {
          let row_sy = sy * w
          let mut sx = x - search_d
          let sx_end = x + search_d
          while sx <= sx_end {
            let dist = patch_distance_inner(
              pixels, x, y, sx, sy, w, ch, c, patch_d, early_term,
            )
            if dist >= early_term {
              sx += step
              continue
            }
            let weight = @math.expf(Float::from_int(-dist) / denom)
            weight_sum += weight
            value_sum += weight *
              Float::from_int(pixels[(row_sy + sx) * ch + c])
            sx += step
          }
          sy += step
        }
        let val = if weight_sum > 0.0F {
          (value_sum / weight_sum).to_int()
        } else {
          pixels[(y * w + x) * ch + c]
        }
        out[(y * w + x) * ch + c] = val.clamp(min=0, max=255).to_byte()
      }
    }
  }
  // 边界区域
  for y in 0..<h_img {
    let y_inner = y >= inner_start && y < h_img - inner_start
    for x in 0..<w {
      if y_inner && x >= inner_start && x < w - inner_start {
        continue
      }
      for c in 0..<ch {
        if ch == 4 && c == 3 {
          out[(y * w + x) * ch + 3] = img.data[(y * w + x) * ch + 3]
          continue
        }
        let mut weight_sum = 0.0F
        let mut value_sum = 0.0F
        let sy_start = if y - search_d < 0 { 0 } else { y - search_d }
        let sy_end = if y + search_d > h_img - 1 {
          h_img - 1
        } else {
          y + search_d
        }
        let sx_start = if x - search_d < 0 { 0 } else { x - search_d }
        let sx_end = if x + search_d > w - 1 { w - 1 } else { x + search_d }
        let mut sy = sy_start
        while sy <= sy_end {
          let mut sx = sx_start
          while sx <= sx_end {
            let dist = patch_distance_fast(
              pixels, x, y, sx, sy, w, h_img, ch, c, patch_d, early_term,
            )
            if dist >= early_term {
              sx += step
              continue
            }
            let weight = @math.expf(Float::from_int(-dist) / denom)
            weight_sum += weight
            value_sum += weight *
              Float::from_int(pixels[(sy * w + sx) * ch + c])
            sx += step
          }
          sy += step
        }
        let val = if weight_sum > 0.0F {
          (value_sum / weight_sum).to_int()
        } else {
          pixels[(y * w + x) * ch + c]
        }
        out[(y * w + x) * ch + c] = val.clamp(min=0, max=255).to_byte()
      }
    }
  }
  @types.Image::{
    width: w,
    height: h_img,
    channels: ch,
    data: Bytes::from_array(out),
  }
}
