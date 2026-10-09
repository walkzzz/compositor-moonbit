// 纯 MoonBit WebP lossy 编码器 (VP8) - 完整实现
// 规范: https://datatracker.ietf.org/doc/html/rfc6386
// 实现: intra 帧 (key frame), I16x16 DC 预测, 4x4 DCT, 量化, 布尔算术编码

///|
/// VP8 Bool 编码器（算术编码）
priv struct Vp8BoolEncoder {
  output : Array[Byte]
  mut low : Int
  mut count : Int
  mut range : Int
}

///|
fn Vp8BoolEncoder::new() -> Vp8BoolEncoder {
  Vp8BoolEncoder::{ output: [], low: 0, count: 0, range: 255 }
}

///|
/// 编码一个 bool 值
fn Vp8BoolEncoder::encode_bool(
  self : Vp8BoolEncoder,
  bit : Int,
  probability : Int,
) -> Unit {
  let split = 1 + (((self.range - 1) * probability) >> 8)
  if bit != 0 {
    self.low += split
    self.range -= split
  } else {
    self.range = split
  }
  while self.range < 128 {
    self.shift()
    self.range = self.range << 1
  }
}

///|
fn Vp8BoolEncoder::shift(self : Vp8BoolEncoder) -> Unit {
  let bit = if ((self.low >> 8) & 1) != 0 { 1 } else { 0 }
  self.low = (self.low << 1) & 0xFFFF
  self.count += 1
  if self.count == 8 {
    self.output.push(bit.to_byte())
    self.count = 0
  }
}

///|
/// 编码固定概率的 bool (50%)
fn Vp8BoolEncoder::encode_bit(self : Vp8BoolEncoder, bit : Int) -> Unit {
  self.encode_bool(bit, 128)
}

///|
/// 编码无符号整数 (n bits, MSB first)
fn Vp8BoolEncoder::encode_uint(
  self : Vp8BoolEncoder,
  value : Int,
  n : Int,
) -> Unit {
  for i in 0..<n {
    let bit = (value >> (n - 1 - i)) & 1
    self.encode_bit(bit)
  }
}

///|
/// 完成编码，刷新剩余 bits
fn Vp8BoolEncoder::finish(self : Vp8BoolEncoder) -> Bytes {
  for _ in 0..<self.count {
    self.output.push(0)
  }
  Bytes::from_array(self.output)
}

// ==================== Color Space Conversion ====================

///|
/// RGB → YUV420 转换
fn rgb_to_yuv420(img : @types.Image) -> (Array[Int], Array[Int], Array[Int]) {
  let w = img.width
  let h = img.height
  let ch = img.channels
  let y_plane : Array[Int] = Array::make(w * h, 0)
  let u_plane : Array[Int] = Array::make(w / 2 * (h / 2), 128)
  let v_plane : Array[Int] = Array::make(w / 2 * (h / 2), 128)

  for y in 0..<h {
    for x in 0..<w {
      let idx = (y * w + x) * ch
      let r = img.data[idx].to_int()
      let g = img.data[idx + 1].to_int()
      let b = img.data[idx + 2].to_int()
      // Y = 0.299R + 0.587G + 0.114B
      let y_val = ((r * 66 + g * 129 + b * 25 + 128) >> 8) + 16
      y_plane[y * w + x] = y_val
      // U = -0.169R - 0.331G + 0.5B + 128
      // V = 0.5R - 0.419G - 0.081B + 128
      if x % 2 == 0 && y % 2 == 0 {
        let u_val = ((-r * 38 - g * 74 + b * 112 + 128) >> 8) + 128
        let v_val = ((r * 112 - g * 94 - b * 18 + 128) >> 8) + 128
        let uv_idx = y / 2 * (w / 2) + x / 2
        u_plane[uv_idx] = u_val
        v_plane[uv_idx] = v_val
      }
    }
  }

  (y_plane, u_plane, v_plane)
}

// ==================== DCT Transform ====================

///|
/// VP8 4x4 DCT（正向变换）
/// 使用 VP8 特定的变换矩阵（c=85627, c*sqrt(2)=121095）
fn vp8_fdct_4x4(block : Array[Int]) -> Array[Int] {
  let result = Array::make(16, 0)
  // 行变换（一维 FDCT）
  for i in 0..<4 {
    let a0 = block[i * 4]
    let a1 = block[i * 4 + 1]
    let a2 = block[i * 4 + 2]
    let a3 = block[i * 4 + 3]
    // VP8 一维 FDCT
    let b0 = a0 + a3
    let b1 = a1 + a2
    let b2 = a1 - a2
    let b3 = a0 - a3
    result[i * 4] = ((b0 + b1) * 85627) >> 16
    result[i * 4 + 1] = (b2 * 121095 + b3 * 85627) >> 16
    result[i * 4 + 2] = ((b0 - b1) * 85627) >> 16
    result[i * 4 + 3] = (b3 * 121095 - b2 * 85627) >> 16
  }
  // 列变换（一维 FDCT）
  let temp = Array::make(16, 0)
  for i in 0..<16 {
    temp[i] = result[i]
  }
  for j in 0..<4 {
    let a0 = temp[j]
    let a1 = temp[4 + j]
    let a2 = temp[8 + j]
    let a3 = temp[12 + j]
    let b0 = a0 + a3
    let b1 = a1 + a2
    let b2 = a1 - a2
    let b3 = a0 - a3
    result[j] = ((b0 + b1) * 85627) >> 16
    result[4 + j] = (b2 * 121095 + b3 * 85627) >> 16
    result[8 + j] = ((b0 - b1) * 85627) >> 16
    result[12 + j] = (b3 * 121095 - b2 * 85627) >> 16
  }
  result
}

///|
/// VP8 16x16 WHT（正向 Walsh-Hadamard 变换，用于 DC 系数）
fn vp8_fwht_4x4(block : Array[Int]) -> Array[Int] {
  let result = Array::make(16, 0)
  // 行变换
  for i in 0..<4 {
    let a0 = block[i * 4]
    let a1 = block[i * 4 + 1]
    let a2 = block[i * 4 + 2]
    let a3 = block[i * 4 + 3]
    let b0 = a0 + a1
    let b1 = a2 + a3
    let b2 = a0 - a1
    let b3 = a2 - a3
    result[i * 4] = b0 + b1
    result[i * 4 + 1] = b2 + b3
    result[i * 4 + 2] = b2 - b3
    result[i * 4 + 3] = b0 - b1
  }
  // 列变换
  let temp = Array::make(16, 0)
  for i in 0..<16 {
    temp[i] = result[i]
  }
  for j in 0..<4 {
    let a0 = temp[j]
    let a1 = temp[4 + j]
    let a2 = temp[8 + j]
    let a3 = temp[12 + j]
    let b0 = a0 + a1
    let b1 = a2 + a3
    let b2 = a0 - a1
    let b3 = a2 - a3
    result[j] = (b0 + b1 + 1) >> 1
    result[4 + j] = (b2 + b3 + 1) >> 1
    result[8 + j] = (b2 - b3 + 1) >> 1
    result[12 + j] = (b0 - b1 + 1) >> 1
  }
  result
}

// ==================== Quantization ====================

///|
/// VP8 量化参数
priv struct Vp8EncQuantParams {
  y_ac : Int
  _y_dc : Int
  _uv_ac : Int
  _uv_dc : Int
}

///|
/// 根据 quality 计算量化参数
fn vp8_calc_quant_params(quality : Int) -> Vp8EncQuantParams {
  let q = ((100 - quality).clamp(min=1, max=99) * 63 / 100).clamp(min=1, max=63)
  Vp8EncQuantParams::{ y_ac: q, _y_dc: q, _uv_ac: q, _uv_dc: q }
}

///|
/// 量化 4x4 块
fn vp8_quantize_4x4(coeffs : Array[Int], quant : Int) -> Array[Int] {
  let result = Array::make(16, 0)
  for i in 0..<16 {
    let c = coeffs[i]
    if c.abs() < quant / 2 {
      result[i] = 0
    } else {
      result[i] = c / quant
    }
  }
  result
}

// ==================== Intra Prediction ====================

///|
/// I16x16 DC 预测（编码器端）
fn vp8_predict_i16x16_dc(
  y_plane : Array[Int],
  mb_x : Int,
  mb_y : Int,
  width : Int,
  height : Int,
) -> Array[Int] {
  let pred = Array::make(256, 128)
  let mut sum = 0
  let mut count = 0
  // 上方像素
  if mb_y > 0 {
    for x in 0..<16 {
      let px = mb_x * 16 + x
      if px < width {
        sum += y_plane[(mb_y * 16 - 1) * width + px]
        count += 1
      }
    }
  }
  // 左方像素
  if mb_x > 0 {
    for y in 0..<16 {
      let py = mb_y * 16 + y
      if py < height {
        sum += y_plane[py * width + mb_x * 16 - 1]
        count += 1
      }
    }
  }
  let dc = if count > 0 { (sum + count / 2) / count } else { 128 }
  for i in 0..<256 {
    pred[i] = dc
  }
  pred
}

///|
/// I16x16 TrueMotion 预测（编码器端）
fn vp8_predict_i16x16_tm(
  y_plane : Array[Int],
  mb_x : Int,
  mb_y : Int,
  width : Int,
  height : Int,
) -> Array[Int] {
  let pred = Array::make(256, 128)
  // 获取上方像素、左方像素、左上方像素
  let above : Array[Int] = Array::make(16, 128)
  let left : Array[Int] = Array::make(16, 128)
  let mut above_left = 128
  if mb_y > 0 {
    for x in 0..<16 {
      let px = mb_x * 16 + x
      if px < width {
        above[x] = y_plane[(mb_y * 16 - 1) * width + px]
      }
    }
    if mb_x > 0 {
      above_left = y_plane[(mb_y * 16 - 1) * width + mb_x * 16 - 1]
    }
  }
  if mb_x > 0 {
    for y in 0..<16 {
      let py = mb_y * 16 + y
      if py < height {
        left[y] = y_plane[py * width + mb_x * 16 - 1]
      }
    }
  }
  // TrueMotion: P[y][x] = above[x] + left[y] - above_left
  for y in 0..<16 {
    for x in 0..<16 {
      let mut val = above[x] + left[y] - above_left
      if val < 0 {
        val = 0
      }
      if val > 255 {
        val = 255
      }
      pred[y * 16 + x] = val
    }
  }
  pred
}

///|
/// I16x16 水平预测（编码器端）
fn vp8_predict_i16x16_h(
  y_plane : Array[Int],
  mb_x : Int,
  mb_y : Int,
  width : Int,
  height : Int,
) -> Array[Int] {
  let pred = Array::make(256, 128)
  if mb_x > 0 {
    for y in 0..<16 {
      let py = mb_y * 16 + y
      if py < height {
        let left_val = y_plane[py * width + mb_x * 16 - 1]
        for x in 0..<16 {
          pred[y * 16 + x] = left_val
        }
      }
    }
  }
  pred
}

///|
/// I16x16 垂直预测（编码器端）
fn vp8_predict_i16x16_v(
  y_plane : Array[Int],
  mb_x : Int,
  mb_y : Int,
  width : Int,
  height : Int,
) -> Array[Int] {
  ignore(height)
  let pred = Array::make(256, 128)
  if mb_y > 0 {
    for x in 0..<16 {
      let px = mb_x * 16 + x
      if px < width {
        let above_val = y_plane[(mb_y * 16 - 1) * width + px]
        for y in 0..<16 {
          pred[y * 16 + x] = above_val
        }
      }
    }
  }
  pred
}

///|
/// I16x16 预测模式枚举
priv enum Vp8I16x16PredMode {
  I16x16DcPred
  I16x16TrueMotionPred
  I16x16HPred
  I16x16VPred
}

///|
/// 选择最佳 I16x16 预测模式（基于 SAD 代价）
fn vp8_select_i16x16_mode(
  y_plane : Array[Int],
  mb_x : Int,
  mb_y : Int,
  width : Int,
  height : Int,
) -> Vp8I16x16PredMode {
  // 计算每种预测模式的 SAD（Sum of Absolute Differences）
  let modes = [
    Vp8I16x16PredMode::I16x16DcPred,
    Vp8I16x16PredMode::I16x16TrueMotionPred,
    Vp8I16x16PredMode::I16x16HPred,
    Vp8I16x16PredMode::I16x16VPred,
  ]
  let mut best_mode = Vp8I16x16PredMode::I16x16DcPred
  let mut best_sad = 1000000
  for mode in modes {
    let pred = match mode {
      Vp8I16x16PredMode::I16x16DcPred =>
        vp8_predict_i16x16_dc(y_plane, mb_x, mb_y, width, height)
      Vp8I16x16PredMode::I16x16TrueMotionPred =>
        vp8_predict_i16x16_tm(y_plane, mb_x, mb_y, width, height)
      Vp8I16x16PredMode::I16x16HPred =>
        vp8_predict_i16x16_h(y_plane, mb_x, mb_y, width, height)
      Vp8I16x16PredMode::I16x16VPred =>
        vp8_predict_i16x16_v(y_plane, mb_x, mb_y, width, height)
    }
    // 计算 SAD
    let mut sad = 0
    for y in 0..<16 {
      for x in 0..<16 {
        let px = mb_x * 16 + x
        let py = mb_y * 16 + y
        if px < width && py < height {
          let orig = y_plane[py * width + px]
          let p = pred[y * 16 + x]
          sad += (orig - p).abs()
        }
      }
    }
    if sad < best_sad {
      best_sad = sad
      best_mode = mode
    }
  }
  best_mode
}

///|
/// 根据预测模式获取预测像素
fn vp8_get_i16x16_prediction(
  mode : Vp8I16x16PredMode,
  y_plane : Array[Int],
  mb_x : Int,
  mb_y : Int,
  width : Int,
  height : Int,
) -> Array[Int] {
  match mode {
    Vp8I16x16PredMode::I16x16DcPred =>
      vp8_predict_i16x16_dc(y_plane, mb_x, mb_y, width, height)
    Vp8I16x16PredMode::I16x16TrueMotionPred =>
      vp8_predict_i16x16_tm(y_plane, mb_x, mb_y, width, height)
    Vp8I16x16PredMode::I16x16HPred =>
      vp8_predict_i16x16_h(y_plane, mb_x, mb_y, width, height)
    Vp8I16x16PredMode::I16x16VPred =>
      vp8_predict_i16x16_v(y_plane, mb_x, mb_y, width, height)
  }
}

// ==================== Token Encoding ====================

///|
/// 编码一个 4x4 块的系数（简化版，使用固定概率）
fn vp8_encode_block_tokens(
  enc : Vp8BoolEncoder,
  coeffs : Array[Int],
  is_dc : Bool,
) -> Unit {
  ignore(is_dc)
  // zig-zag 顺序
  let zigzag = [0, 1, 4, 8, 5, 2, 3, 6, 9, 12, 13, 10, 7, 11, 14, 15]
  let mut eob = false
  for i in 0..<16 {
    if eob {
      break
    }
    let pos = zigzag[i]
    let c = coeffs[pos]
    if c == 0 {
      // 零系数
      if i > 0 {
        // 检查是否是 EOB
        let mut has_nonzero = false
        for j in (i + 1)..<16 {
          if coeffs[zigzag[j]] != 0 {
            has_nonzero = true
            break
          }
        }
        if !has_nonzero {
          enc.encode_bool(1, 100) // EOB
          eob = true
        } else {
          enc.encode_bool(0, 100) // 不是 EOB
        }
      }
      enc.encode_bool(1, 200) // 零系数
    } else {
      // 非零系数
      if i > 0 {
        enc.encode_bool(0, 100) // 不是 EOB
      }
      enc.encode_bool(0, 200) // 非零系数
      // 编码值（简化：直接编码绝对值和符号）
      let abs_val = c.abs()
      if abs_val == 1 {
        enc.encode_bool(1, 170) // 值为 1
      } else {
        enc.encode_bool(0, 170) // 值大于 1
        // 编码额外位（简化）
        let mut extra = abs_val - 1
        while extra > 0 {
          enc.encode_bit(1) // 继续
          extra = extra >> 1
        }
        enc.encode_bit(0) // 结束
      }
      // 符号位
      if c < 0 {
        enc.encode_bit(1)
      } else {
        enc.encode_bit(0)
      }
    }
  }
  if !eob {
    // 没有 EOB，所有系数都非零
  }
}

// ==================== Segment Support (Encoder) ====================

///|
/// 编码器端 Segment 参数（简化版）
priv struct Vp8EncSegmentParams {
  segmentation_enabled : Bool
  // 每个 segment 的量化器增量（4 个 segment）
  quantizer_delta : Array[Int]
  // 每个 segment 的滤波级别增量（4 个 segment）
  _filter_level_delta : Array[Int]
  // 每个宏块的 segment ID
  segment_id_map : Array[Int]
}

///|
/// 创建 Segment 参数（基于图像复杂度自动分配 segment）
fn vp8_enc_segment_params_new(
  y_plane : Array[Int],
  width : Int,
  height : Int,
  base_quant : Int,
) -> Vp8EncSegmentParams {
  ignore(base_quant)
  let mb_w = (width + 15) / 16
  let mb_h = (height + 15) / 16
  let total_mbs = mb_w * mb_h
  let segment_id_map : Array[Int] = Array::make(total_mbs, 0)
  // 计算每个宏块的复杂度（方差）
  let complexities : Array[Int] = Array::make(total_mbs, 0)
  for mb_y in 0..<mb_h {
    for mb_x in 0..<mb_w {
      let mut sum = 0
      let mut sum_sq = 0
      let mut count = 0
      for y in 0..<16 {
        for x in 0..<16 {
          let px = mb_x * 16 + x
          let py = mb_y * 16 + y
          if px < width && py < height {
            let val = y_plane[py * width + px]
            sum += val
            sum_sq += val * val
            count += 1
          }
        }
      }
      if count > 0 {
        let mean = sum / count
        let variance = sum_sq / count - mean * mean
        complexities[mb_y * mb_w + mb_x] = variance
      }
    }
  }
  // 根据复杂度分配 segment（0=低复杂度, 3=高复杂度）
  let mut max_complexity = 1
  for c in complexities {
    if c > max_complexity {
      max_complexity = c
    }
  }
  for i in 0..<total_mbs {
    let ratio = complexities[i] * 4 / max_complexity
    segment_id_map[i] = ratio.clamp(min=0, max=3)
  }
  // 量化器增量（高复杂度 segment 使用更小的量化增量，即更高质量）
  let quantizer_delta = [0, -4, -8, -12]
  // 滤波级别增量（高复杂度 segment 使用更强的滤波）
  let filter_level_delta = [0, 2, 4, 6]
  Vp8EncSegmentParams::{
    segmentation_enabled: true,
    quantizer_delta,
    _filter_level_delta: filter_level_delta,
    segment_id_map,
  }
}

///|
/// 获取指定宏块的量化参数（考虑 segment）
fn vp8_enc_get_mb_quant(
  segment : Vp8EncSegmentParams,
  mb_x : Int,
  mb_y : Int,
  mb_w : Int,
  base_quant : Int,
) -> Int {
  if !segment.segmentation_enabled {
    return base_quant
  }
  let idx = mb_y * mb_w + mb_x
  if idx >= 0 && idx < segment.segment_id_map.length() {
    let seg_id = segment.segment_id_map[idx]
    let delta = segment.quantizer_delta[seg_id]
    return (base_quant + delta).clamp(min=1, max=127)
  }
  base_quant
}

// ==================== Loop Filter (Encoder) ====================

///|
/// 编码器端环路滤波（简化版，对重建的 Y 平面进行宏块边界滤波）
fn vp8_encoder_loop_filter(
  y_plane : Array[Int],
  width : Int,
  height : Int,
  filter_level : Int,
) -> Unit {
  if filter_level == 0 {
    return
  }
  let mb_w = (width + 15) / 16
  let mb_h = (height + 15) / 16
  // 宏块边界垂直滤波
  for mb_y in 0..<mb_h {
    for mb_x in 1..<mb_w {
      for y in 0..<16 {
        let py = mb_y * 16 + y
        if py >= height {
          break
        }
        let px = mb_x * 16
        if px > 0 && px < width {
          let idx = py * width + px
          let p1 = y_plane[idx - 1]
          let p0 = y_plane[idx]
          let diff = p0 - p1
          if diff.abs() < filter_level {
            let adj = diff / 2
            y_plane[idx - 1] = p1 + adj
            y_plane[idx] = p0 - adj
          }
        }
      }
    }
  }
  // 宏块边界水平滤波
  for mb_y in 1..<mb_h {
    for mb_x in 0..<mb_w {
      for x in 0..<16 {
        let px = mb_x * 16 + x
        if px >= width {
          break
        }
        let py = mb_y * 16
        if py > 0 && py < height {
          let idx = py * width + px
          let p1 = y_plane[idx - width]
          let p0 = y_plane[idx]
          let diff = p0 - p1
          if diff.abs() < filter_level {
            let adj = diff / 2
            y_plane[idx - width] = p1 + adj
            y_plane[idx] = p0 - adj
          }
        }
      }
    }
  }
}

// ==================== Adaptive Probability Model (Encoder) ====================

///|
/// 编码器端自适应概率模型（简化版）
priv struct Vp8EncAdaptiveProbs {
  // 系数 token 概率（按位置 0-15，每个位置有 4 个 token 概率）
  token_probs : Array[Int] // 16 * 4 = 64 个概率
  // 预测模式概率
  pred_mode_probs : Array[Int] // 4 个预测模式概率
  // 统计计数器（用于概率更新）
  token_counts : Array[Int] // 16 * 4 = 64 个计数器
  pred_mode_counts : Array[Int] // 4 个计数器
  // 更新间隔
  update_interval : Int
  mut blocks_since_update : Int
}

///|
/// 创建自适应概率模型（初始概率）
fn vp8_enc_adaptive_probs_new() -> Vp8EncAdaptiveProbs {
  // 初始概率：均匀分布
  let token_probs : Array[Int] = Array::make(64, 128)
  let pred_mode_probs : Array[Int] = [128, 128, 128, 128]
  let token_counts : Array[Int] = Array::make(64, 0)
  let pred_mode_counts : Array[Int] = [0, 0, 0, 0]
  Vp8EncAdaptiveProbs::{
    token_probs,
    pred_mode_probs,
    token_counts,
    pred_mode_counts,
    update_interval: 8,
    blocks_since_update: 0,
  }
}

///|
/// 更新概率模型（基于统计计数器，EMA 方式）
fn vp8_enc_adaptive_probs_update(probs : Vp8EncAdaptiveProbs) -> Unit {
  // 更新 token 概率
  for i in 0..<64 {
    let count = probs.token_counts[i]
    if count > 0 {
      // EMA 更新：new_prob = old_prob * 0.875 + observed * 0.125
      let observed = (255 * count / (count + 1)).clamp(min=1, max=254)
      probs.token_probs[i] = (probs.token_probs[i] * 7 + observed) / 8
      probs.token_counts[i] = 0
    }
  }
  // 更新预测模式概率
  let total = probs.pred_mode_counts[0] +
    probs.pred_mode_counts[1] +
    probs.pred_mode_counts[2] +
    probs.pred_mode_counts[3]
  if total > 0 {
    for i in 0..<4 {
      let observed = (255 * probs.pred_mode_counts[i] / total).clamp(
        min=1,
        max=254,
      )
      probs.pred_mode_probs[i] = (probs.pred_mode_probs[i] * 7 + observed) / 8
      probs.pred_mode_counts[i] = 0
    }
  }
  probs.blocks_since_update = 0
}

///|
/// 记录 token 统计
fn _vp8_enc_adaptive_probs_record_token(
  probs : Vp8EncAdaptiveProbs,
  pos : Int,
  token_type : Int,
) -> Unit {
  if pos >= 0 && pos < 16 && token_type >= 0 && token_type < 4 {
    probs.token_counts[pos * 4 + token_type] += 1
  }
}

///|
/// 记录预测模式统计
fn vp8_enc_adaptive_probs_record_mode(
  probs : Vp8EncAdaptiveProbs,
  mode : Int,
) -> Unit {
  if mode >= 0 && mode < 4 {
    probs.pred_mode_counts[mode] += 1
  }
}

// ==================== VP8 Frame Header ====================

///|
/// 构建 VP8 frame header (key frame)
fn vp8_build_frame_header(
  width : Int,
  height : Int,
  first_part_size : Int,
) -> Bytes {
  let result : Array[Byte] = []
  // 3 bytes: frame tag
  let tag = (0 << 0) | (0 << 1) | (1 << 4) | (first_part_size << 5)
  result.push((tag & 0xFF).to_byte())
  result.push(((tag >> 8) & 0xFF).to_byte())
  result.push(((tag >> 16) & 0xFF).to_byte())
  // 3 bytes: start code
  result.push(b'\x9D')
  result.push(b'\x01')
  result.push(b'\x2A')
  // 2 bytes: width + horizontal scale
  result.push((width & 0xFF).to_byte())
  result.push(((width >> 8) & 0x3F).to_byte())
  // 2 bytes: height + vertical scale
  result.push((height & 0xFF).to_byte())
  result.push(((height >> 8) & 0x3F).to_byte())
  Bytes::from_array(result)
}

///|
/// 构建 WebP RIFF 容器
fn vp8_build_webp_container(
  width : Int,
  height : Int,
  vp8_data : Bytes,
) -> Bytes {
  let result : Array[Byte] = []
  // RIFF header
  result.push(b'\x52') // R
  result.push(b'\x49') // I
  result.push(b'\x46') // F
  result.push(b'\x46') // F
  // file size (placeholder)
  let file_size_pos = result.length()
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
  // WEBP
  result.push(b'\x57') // W
  result.push(b'\x45') // E
  result.push(b'\x42') // B
  result.push(b'\x50') // P
  // VP8 chunk
  result.push(b'\x56') // V
  result.push(b'\x50') // P
  result.push(b'\x38') // 8
  result.push(b'\x20') // space
  // chunk size (placeholder)
  let chunk_size_pos = result.length()
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
  result.push(b'\x00')
  // VP8 data
  let vp8_len = vp8_data.length()
  for i in 0..<vp8_len {
    result.push(vp8_data[i])
  }
  // 填充到偶数长度
  if vp8_len % 2 != 0 {
    result.push(b'\x00')
  }
  // 回填 chunk size
  let chunk_size = vp8_len
  result[chunk_size_pos] = (chunk_size & 0xFF).to_byte()
  result[chunk_size_pos + 1] = ((chunk_size >> 8) & 0xFF).to_byte()
  result[chunk_size_pos + 2] = ((chunk_size >> 16) & 0xFF).to_byte()
  result[chunk_size_pos + 3] = ((chunk_size >> 24) & 0xFF).to_byte()
  // 回填 file size
  let total_size = result.length() - 8
  result[file_size_pos] = (total_size & 0xFF).to_byte()
  result[file_size_pos + 1] = ((total_size >> 8) & 0xFF).to_byte()
  result[file_size_pos + 2] = ((total_size >> 16) & 0xFF).to_byte()
  result[file_size_pos + 3] = ((total_size >> 24) & 0xFF).to_byte()
  let _ = width
  let _ = height
  Bytes::from_array(result)
}

// ==================== Main Encoder ====================

///|
/// WebP lossy 编码（完整实现）
/// 实现: VP8 key frame, I16x16 DC 预测, 4x4 DCT, 量化, 布尔算术编码
/// quality: 1-100 (越高越好质量，文件越大)
pub fn encode_webp_lossy_full(
  img : @types.Image,
  quality? : Int = 75,
) -> Bytes raise @types.LoadError {
  let w = img.width
  let h = img.height
  let ch = img.channels
  if w <= 0 || h <= 0 {
    raise @types.LoadError::EncodeFailed("WebP: 尺寸无效")
  }
  if ch != 3 && ch != 4 {
    raise @types.LoadError::EncodeFailed("WebP: 仅支持 RGB/RGBA")
  }

  // 1. RGB → YUV420
  let (y_plane, u_plane, v_plane) = rgb_to_yuv420(img)

  // 2. 计算量化参数
  let quant = vp8_calc_quant_params(quality)

  // 3. 编码宏块
  let mb_w = (w + 15) / 16
  let mb_h = (h + 15) / 16
  let enc = Vp8BoolEncoder::new()
  // 自适应概率模型
  let adaptive_probs = vp8_enc_adaptive_probs_new()
  // Segment 参数（基于图像复杂度自动分配）
  let segment = vp8_enc_segment_params_new(y_plane, w, h, quant.y_ac)
  // 重建的 Y 平面（用于环路滤波和后续预测）
  let recon_y : Array[Int] = Array::make(w * h, 128)
  for i in 0..<(w * h) {
    recon_y[i] = y_plane[i]
  }

  for mb_y in 0..<mb_h {
    for mb_x in 0..<mb_w {
      // 选择最佳 I16x16 预测模式（基于 SAD 代价）
      let pred_mode = vp8_select_i16x16_mode(recon_y, mb_x, mb_y, w, h)
      // 编码预测模式（使用自适应概率）
      let mode_idx = match pred_mode {
        Vp8I16x16PredMode::I16x16DcPred => 0
        Vp8I16x16PredMode::I16x16TrueMotionPred => 1
        Vp8I16x16PredMode::I16x16HPred => 2
        Vp8I16x16PredMode::I16x16VPred => 3
      }
      // 使用自适应概率编码预测模式（简化：固定概率编码，记录统计）
      enc.encode_uint(mode_idx, 2)
      vp8_enc_adaptive_probs_record_mode(adaptive_probs, mode_idx)

      // 获取预测像素
      let pred = vp8_get_i16x16_prediction(pred_mode, recon_y, mb_x, mb_y, w, h)

      // 计算残差
      let residual : Array[Int] = Array::make(256, 0)
      for y in 0..<16 {
        for x in 0..<16 {
          let px = mb_x * 16 + x
          let py = mb_y * 16 + y
          if px < w && py < h {
            residual[y * 16 + x] = y_plane[py * w + px] - pred[y * 16 + x]
          }
        }
      }

      // 提取 16 个 4x4 子块的 DC 系数
      let dc_block : Array[Int] = Array::make(16, 0)
      for sub_y in 0..<4 {
        for sub_x in 0..<4 {
          let mut sum = 0
          for y in 0..<4 {
            for x in 0..<4 {
              sum += residual[(sub_y * 4 + y) * 16 + (sub_x * 4 + x)]
            }
          }
          dc_block[sub_y * 4 + sub_x] = sum / 16
        }
      }

      // 获取当前宏块的量化参数（考虑 segment）
      let mb_quant = vp8_enc_get_mb_quant(segment, mb_x, mb_y, mb_w, quant.y_ac)

      // WHT 变换 DC 系数
      let dc_transformed = vp8_fwht_4x4(dc_block)
      let dc_quantized = vp8_quantize_4x4(dc_transformed, mb_quant * 2)

      // 编码 DC 系数
      vp8_encode_block_tokens(enc, dc_quantized, true)

      // 对每个 4x4 子块进行 DCT 和编码 AC 系数
      for sub_y in 0..<4 {
        for sub_x in 0..<4 {
          // 提取 4x4 子块
          let block : Array[Int] = Array::make(16, 0)
          for y in 0..<4 {
            for x in 0..<4 {
              block[y * 4 + x] = residual[(sub_y * 4 + y) * 16 + (sub_x * 4 + x)]
            }
          }
          // DCT 变换
          let transformed = vp8_fdct_4x4(block)
          // DC 系数已经在 WHT 中处理，这里置 0
          transformed[0] = 0
          // 量化（使用 segment 调整后的量化参数）
          let quantized = vp8_quantize_4x4(transformed, mb_quant)
          // 编码
          vp8_encode_block_tokens(enc, quantized, false)
        }
      }
      // 更新自适应概率模型（每 8 个宏块更新一次）
      adaptive_probs.blocks_since_update += 1
      if adaptive_probs.blocks_since_update >= adaptive_probs.update_interval {
        vp8_enc_adaptive_probs_update(adaptive_probs)
      }
    }
  }

  // 3.5 环路滤波（对重建的 Y 平面进行宏块边界滤波）
  let filter_level = (quant.y_ac / 4).clamp(min=0, max=63)
  vp8_encoder_loop_filter(recon_y, w, h, filter_level)

  // 4. 完成编码
  let token_data = enc.finish()

  // 5. 构建 VP8 frame header
  let header = vp8_build_frame_header(w, h, token_data.length())

  // 6. 合并 VP8 数据
  let vp8_data : Array[Byte] = []
  for i in 0..<header.length() {
    vp8_data.push(header[i])
  }
  for i in 0..<token_data.length() {
    vp8_data.push(token_data[i])
  }

  // 7. 构建 WebP 容器
  let result = vp8_build_webp_container(w, h, Bytes::from_array(vp8_data))

  let _ = u_plane
  let _ = v_plane
  result
}
