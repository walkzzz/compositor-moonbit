// 图像修复（v12.0.0）
// 基于快速行进法（Fast Marching Method）的图像修复

///|
/// 图像修复配置
pub(all) struct InpaintConfig {
  radius : Int // 修复半径
  method_type : String // "telea" / "ns"（Navier-Stokes）
  max_iterations : Int // 最大迭代次数
}

///|
/// 创建默认图像修复配置
pub fn inpaint_default_config() -> InpaintConfig {
  InpaintConfig::{ radius: 5, method_type: "telea", max_iterations: 1000 }
}

///|
/// 图像修复（Telea 算法，简化版）
/// 基于快速行进法，从边界向内部逐步修复
pub fn inpaint_advanced(
  img : @types.Image,
  mask : @types.Image,
  radius? : Int = 5,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "inpaint_advanced: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "inpaint_advanced: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "inpaint_advanced: 图像数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if mask.width != img.width || mask.height != img.height {
    raise @types.LoadError::DecodeFailed(
      "inpaint_advanced: 掩码图像尺寸必须与原图一致",
    )
  }
  if mask.channels < 1 {
    raise @types.LoadError::DecodeFailed(
      "inpaint_advanced: 掩码通道数必须大于0",
    )
  }
  if radius <= 0 {
    raise @types.LoadError::DecodeFailed(
      "inpaint_advanced: radius必须大于0",
    )
  }

  let r = radius
  let w = img.width
  let h = img.height
  let channels = img.channels
  let img_data = img.data
  let mask_data = mask.data
  // 复制原图
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  for i in 0..<(w * h * channels) {
    out_data[i] = img_data[i]
  }
  // 标记需要修复的区域（mask 中非零像素）
  let to_inpaint : Array[Bool] = []
  for i in 0..<(w * h) {
    let mask_val = if mask.channels >= 1 {
      mask_data[i * mask.channels].to_int()
    } else {
      0
    }
    to_inpaint.push(mask_val > 128)
  }
  // 快速行进法：迭代修复边界像素
  let mut changed = true
  let mut iteration = 0
  while changed && iteration < 1000 {
    changed = false
    iteration += 1
    // 找到所有待修复区域的边界像素
    let boundary : Array[(Int, Int)] = []
    for y in 0..<h {
      for x in 0..<w {
        if to_inpaint[y * w + x] {
          // 检查是否有已修复的邻域
          let mut has_known_neighbor = false
          let neighbors = [(-1, 0), (1, 0), (0, -1), (0, 1)]
          for _tup0 in neighbors {
            let (dx, dy) = _tup0
            let nx = x + dx
            let ny = y + dy
            if nx >= 0 &&
              nx < w &&
              ny >= 0 &&
              ny < h &&
              !to_inpaint[ny * w + nx] {
              has_known_neighbor = true
            }
          }
          if has_known_neighbor {
            boundary.push((x, y))
          }
        }
      }
    }
    // 对边界像素进行修复
    for _tup1 in boundary {
      let (x, y) = _tup1
      // 计算邻域已知像素的加权平均
      let mut sum_r = 0.0
      let mut sum_g = 0.0
      let mut sum_b = 0.0
      let mut weight_sum = 0.0
      for dy in -r..<(r + 1) {
        for dx in -r..<(r + 1) {
          let nx = x + dx
          let ny = y + dy
          if nx >= 0 && nx < w && ny >= 0 && ny < h && !to_inpaint[ny * w + nx] {
            // 距离加权（越近权重越大）
            let dist = (dx * dx + dy * dy).to_double().sqrt()
            let weight = 1.0 / (dist + 1.0)
            let idx = (ny * w + nx) * channels
            sum_r += out_data[idx].to_double() * weight
            if channels >= 2 {
              sum_g += out_data[idx + 1].to_double() * weight
            }
            if channels >= 3 {
              sum_b += out_data[idx + 2].to_double() * weight
            }
            weight_sum += weight
          }
        }
      }
      if weight_sum > 0.0 {
        let idx = (y * w + x) * channels
        out_data[idx] = (sum_r / weight_sum)
          .min(255.0)
          .max(0.0)
          .to_int()
          .to_byte()
        if channels >= 2 {
          out_data[idx + 1] = (sum_g / weight_sum)
            .min(255.0)
            .max(0.0)
            .to_int()
            .to_byte()
        }
        if channels >= 3 {
          out_data[idx + 2] = (sum_b / weight_sum)
            .min(255.0)
            .max(0.0)
            .to_int()
            .to_byte()
        }
        if channels >= 4 {
          out_data[idx + 3] = img_data[idx + 3]
        }
        // 标记为已修复
        to_inpaint[y * w + x] = false
        changed = true
      }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 创建矩形修复掩码
pub fn create_rect_mask(
  width : Int,
  height : Int,
  x : Int,
  y : Int,
  rect_w : Int,
  rect_h : Int,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if width <= 0 || height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "create_rect_mask: 图像尺寸必须大于0",
    )
  }
  if x < 0 || y < 0 {
    raise @types.LoadError::DecodeFailed(
      "create_rect_mask: 矩形坐标不能为负",
    )
  }
  if rect_w <= 0 || rect_h <= 0 {
    raise @types.LoadError::DecodeFailed(
      "create_rect_mask: 矩形尺寸必须大于0",
    )
  }
  if x + rect_w > width || y + rect_h > height {
    raise @types.LoadError::DecodeFailed(
      "create_rect_mask: 矩形超出图像边界",
    )
  }

  let mask_data : Array[Byte] = Array::make(width * height, b'\x00')
  for py in 0..<height {
    for px in 0..<width {
      if px >= x && px < x + rect_w && py >= y && py < y + rect_h {
        mask_data[py * width + px] = b'\xFF'
      }
    }
  }
  @types.Image::{
    width,
    height,
    channels: 1,
    data: Bytes::from_array(mask_data),
  }
}

///|
/// 去除图像中的小物体（基于连通域分析）
pub fn remove_small_objects(
  img : @types.Image,
  max_size? : Int = 100,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "remove_small_objects: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "remove_small_objects: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "remove_small_objects: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if max_size <= 0 {
    raise @types.LoadError::DecodeFailed(
      "remove_small_objects: max_size必须大于0",
    )
  }

  let ms = max_size
  let w = img.width
  let h = img.height
  let channels = img.channels
  let data = img.data
  // 转换为灰度
  let gray : Array[Int] = []
  for i in 0..<(w * h) {
    let idx = i * channels
    let r = data[idx].to_int()
    let g = if channels >= 2 { data[idx + 1].to_int() } else { r }
    let b = if channels >= 3 { data[idx + 2].to_int() } else { r }
    gray.push(
      (0.299 * r.to_double() + 0.587 * g.to_double() + 0.114 * b.to_double()).to_int(),
    )
  }
  // 连通域分析（洪水填充）
  let labels : Array[Int] = Array::make(w * h, 0)
  let mut next_label = 1
  let sizes : Array[Int] = []
  for y in 0..<h {
    for x in 0..<w {
      if gray[y * w + x] > 128 && labels[y * w + x] == 0 {
        // 洪水填充
        let stack : Array[(Int, Int)] = []
        stack.push((x, y))
        labels[y * w + x] = next_label
        let mut size = 0
        while stack.length() > 0 {
          match stack.pop() {
            Some((cx, cy)) => {
              size += 1
              let neighbors = [(-1, 0), (1, 0), (0, -1), (0, 1)]
              for _tup2 in neighbors {
                let (dx, dy) = _tup2
                let nx = cx + dx
                let ny = cy + dy
                if nx >= 0 &&
                  nx < w &&
                  ny >= 0 &&
                  ny < h &&
                  gray[ny * w + nx] > 128 &&
                  labels[ny * w + nx] == 0 {
                  labels[ny * w + nx] = next_label
                  stack.push((nx, ny))
                }
              }
            }
            None => ignore(())
          }
        }
        sizes.push(size)
        next_label += 1
      }
    }
  }
  // 去除小物体（将小连通域的像素设为背景色）
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  for i in 0..<(w * h) {
    let idx = i * channels
    let label = labels[i]
    if label > 0 && sizes[label - 1] <= ms {
      // 小物体：设为黑色（或周围背景色）
      for c in 0..<channels {
        out_data[idx + c] = b'\x00'
      }
    } else {
      // 保留原像素
      for c in 0..<channels {
        out_data[idx + c] = data[idx + c]
      }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 图像去水印（基于修复的简化版）
/// 将指定区域的像素用周围像素填充
pub fn remove_watermark(
  img : @types.Image,
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "remove_watermark: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "remove_watermark: 通道数必须在1-4之间",
    )
  }
  if x < 0 || y < 0 {
    raise @types.LoadError::DecodeFailed(
      "remove_watermark: 区域坐标不能为负",
    )
  }
  if width <= 0 || height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "remove_watermark: 区域尺寸必须大于0",
    )
  }
  if x + width > img.width || y + height > img.height {
    raise @types.LoadError::DecodeFailed(
      "remove_watermark: 区域超出图像边界",
    )
  }

  let mask = create_rect_mask(img.width, img.height, x, y, width, height)
  inpaint_advanced(img, mask, radius=5)
}
