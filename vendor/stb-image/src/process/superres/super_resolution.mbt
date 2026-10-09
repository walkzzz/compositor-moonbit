// 超分辨率（v11.2.0）
// 双三次插值 + Lanczos 插值 + 边缘保持超分

///|
/// 超分辨率配置
pub(all) struct SuperResolutionConfig {
  scale : Double // 放大倍数
  method_type : String // "bicubic" / "lanczos" / "edge_preserving"
  lanczos_a : Int // Lanczos 参数（2或3）
  edge_threshold : Double // 边缘阈值
  sharpen_amount : Double // 锐化强度
}

///|
/// 创建默认超分辨率配置
pub fn sr_default_config() -> SuperResolutionConfig {
  SuperResolutionConfig::{
    scale: 2.0,
    method_type: "bicubic",
    lanczos_a: 3,
    edge_threshold: 30.0,
    sharpen_amount: 0.5,
  }
}

///|
/// 双三次插值核
fn bicubic_kernel(x : Double) -> Double {
  let a = -0.5
  let abs_x = x.abs()
  if abs_x <= 1.0 {
    (a + 2.0) * abs_x * abs_x * abs_x - (a + 3.0) * abs_x * abs_x + 1.0
  } else if abs_x <= 2.0 {
    a * abs_x * abs_x * abs_x -
    5.0 * a * abs_x * abs_x +
    8.0 * a * abs_x -
    4.0 * a
  } else {
    0.0
  }
}

///|
/// Lanczos 插值核
fn lanczos_kernel(x : Double, a : Int) -> Double {
  let a_d = a.to_double()
  let abs_x = x.abs()
  if abs_x < 0.0001 {
    1.0
  } else if abs_x < a_d {
    let pi_x = 3.141592653589793 * x
    let pi_x_a = pi_x / a_d
    @math.sin(pi_x) * @math.sin(pi_x_a) / (pi_x * pi_x_a)
  } else {
    0.0
  }
}

///|
/// 双三次插值超分辨率
pub fn super_resolution_bicubic(
  img : @types.Image,
  scale : Double,
) -> @types.Image {
  let w = img.width
  let h = img.height
  let channels = img.channels
  let data = img.data
  let out_w = (w.to_double() * scale).to_int()
  let out_h = (h.to_double() * scale).to_int()
  let out_data : Array[Byte] = Array::make(out_w * out_h * channels, b'\x00')
  for y in 0..<out_h {
    for x in 0..<out_w {
      // 反向映射到原图坐标
      let src_x = (x.to_double() + 0.5) / scale - 0.5
      let src_y = (y.to_double() + 0.5) / scale - 0.5
      let x0 = src_x.to_int()
      let y0 = src_y.to_int()
      for c in 0..<channels {
        let mut sum = 0.0
        let mut weight_sum = 0.0
        // 4x4 邻域
        for dy in -1..<3 {
          for dx in -1..<3 {
            let px = x0 + dx
            let py = y0 + dy
            if px >= 0 && px < w && py >= 0 && py < h {
              let wx = bicubic_kernel(src_x - px.to_double())
              let wy = bicubic_kernel(src_y - py.to_double())
              let weight = wx * wy
              sum += data[(py * w + px) * channels + c].to_double() * weight
              weight_sum += weight
            }
          }
        }
        let value = if weight_sum > 0.0 { sum / weight_sum } else { 0.0 }
        let clamped = if value < 0.0 {
          0.0
        } else if value > 255.0 {
          255.0
        } else {
          value
        }
        out_data[(y * out_w + x) * channels + c] = clamped.to_int().to_byte()
      }
    }
  }
  @types.Image::{
    width: out_w,
    height: out_h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// Lanczos 插值超分辨率
pub fn super_resolution_lanczos(
  img : @types.Image,
  scale : Double,
  a? : Int = 3,
) -> @types.Image {
  let lanczos_a = a
  let w = img.width
  let h = img.height
  let channels = img.channels
  let data = img.data
  let out_w = (w.to_double() * scale).to_int()
  let out_h = (h.to_double() * scale).to_int()
  let out_data : Array[Byte] = Array::make(out_w * out_h * channels, b'\x00')
  let radius = lanczos_a
  for y in 0..<out_h {
    for x in 0..<out_w {
      let src_x = (x.to_double() + 0.5) / scale - 0.5
      let src_y = (y.to_double() + 0.5) / scale - 0.5
      let x0 = src_x.to_int()
      let y0 = src_y.to_int()
      for c in 0..<channels {
        let mut sum = 0.0
        let mut weight_sum = 0.0
        for dy in -radius..<(radius + 1) {
          for dx in -radius..<(radius + 1) {
            let px = x0 + dx
            let py = y0 + dy
            if px >= 0 && px < w && py >= 0 && py < h {
              let wx = lanczos_kernel(src_x - px.to_double(), lanczos_a)
              let wy = lanczos_kernel(src_y - py.to_double(), lanczos_a)
              let weight = wx * wy
              sum += data[(py * w + px) * channels + c].to_double() * weight
              weight_sum += weight
            }
          }
        }
        let value = if weight_sum > 0.0 { sum / weight_sum } else { 0.0 }
        let clamped = if value < 0.0 {
          0.0
        } else if value > 255.0 {
          255.0
        } else {
          value
        }
        out_data[(y * out_w + x) * channels + c] = clamped.to_int().to_byte()
      }
    }
  }
  @types.Image::{
    width: out_w,
    height: out_h,
    channels,
    data: Bytes::from_array(out_data),
  }
}

///|
/// 边缘保持超分辨率（双三次 + 边缘检测 + 锐化）
pub fn super_resolution_edge_preserving(
  img : @types.Image,
  scale : Double,
  edge_threshold? : Double = 30.0,
  sharpen_amount? : Double = 0.5,
) -> @types.Image {
  let et = edge_threshold
  let sa = sharpen_amount
  // 第一步：双三次插值
  let upscaled = super_resolution_bicubic(img, scale)
  // 第二步：边缘检测（Sobel）
  let edges = detect_edges_sobel(upscaled)
  // 第三步：在边缘区域进行锐化
  let w = upscaled.width
  let h = upscaled.height
  let channels = upscaled.channels
  let data = upscaled.data
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      for c in 0..<channels {
        let idx = (y * w + x) * channels + c
        let edge_strength = edges[y * w + x]
        if edge_strength > et && x > 0 && x < w - 1 && y > 0 && y < h - 1 {
          // 锐化：中心像素加权，减去邻域模糊
          let center = data[idx].to_double()
          let mut neighbor_sum = 0.0
          let neighbors = [(-1, 0), (1, 0), (0, -1), (0, 1)]
          for _tup0 in neighbors {
            let (dx, dy) = _tup0
            neighbor_sum += data[((y + dy) * w + (x + dx)) * channels + c].to_double()
          }
          let sharpened = center * (1.0 + sa) - neighbor_sum * sa / 4.0
          let clamped = if sharpened < 0.0 {
            0.0
          } else if sharpened > 255.0 {
            255.0
          } else {
            sharpened
          }
          out_data[idx] = clamped.to_int().to_byte()
        } else {
          out_data[idx] = data[idx]
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
/// Sobel 边缘检测
fn detect_edges_sobel(img : @types.Image) -> Array[Double] {
  let w = img.width
  let h = img.height
  let data = img.data
  let channels = img.channels
  let edges : Array[Double] = Array::make(w * h, 0.0)
  // 转换为灰度
  let gray : Array[Double] = []
  for i in 0..<(w * h) {
    if channels >= 3 {
      let r = data[i * channels].to_double()
      let g = data[i * channels + 1].to_double()
      let b = data[i * channels + 2].to_double()
      gray.push(0.299 * r + 0.587 * g + 0.114 * b)
    } else {
      gray.push(data[i * channels].to_double())
    }
  }
  // Sobel 算子
  let gx_kernel = [
    (-1, -1, -1),
    (0, -1, 0),
    (1, -1, 1),
    (-1, 0, -2),
    (0, 0, 0),
    (1, 0, 2),
    (-1, 1, -1),
    (0, 1, 0),
    (1, 1, 1),
  ]
  let gy_kernel = [
    (-1, -1, -1),
    (0, -1, -2),
    (1, -1, -1),
    (-1, 0, 0),
    (0, 0, 0),
    (1, 0, 0),
    (-1, 1, 1),
    (0, 1, 2),
    (1, 1, 1),
  ]
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let mut gx = 0.0
      let mut gy = 0.0
      for i in 0..<9 {
        let (dx, dy, weight) = gx_kernel[i]
        gx += gray[(y + dy) * w + (x + dx)] * weight.to_double()
      }
      for i in 0..<9 {
        let (dx, dy, weight) = gy_kernel[i]
        gy += gray[(y + dy) * w + (x + dx)] * weight.to_double()
      }
      edges[y * w + x] = (gx * gx + gy * gy).sqrt()
    }
  }
  edges
}

///|
/// 通用超分辨率接口
pub fn super_resolution(
  img : @types.Image,
  config? : SuperResolutionConfig,
) -> @types.Image {
  let cfg = match config {
    Some(c) => c
    None => sr_default_config()
  }
  match cfg.method_type {
    "lanczos" => super_resolution_lanczos(img, cfg.scale, a=cfg.lanczos_a)
    "edge_preserving" =>
      super_resolution_edge_preserving(
        img,
        cfg.scale,
        edge_threshold=cfg.edge_threshold,
        sharpen_amount=cfg.sharpen_amount,
      )
    _ => super_resolution_bicubic(img, cfg.scale)
  }
}

///|
/// 2倍超分辨率（便捷接口）
pub fn upscale_2x(img : @types.Image) -> @types.Image {
  super_resolution_bicubic(img, 2.0)
}

///|
/// 4倍超分辨率（便捷接口）
pub fn upscale_4x(img : @types.Image) -> @types.Image {
  super_resolution_bicubic(img, 4.0)
}
