// 倾斜校正
// 基于霍夫变换的倾斜检测与校正

///|
/// 辅助函数：限制字节范围
fn clamp_byte_deskew(v : Int) -> Byte {
  if v < 0 {
    b'\x00'
  } else if v > 255 {
    b'\xFF'
  } else {
    v.to_byte()
  }
}

///|
/// 检测图像倾斜角度（基于水平投影的方差最大化）
/// 返回角度（度），正值表示顺时针倾斜
pub fn detect_skew_angle(img : @types.Image) -> Double raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_skew_angle: 图像尺寸必须大于0",
    )
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed(
      "detect_skew_angle: 仅支持单通道灰度图",
    )
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "detect_skew_angle: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let w = img.width
  let h = img.height
  let data = img.data
  // 在 -15 到 +15 度范围内搜索最佳倾斜角度
  let mut best_angle = 0.0
  let mut best_variance = 0.0
  let step = 0.5 // 0.5 度步长
  let mut angle = -15.0
  while angle <= 15.0 {
    let variance = projection_variance_at_angle(data, w, h, angle)
    if variance > best_variance {
      best_variance = variance
      best_angle = angle
    }
    angle += step
  }
  best_angle
}

///|
/// 计算指定角度下的水平投影方差
fn projection_variance_at_angle(
  data : Bytes,
  width : Int,
  height : Int,
  angle_deg : Double,
) -> Double {
  let angle_rad = angle_deg * 3.141592653589793 / 180.0
  let cos_a = @math.cos(angle_rad)
  let sin_a = @math.sin(angle_rad)
  // 计算旋转后的图像尺寸
  let new_h = (height.to_double() * cos_a.abs() +
    width.to_double() * sin_a.abs()).to_int() +
    1
  // 计算水平投影
  let projection : Array[Int] = Array::make(new_h, 0)
  for y in 0..<height {
    for x in 0..<width {
      if data[y * width + x].to_int() < 128 {
        // 黑色像素（文字）
        let new_y = ((x.to_double() - width.to_double() / 2.0) * sin_a +
        (y.to_double() - height.to_double() / 2.0) * cos_a +
        new_h.to_double() / 2.0).to_int()
        if new_y >= 0 && new_y < new_h {
          projection[new_y] += 1
        }
      }
    }
  }
  // 计算投影的方差
  let mut sum = 0
  let mut sum_sq = 0
  let mut count = 0
  for i in 0..<new_h {
    sum += projection[i]
    sum_sq += projection[i] * projection[i]
    count += 1
  }
  if count == 0 {
    return 0.0
  }
  let mean = sum.to_double() / count.to_double()
  let variance = sum_sq.to_double() / count.to_double() - mean * mean
  variance
}

///|
/// 倾斜校正（自动检测倾斜角度并旋转）
pub fn deskew(img : @types.Image) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed("deskew: 图像尺寸必须大于0")
  }
  if img.channels != 1 {
    raise @types.LoadError::DecodeFailed("deskew: 仅支持单通道灰度图")
  }
  let expected_size = img.width * img.height
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "deskew: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let angle = detect_skew_angle(img)
  rotate_document(img, -angle)
}

///|
/// 文档旋转（带白色背景填充）
/// angle: 旋转角度（度），正值表示逆时针
pub fn rotate_document(
  img : @types.Image,
  angle : Double,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "rotate_document: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "rotate_document: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "rotate_document: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let w = img.width
  let h = img.height
  let ch = img.channels
  let angle_rad = angle * 3.141592653589793 / 180.0
  let cos_a = @math.cos(angle_rad)
  let sin_a = @math.sin(angle_rad)
  // 计算新图像尺寸
  let new_w = (w.to_double() * cos_a.abs() + h.to_double() * sin_a.abs()).to_int() +
    1
  let new_h = (w.to_double() * sin_a.abs() + h.to_double() * cos_a.abs()).to_int() +
    1
  // 创建白色背景的新图像
  let out : Array[Byte] = Array::make(new_w * new_h * ch, b'\xFF')
  let data = img.data
  // 反向映射：对新图像的每个像素，找到原图像对应的像素
  for y in 0..<new_h {
    for x in 0..<new_w {
      // 相对于中心的坐标
      let cx = x.to_double() - new_w.to_double() / 2.0
      let cy = y.to_double() - new_h.to_double() / 2.0
      // 反向旋转
      let src_x = cx * cos_a + cy * sin_a + w.to_double() / 2.0
      let src_y = -cx * sin_a + cy * cos_a + h.to_double() / 2.0
      // 双线性插值
      let x0 = src_x.to_int()
      let y0 = src_y.to_int()
      let x1 = x0 + 1
      let y1 = y0 + 1
      let fx = src_x - x0.to_double()
      let fy = src_y - y0.to_double()
      if x0 >= 0 && x1 < w && y0 >= 0 && y1 < h {
        for c in 0..<ch {
          let v00 = data[(y0 * w + x0) * ch + c].to_int().to_double()
          let v01 = data[(y0 * w + x1) * ch + c].to_int().to_double()
          let v10 = data[(y1 * w + x0) * ch + c].to_int().to_double()
          let v11 = data[(y1 * w + x1) * ch + c].to_int().to_double()
          // 双线性插值
          let v0 = v00 * (1.0 - fx) + v01 * fx
          let v1 = v10 * (1.0 - fx) + v11 * fx
          let v = v0 * (1.0 - fy) + v1 * fy
          out[(y * new_w + x) * ch + c] = clamp_byte_deskew(v.to_int())
        }
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
