// 纯 MoonBit 图像缩放（全目标可用：native/wasm/js）
// 仅依赖 @types，不依赖 @core/FFI
// 支持最近邻 + 双线性插值

///|
/// 双线性插值采样。在 (x, y) 处采样通道 c 的值。
fn resize_sample_bilinear(
  data : Array[Int],
  w : Int,
  h : Int,
  ch : Int,
  c : Int,
  x : Float,
  y : Float,
) -> Int {
  let x0 = x.to_int()
  let y0 = y.to_int()
  let w_minus_1 = w - 1
  let h_minus_1 = h - 1
  let x0c = x0.clamp(min=0, max=w_minus_1)
  let y0c = y0.clamp(min=0, max=h_minus_1)
  let x1 = (x0 + 1).clamp(min=0, max=w_minus_1)
  let y1 = (y0 + 1).clamp(min=0, max=h_minus_1)
  let fx = x - Float::from_int(x0)
  let fy = y - Float::from_int(y0)
  let p00 = data[(y0c * w + x0c) * ch + c]
  let p10 = data[(y0c * w + x1) * ch + c]
  let p01 = data[(y1 * w + x0c) * ch + c]
  let p11 = data[(y1 * w + x1) * ch + c]
  let top = Float::from_int(p00) * (1.0F - fx) + Float::from_int(p10) * fx
  let bot = Float::from_int(p01) * (1.0F - fx) + Float::from_int(p11) * fx
  (top * (1.0F - fy) + bot * fy + 0.5F).to_int()
}

///|
/// 最近邻采样。在 (x, y) 处采样通道 c 的值。
fn resize_sample_nearest(
  data : Array[Int],
  w : Int,
  h : Int,
  ch : Int,
  c : Int,
  x : Float,
  y : Float,
) -> Int {
  let xi = (x + 0.5F).to_int().clamp(min=0, max=w - 1)
  let yi = (y + 0.5F).to_int().clamp(min=0, max=h - 1)
  data[(yi * w + xi) * ch + c]
}

///|
/// resize 8-bit 图像（纯 MoonBit，全目标可用）。
/// 使用双线性插值（filter = PointSample 时使用最近邻）。
/// edge 参数目前统一按 Clamp 处理（边缘像素重复）。
pub fn resize_pure(
  img : @types.Image,
  out_w : Int,
  out_h : Int,
  filter? : @types.ResizeFilter = @types.ResizeFilter::Default,
  edge? : @types.ResizeEdge = @types.ResizeEdge::Clamp,
) -> @types.Image raise @types.LoadError {
  let _ = edge
  if out_w <= 0 || out_h <= 0 {
    raise @types.LoadError::DecodeFailed("resize 输出尺寸必须为正数")
  }
  let ch = img.channels
  let w = img.width
  let h = img.height
  let data_int : Array[Int] = Array::make(w * h * ch, 0)
  for i in 0..<(w * h * ch) {
    data_int[i] = img.data[i].to_int()
  }
  let scale_x = Float::from_int(w) / Float::from_int(out_w)
  let scale_y = Float::from_int(h) / Float::from_int(out_h)
  let use_nearest = match filter {
    PointSample => true
    _ => false
  }
  let out : Array[Byte] = Array::make(out_w * out_h * ch, b'\x00')
  for dy in 0..<out_h {
    let sy = (Float::from_int(dy) + 0.5F) * scale_y - 0.5F
    for dx in 0..<out_w {
      let sx = (Float::from_int(dx) + 0.5F) * scale_x - 0.5F
      for ci in 0..<ch {
        let val = if use_nearest {
          resize_sample_nearest(data_int, w, h, ch, ci, sx, sy)
        } else {
          resize_sample_bilinear(data_int, w, h, ch, ci, sx, sy)
        }
        out[(dy * out_w + dx) * ch + ci] = val.clamp(min=0, max=255).to_byte()
      }
    }
  }
  @types.Image::{
    width: out_w,
    height: out_h,
    channels: ch,
    data: Bytes::from_array(out),
  }
}
