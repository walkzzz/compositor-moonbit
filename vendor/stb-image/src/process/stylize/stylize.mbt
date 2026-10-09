// 图像风格化（v11.5.0）
// 油画效果 / 素描效果 / 水彩效果 / 卡通效果

///|
/// 风格化配置
pub(all) struct StylizeConfig {
  oil_paint_radius : Int // 油画效果半径
  oil_paint_intensity : Int // 油画色阶数
  sketch_blend : Double // 素描混合比例
  watercolor_blur : Int // 水彩模糊半径
  cartoon_levels : Int // 卡通色阶数
  cartoon_edge_threshold : Double // 卡通边缘阈值
}

///|
/// 创建默认风格化配置
pub fn stylize_default_config() -> StylizeConfig {
  StylizeConfig::{
    oil_paint_radius: 3,
    oil_paint_intensity: 20,
    sketch_blend: 0.7,
    watercolor_blur: 5,
    cartoon_levels: 8,
    cartoon_edge_threshold: 30.0,
  }
}

///|
/// 油画效果
/// 基于颜色直方图的油画效果：在邻域内取出现频率最高的颜色
pub fn oil_paint(
  img : @types.Image,
  radius? : Int = 3,
  intensity? : Int = 20,
) -> @types.Image {
  let r = radius
  let levels = intensity
  let w = img.width
  let h = img.height
  let channels = img.channels
  let data = img.data
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      // 统计邻域内各颜色的出现频率
      let bins : Array[Int] = Array::make(levels * levels * levels, 0)
      let bin_r : Array[Int] = Array::make(levels * levels * levels, 0)
      let bin_g : Array[Int] = Array::make(levels * levels * levels, 0)
      let bin_b : Array[Int] = Array::make(levels * levels * levels, 0)
      for dy in -r..<(r + 1) {
        for dx in -r..<(r + 1) {
          let nx = x + dx
          let ny = y + dy
          if nx >= 0 && nx < w && ny >= 0 && ny < h {
            let idx = (ny * w + nx) * channels
            let red = data[idx].to_int()
            let green = if channels >= 2 { data[idx + 1].to_int() } else { red }
            let blue = if channels >= 3 { data[idx + 2].to_int() } else { red }
            // 量化到 levels 级
            let r_bin = (red * levels / 256).min(levels - 1)
            let g_bin = (green * levels / 256).min(levels - 1)
            let b_bin = (blue * levels / 256).min(levels - 1)
            let bin_idx = r_bin * levels * levels + g_bin * levels + b_bin
            bins[bin_idx] += 1
            bin_r[bin_idx] += red
            bin_g[bin_idx] += green
            bin_b[bin_idx] += blue
          }
        }
      }
      // 找出现频率最高的颜色
      let mut max_count = 0
      let mut max_bin = 0
      for i in 0..<(levels * levels * levels) {
        if bins[i] > max_count {
          max_count = bins[i]
          max_bin = i
        }
      }
      // 取该 bin 的平均颜色
      let out_idx = (y * w + x) * channels
      if max_count > 0 {
        out_data[out_idx] = (bin_r[max_bin] / max_count).to_byte()
        if channels >= 2 {
          out_data[out_idx + 1] = (bin_g[max_bin] / max_count).to_byte()
        }
        if channels >= 3 {
          out_data[out_idx + 2] = (bin_b[max_bin] / max_count).to_byte()
        }
        if channels >= 4 {
          out_data[out_idx + 3] = data[out_idx + 3]
        }
      } else {
        for c in 0..<channels {
          out_data[out_idx + c] = data[out_idx + c]
        }
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
/// 素描效果
/// 基于灰度反色 + 颜色减淡混合的铅笔素描效果
pub fn sketch(img : @types.Image, blend? : Double = 0.7) -> @types.Image {
  let b = blend
  let w = img.width
  let h = img.height
  let channels = img.channels
  let data = img.data
  // 1. 转换为灰度
  let gray : Array[Byte] = []
  for i in 0..<(w * h) {
    let idx = i * channels
    let r = data[idx].to_double()
    let g = if channels >= 2 { data[idx + 1].to_double() } else { r }
    let bl = if channels >= 3 { data[idx + 2].to_double() } else { r }
    let gray_val = (0.299 * r + 0.587 * g + 0.114 * bl).to_int().min(255).max(0)
    gray.push(gray_val.to_byte())
  }
  // 2. 反色
  let inverted : Array[Byte] = []
  for i in 0..<(w * h) {
    inverted.push((255 - gray[i].to_int()).to_byte())
  }
  // 3. 对反色图进行高斯模糊（简化版：均值模糊）
  let blurred = simple_blur(inverted, w, h, 5)
  // 4. 颜色减淡混合：result = base / (1 - blend)
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  for i in 0..<(w * h) {
    let base = gray[i].to_double()
    let blur = blurred[i].to_double()
    // 颜色减淡：result = base * 255 / (255 - blur)
    let mut result = if blur < 255.0 {
      base * 255.0 / (255.0 - blur)
    } else {
      255.0
    }
    result = result.min(255.0).max(0.0)
    // 与原图混合
    let final_val = (result * b + base * (1.0 - b)).to_int().min(255).max(0)
    let out_idx = i * channels
    out_data[out_idx] = final_val.to_byte()
    if channels >= 2 {
      out_data[out_idx + 1] = final_val.to_byte()
    }
    if channels >= 3 {
      out_data[out_idx + 2] = final_val.to_byte()
    }
    if channels >= 4 {
      out_data[out_idx + 3] = data[out_idx + 3]
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
/// 简单均值模糊
fn simple_blur(
  input : Array[Byte],
  w : Int,
  h : Int,
  radius : Int,
) -> Array[Byte] {
  let output : Array[Byte] = []
  for y in 0..<h {
    for x in 0..<w {
      let mut sum = 0
      let mut count = 0
      for dy in -radius..<(radius + 1) {
        for dx in -radius..<(radius + 1) {
          let nx = x + dx
          let ny = y + dy
          if nx >= 0 && nx < w && ny >= 0 && ny < h {
            sum += input[ny * w + nx].to_int()
            count += 1
          }
        }
      }
      output.push(
        if count > 0 {
          (sum / count).to_byte()
        } else {
          input[y * w + x]
        },
      )
    }
  }
  output
}

///|
/// 水彩效果
/// 基于模糊 + 颜色量化 + 边缘增强的水彩效果
pub fn watercolor(img : @types.Image, blur_radius? : Int = 5) -> @types.Image {
  let radius = blur_radius
  let w = img.width
  let h = img.height
  let channels = img.channels
  let data = img.data
  // 1. 对每个通道进行均值模糊
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  for c in 0..<channels {
    let channel_data : Array[Byte] = []
    for i in 0..<(w * h) {
      channel_data.push(data[i * channels + c])
    }
    let blurred = simple_blur(channel_data, w, h, radius)
    for i in 0..<(w * h) {
      out_data[i * channels + c] = blurred[i]
    }
  }
  // 2. 颜色量化（减少色阶，增加水彩感）
  let levels = 12
  for i in 0..<(w * h) {
    for c in 0..<channels {
      let idx = i * channels + c
      let val = out_data[idx].to_int()
      let quantized = val * levels / 256 * (256 / levels)
      out_data[idx] = quantized.min(255).to_byte()
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
/// 卡通效果
/// 基于颜色量化 + 边缘检测的卡通效果
pub fn cartoon(
  img : @types.Image,
  levels? : Int = 8,
  edge_threshold? : Double = 30.0,
) -> @types.Image {
  let lv = levels
  let et = edge_threshold
  let w = img.width
  let h = img.height
  let channels = img.channels
  let data = img.data
  // 1. 颜色量化
  let quantized : Array[Byte] = Array::make(w * h * channels, b'\x00')
  for i in 0..<(w * h) {
    for c in 0..<channels {
      let idx = i * channels + c
      let val = data[idx].to_int()
      let q = val * lv / 256 * (256 / lv)
      quantized[idx] = q.min(255).to_byte()
    }
  }
  // 2. 边缘检测（Sobel，基于灰度）
  let edges : Array[Double] = Array::make(w * h, 0.0)
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let _ = (y * w + x) * channels
      // 灰度
      let gray = (px, py) => {
        let i = (py * w + px) * channels
        let r = data[i].to_double()
        let g = if channels >= 2 { data[i + 1].to_double() } else { r }
        let b = if channels >= 3 { data[i + 2].to_double() } else { r }
        0.299 * r + 0.587 * g + 0.114 * b
      }
      let gx = -gray(x - 1, y - 1) -
        2.0 * gray(x - 1, y) -
        gray(x - 1, y + 1) +
        gray(x + 1, y - 1) +
        2.0 * gray(x + 1, y) +
        gray(x + 1, y + 1)
      let gy = -gray(x - 1, y - 1) -
        2.0 * gray(x, y - 1) -
        gray(x + 1, y - 1) +
        gray(x - 1, y + 1) +
        2.0 * gray(x, y + 1) +
        gray(x + 1, y + 1)
      edges[y * w + x] = (gx * gx + gy * gy).sqrt()
    }
  }
  // 3. 合成：量化颜色 + 黑色边缘
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  for i in 0..<(w * h) {
    let idx = i * channels
    if edges[i] > et {
      // 边缘：黑色
      for c in 0..<channels {
        out_data[idx + c] = b'\x00'
      }
      if channels >= 4 {
        out_data[idx + 3] = quantized[idx + 3]
      }
    } else {
      // 非边缘：量化颜色
      for c in 0..<channels {
        out_data[idx + c] = quantized[idx + c]
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
/// 通用风格化接口
pub fn stylize(
  img : @types.Image,
  style : String,
  config? : StylizeConfig,
) -> @types.Image {
  let cfg = match config {
    Some(c) => c
    None => stylize_default_config()
  }
  match style {
    "oil" =>
      oil_paint(
        img,
        radius=cfg.oil_paint_radius,
        intensity=cfg.oil_paint_intensity,
      )
    "sketch" => sketch(img, blend=cfg.sketch_blend)
    "watercolor" => watercolor(img, blur_radius=cfg.watercolor_blur)
    "cartoon" =>
      cartoon(
        img,
        levels=cfg.cartoon_levels,
        edge_threshold=cfg.cartoon_edge_threshold,
      )
    _ => oil_paint(img)
  }
}
