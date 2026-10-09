// 伪彩色映射（纯 MoonBit）：apply_colormap + 预设色彩映射表

///|
/// 色彩映射预设
pub(all) enum Colormap {
  JET // 蓝→青→绿→黄→红
  HOT // 黑→红→黄→白
  COOL // 青→品红
  GRAY // 灰度
  BONE // 偏蓝灰
  COPPER // 偏铜色
}

///|
fn get_colormap_lut(map : Colormap) -> Array[(Byte, Byte, Byte)] {
  let lut : Array[(Byte, Byte, Byte)] = Array::make(
    256,
    (b'\x00', b'\x00', b'\x00'),
  )
  for i in 0..<256 {
    let t = Float::from_int(i) / 255.0F
    let (r, g, b) = match map {
      JET => {
        // JET: 4 段线性插值
        let r_val = if t < 0.375F {
          0.0F
        } else if t < 0.625F {
          (t - 0.375F) / 0.25F
        } else {
          1.0F
        }
        let g_val = if t < 0.125F {
          0.0F
        } else if t < 0.375F {
          (t - 0.125F) / 0.25F
        } else if t < 0.625F {
          1.0F
        } else if t < 0.875F {
          1.0F - (t - 0.625F) / 0.25F
        } else {
          0.0F
        }
        let b_val = if t < 0.125F {
          0.5F + t / 0.25F * 0.5F
        } else if t < 0.375F {
          1.0F
        } else if t < 0.625F {
          1.0F - (t - 0.375F) / 0.25F
        } else {
          0.0F
        }
        (r_val, g_val, b_val)
      }
      HOT => {
        let r_val = if t < 0.333F { t / 0.333F } else { 1.0F }
        let g_val = if t < 0.333F {
          0.0F
        } else if t < 0.666F {
          (t - 0.333F) / 0.333F
        } else {
          1.0F
        }
        let b_val = if t < 0.666F { 0.0F } else { (t - 0.666F) / 0.334F }
        (r_val, g_val, b_val)
      }
      COOL => (0.0F, t, 1.0F - t)
      GRAY => (t, t, t)
      BONE =>
        // 偏蓝灰
        (t * 0.93F, t * 0.88F, t * 1.0F)
      COPPER =>
        // 偏铜色
        ((t * 1.25F).clamp(min=0.0F, max=1.0F), t * 0.78F, t * 0.5F)
    }
    lut[i] = (
      (r * 255.0F + 0.5F).to_int().clamp(min=0, max=255).to_byte(),
      (g * 255.0F + 0.5F).to_int().clamp(min=0, max=255).to_byte(),
      (b * 255.0F + 0.5F).to_int().clamp(min=0, max=255).to_byte(),
    )
  }
  lut
}

///|
/// 伪彩色映射。将灰度图或彩色图（先转灰度）映射为 RGB 伪彩色图像。
pub fn apply_colormap(
  img : @types.Image,
  map : Colormap,
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "apply_colormap: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "apply_colormap: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "apply_colormap: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  let lut = get_colormap_lut(map)
  let n = img.width * img.height
  let ch = img.channels
  let out : Array[Byte] = Array::make(n * 3, b'\x00')
  for i in 0..<n {
    let gray = if ch == 1 {
      img.data[i].to_int()
    } else {
      let r = img.data[i * ch].to_int()
      let g = img.data[i * ch + 1].to_int()
      let b = img.data[i * ch + 2].to_int()
      (r * 299 + g * 587 + b * 114) / 1000
    }
    let (cr, cg, cb) = lut[gray]
    out[i * 3] = cr
    out[i * 3 + 1] = cg
    out[i * 3 + 2] = cb
  }
  @types.Image::{
    width: img.width,
    height: img.height,
    channels: 3,
    data: Bytes::from_array(out),
  }
}
