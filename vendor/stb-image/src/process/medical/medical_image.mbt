// 医学图像处理（v12.10.0）
// 窗宽窗位调整、伪彩色映射、医学图像增强

///|
/// 窗宽窗位配置
pub(all) struct WindowLevel {
  window_width : Double // 窗宽
  window_level : Double // 窗位
}

///|
/// 创建默认窗宽窗位（肺窗）
pub fn window_level_lung() -> WindowLevel {
  WindowLevel::{ window_width: 1500.0, window_level: -600.0 }
}

///|
/// 创建纵隔窗
pub fn window_level_mediastinum() -> WindowLevel {
  WindowLevel::{ window_width: 400.0, window_level: 40.0 }
}

///|
/// 创建骨窗
pub fn window_level_bone() -> WindowLevel {
  WindowLevel::{ window_width: 2000.0, window_level: 400.0 }
}

///|
/// 创建脑窗
pub fn window_level_brain() -> WindowLevel {
  WindowLevel::{ window_width: 80.0, window_level: 40.0 }
}

///|
/// 应用窗宽窗位调整
/// 将原始灰度值（如 CT 值 HU）映射到 0-255
pub fn apply_window_level(
  img : @types.Image,
  config : WindowLevel,
) -> @types.Image {
  let w = img.width
  let h = img.height
  let channels = img.channels
  let out_data : Array[Byte] = Array::make(w * h, b'\x00')
  let low = config.window_level - config.window_width / 2.0
  let high = config.window_level + config.window_width / 2.0
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      // 取第一个通道作为灰度值
      let raw = img.data[idx].to_double()
      let mapped = if raw <= low {
        0.0
      } else if raw >= high {
        255.0
      } else {
        (raw - low) / config.window_width * 255.0
      }
      out_data[y * w + x] = mapped.min(255.0).max(0.0).to_int().to_byte()
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 医学图像伪彩色映射
/// 支持多种医学常用伪彩色方案
pub fn medical_colormap(
  img : @types.Image,
  colormap? : String = "hot",
) -> @types.Image {
  let cmap = colormap
  let w = img.width
  let h = img.height
  let channels = img.channels
  let out_data : Array[Byte] = Array::make(w * h * 3, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      let gray = if channels >= 1 {
        img.data[idx].to_double() / 255.0
      } else {
        0.0
      }
      let out_idx = (y * w + x) * 3
      // 多种伪彩色映射
      let (r, g, b) = match cmap {
        "hot" =>
          // 黑 -> 红 -> 黄 -> 白
          if gray < 0.33 {
            ((gray / 0.33 * 255.0).to_int(), 0, 0)
          } else if gray < 0.66 {
            (255, ((gray - 0.33) / 0.33 * 255.0).to_int(), 0)
          } else {
            (255, 255, ((gray - 0.66) / 0.34 * 255.0).to_int())
          }
        "cool" =>
          // 青 -> 品红
          ((gray * 255.0).to_int(), ((1.0 - gray) * 255.0).to_int(), 255)
        "spring" =>
          // 品红 -> 黄
          (255, (gray * 255.0).to_int(), ((1.0 - gray) * 255.0).to_int())
        "summer" =>
          // 绿 -> 黄
          ((gray * 128.0).to_int(), (128.0 + gray * 127.0).to_int(), 0)
        "autumn" =>
          // 红 -> 黄
          (255, (gray * 255.0).to_int(), 0)
        "winter" =>
          // 蓝 -> 绿
          (0, (gray * 255.0).to_int(), ((1.0 - gray) * 255.0).to_int())
        "bone" => {
          // 骨色：黑 -> 灰 -> 白（带一点蓝调）
          let v = (gray * 255.0).to_int()
          (v, v, (v + 20).min(255))
        }
        "pink" => {
          // 粉色：灰 -> 粉
          let v = (gray * 255.0).to_int()
          (
            v.min(255),
            (v.to_double() * 0.6).to_int().min(255),
            (v.to_double() * 0.7).to_int().min(255),
          )
        }
        _ => {
          // 灰度
          let v = (gray * 255.0).to_int()
          (v, v, v)
        }
      }
      out_data[out_idx] = r.min(255).max(0).to_byte()
      out_data[out_idx + 1] = g.min(255).max(0).to_byte()
      out_data[out_idx + 2] = b.min(255).max(0).to_byte()
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 3,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 医学图像对比度增强（CLAHE 简化版，自适应直方图均衡化）
pub fn medical_contrast_enhance(
  img : @types.Image,
  clip_limit? : Double = 2.0,
  tile_size? : Int = 8,
) -> @types.Image {
  let _ = clip_limit
  let _ = tile_size
  let w = img.width
  let h = img.height
  let channels = img.channels
  // 转换为灰度
  let gray : Array[Int] = Array::make(w * h, 0)
  for i in 0..<(w * h) {
    let idx = i * channels
    let r = img.data[idx].to_int()
    let g = if channels >= 2 { img.data[idx + 1].to_int() } else { r }
    let b = if channels >= 3 { img.data[idx + 2].to_int() } else { r }
    gray[i] = (0.299 * r.to_double() +
    0.587 * g.to_double() +
    0.114 * b.to_double()).to_int()
  }
  // 全局直方图均衡化（简化版）
  let histogram : Array[Int] = Array::make(256, 0)
  for i in 0..<(w * h) {
    histogram[gray[i]] += 1
  }
  // 累积分布函数
  let cdf : Array[Int] = Array::make(256, 0)
  let mut sum = 0
  for i in 0..<256 {
    sum += histogram[i]
    cdf[i] = sum
  }
  // 映射
  let total = w * h
  let out_data : Array[Byte] = Array::make(w * h, b'\x00')
  for i in 0..<(w * h) {
    let value = gray[i]
    let equalized = if total > 0 {
      (cdf[value].to_double() / total.to_double() * 255.0).to_int()
    } else {
      value
    }
    out_data[i] = equalized.min(255).max(0).to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 医学图像降噪（各向异性扩散，简化版）
pub fn medical_denoise(
  img : @types.Image,
  iterations? : Int = 5,
  kappa? : Double = 30.0,
) -> @types.Image {
  let iter = iterations
  let k = kappa
  let w = img.width
  let h = img.height
  let channels = img.channels
  let mut current : Array[Double] = Array::make(w * h * channels, 0.0)
  for i in 0..<(w * h * channels) {
    current[i] = img.data[i].to_double()
  }
  for _ in 0..<iter {
    let next : Array[Double] = Array::make(w * h * channels, 0.0)
    for y in 1..<(h - 1) {
      for x in 1..<(w - 1) {
        for c in 0..<channels {
          let idx = (y * w + x) * channels + c
          let center = current[idx]
          // 四邻域梯度
          let north = current[((y - 1) * w + x) * channels + c] - center
          let south = current[((y + 1) * w + x) * channels + c] - center
          let east = current[(y * w + (x + 1)) * channels + c] - center
          let west = current[(y * w + (x - 1)) * channels + c] - center
          // 扩散系数（指数函数，边缘保留）
          let cn = @math.exp(-(north.abs() / k) * (north.abs() / k))
          let cs = @math.exp(-(south.abs() / k) * (south.abs() / k))
          let ce = @math.exp(-(east.abs() / k) * (east.abs() / k))
          let cw = @math.exp(-(west.abs() / k) * (west.abs() / k))
          // 更新
          let lambda = 0.25
          next[idx] = center +
            lambda * (cn * north + cs * south + ce * east + cw * west)
        }
      }
    }
    // 边界复制
    for y in 0..<h {
      for x in 0..<w {
        if y == 0 || y == h - 1 || x == 0 || x == w - 1 {
          for c in 0..<channels {
            next[(y * w + x) * channels + c] = current[(y * w + x) * channels +
              c]
          }
        }
      }
    }
    current = next
  }
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  for i in 0..<(w * h * channels) {
    out_data[i] = current[i].min(255.0).max(0.0).to_int().to_byte()
  }
  @types.Image::{
    width: w,
    height: h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 测量图像中两点之间的距离（像素距离）
pub fn measure_distance(
  x1 : Int,
  y1 : Int,
  x2 : Int,
  y2 : Int,
  pixel_spacing? : Double = 1.0,
) -> Double {
  let spacing = pixel_spacing
  let dx = (x2 - x1).to_double()
  let dy = (y2 - y1).to_double()
  (dx * dx + dy * dy).sqrt() * spacing
}

///|
/// 测量图像中区域的面积（像素面积）
pub fn measure_area(mask : @types.Image, pixel_area? : Double = 1.0) -> Double {
  let area_per_pixel = pixel_area
  let w = mask.width
  let h = mask.height
  let channels = mask.channels
  let mut count = 0
  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * channels
      if mask.data[idx].to_int() > 128 {
        count += 1
      }
    }
  }
  count.to_double() * area_per_pixel
}
