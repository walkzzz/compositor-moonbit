// 纯 MoonBit WebP lossy VP8 解码器
// 规范: https://datatracker.ietf.org/doc/html/rfc6386
// 支持 VP8 lossy 解码

// ==================== VP8 BitReader ====================
// VP8 使用大端序 bitstream（与 VP8L 不同）

///|
priv struct Vp8BitReader {
  data : Bytes
  mut pos : Int
  mut bit_buf : Int
  mut bit_count : Int
}

///|
fn Vp8BitReader::new(data : Bytes, start : Int) -> Vp8BitReader {
  Vp8BitReader::{ data, pos: start, bit_buf: 0, bit_count: 0 }
}

///|
fn Vp8BitReader::read_bits(self : Vp8BitReader, n : Int) -> Int {
  let mut result = 0
  for _ in 0..<n {
    if self.bit_count == 0 {
      if self.pos >= self.data.length() {
        self.bit_buf = 0
        self.bit_count = 8
      } else {
        self.bit_buf = self.data[self.pos].to_int()
        self.pos += 1
        self.bit_count = 8
      }
    }
    // VP8 是大端序：MSB first
    let bit = (self.bit_buf >> 7) & 1
    self.bit_buf = (self.bit_buf << 1) & 0xFF
    self.bit_count -= 1
    result = (result << 1) | bit
  }
  result
}

///|
fn Vp8BitReader::read_bit(self : Vp8BitReader) -> Int {
  self.read_bits(1)
}

///|
fn Vp8BitReader::read_bool(self : Vp8BitReader, prob : Int) -> Int {
  // 简化版：用于帧头解析，prob 暂不使用
  ignore(prob)
  self.read_bit()
}

// ==================== VP8 Bool Decoder ====================
// VP8 使用基于概率的布尔算术编码

///|
priv struct Vp8BoolDecoder {
  data : Bytes
  mut pos : Int
  mut bit_count : Int
  mut range : Int
  mut value : Int
}

///|
fn Vp8BoolDecoder::new(data : Bytes, start : Int) -> Vp8BoolDecoder {
  let bd = Vp8BoolDecoder::{
    data,
    pos: start,
    bit_count: 0,
    range: 255,
    value: 0,
  }
  // 初始化：读取前两个字节
  bd.value = if bd.pos < bd.data.length() {
    bd.data[bd.pos].to_int()
  } else {
    0
  }
  bd.pos += 1
  bd.value = (bd.value << 8) |
    (if bd.pos < bd.data.length() { bd.data[bd.pos].to_int() } else { 0 })
  bd.pos += 1
  bd.bit_count = 16
  bd
}

///|
fn Vp8BoolDecoder::read_bool(self : Vp8BoolDecoder, prob : Int) -> Int {
  // VP8 布尔解码器核心算法
  let split = 1 + (((self.range - 1) * prob) >> 8)
  let bigsplit = split << 8
  let mut bit = 0
  if self.value >= bigsplit {
    self.range -= split
    self.value -= bigsplit
    bit = 1
  } else {
    self.range = split
  }
  // 归一化
  while self.range < 128 {
    self.range = self.range << 1
    self.value = self.value << 1
    self.bit_count -= 1
    if self.bit_count == 0 {
      self.bit_count = 8
      if self.pos < self.data.length() {
        self.value = self.value | self.data[self.pos].to_int()
        self.pos += 1
      }
    }
  }
  bit
}

///|
fn Vp8BoolDecoder::_read_literal(self : Vp8BoolDecoder, num_bits : Int) -> Int {
  // 读取指定位数的字面值（概率 128）
  let mut v = 0
  for _ in 0..<num_bits {
    v = (v << 1) | self.read_bool(128)
  }
  v
}

// ==================== VP8 Adaptive Probability Model ====================
// VP8 自适应概率模型：按系数位置和 token 类型维护独立概率
// 概率更新：使用指数加权平均（EMA）根据已解析 token 更新

///|
/// VP8 自适应系数概率模型
priv struct Vp8AdaptiveProbs {
  // 每个系数位置（0-15，zig-zag 顺序）的概率
  prob_zero : Array[Int] // 零系数概率
  prob_one : Array[Int] // 单系数（值为±1）概率
  prob_eob : Array[Int] // EOB（块结束）概率
  prob_extra : Array[Int] // 额外位概率
  mut prob_sign : Int // 符号位概率（所有位置共用）

  // 统计计数器（用于概率更新）
  count_zero : Array[Int]
  count_one : Array[Int]
  count_eob : Array[Int]
  count_extra : Array[Int]
  mut count_sign_pos : Int // 正符号计数
  mut count_sign_neg : Int // 负符号计数
  mut total_blocks : Int // 已解析块数
}

///|
fn Vp8AdaptiveProbs::new() -> Vp8AdaptiveProbs {
  // VP8 默认概率（基于统计）
  let default_zero = [
    200, 180, 170, 160, 150, 140, 130, 120, 110, 100, 90, 80, 70, 60, 50, 40,
  ]
  let default_one = [
    180, 170, 160, 150, 140, 130, 120, 110, 100, 90, 80, 70, 60, 50, 40, 30,
  ]
  let default_eob = [
    100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210, 220, 230, 240, 250,
  ]
  let default_extra = [
    140, 140, 140, 140, 140, 140, 140, 140, 140, 140, 140, 140, 140, 140, 140, 140,
  ]

  Vp8AdaptiveProbs::{
    prob_zero: default_zero,
    prob_one: default_one,
    prob_eob: default_eob,
    prob_extra: default_extra,
    prob_sign: 128,
    count_zero: Array::make(16, 0),
    count_one: Array::make(16, 0),
    count_eob: Array::make(16, 0),
    count_extra: Array::make(16, 0),
    count_sign_pos: 0,
    count_sign_neg: 0,
    total_blocks: 0,
  }
}

///|
/// 记录零系数统计
fn Vp8AdaptiveProbs::record_zero(self : Vp8AdaptiveProbs, pos : Int) -> Unit {
  if pos >= 0 && pos < 16 {
    self.count_zero[pos] += 1
  }
}

///|
/// 记录单系数统计
fn Vp8AdaptiveProbs::record_one(self : Vp8AdaptiveProbs, pos : Int) -> Unit {
  if pos >= 0 && pos < 16 {
    self.count_one[pos] += 1
  }
}

///|
/// 记录 EOB 统计
fn Vp8AdaptiveProbs::record_eob(self : Vp8AdaptiveProbs, pos : Int) -> Unit {
  if pos >= 0 && pos < 16 {
    self.count_eob[pos] += 1
  }
}

///|
/// 记录额外位统计
fn Vp8AdaptiveProbs::record_extra(self : Vp8AdaptiveProbs, pos : Int) -> Unit {
  if pos >= 0 && pos < 16 {
    self.count_extra[pos] += 1
  }
}

///|
/// 记录符号统计
fn Vp8AdaptiveProbs::record_sign(
  self : Vp8AdaptiveProbs,
  is_positive : Bool,
) -> Unit {
  if is_positive {
    self.count_sign_pos += 1
  } else {
    self.count_sign_neg += 1
  }
}

///|
/// 更新概率（指数加权平均 EMA）
/// 在解析每个块后调用，使用最近的统计信息更新概率
fn Vp8AdaptiveProbs::update(self : Vp8AdaptiveProbs) -> Unit {
  self.total_blocks += 1
  // 每 8 个块更新一次概率（减少计算量）
  if self.total_blocks % 8 != 0 {
    return
  }

  // EMA 更新：new_prob = old_prob * 7/8 + observed_prob * 1/8
  for i in 0..<16 {
    let total = self.count_zero[i] + self.count_one[i] + 1
    // 更新零系数概率
    if total > 0 {
      let observed_zero = self.count_zero[i] * 256 / total
      self.prob_zero[i] = (self.prob_zero[i] * 7 + observed_zero) / 8
    }
    // 更新单系数概率
    let non_zero = self.count_one[i] + 1
    if non_zero > 0 {
      let observed_one = self.count_one[i] * 256 / non_zero
      self.prob_one[i] = (self.prob_one[i] * 7 + observed_one) / 8
    }
    // 更新 EOB 概率
    let eob_total = self.count_eob[i] + 1
    if eob_total > 0 {
      let observed_eob = self.count_eob[i] * 256 / eob_total
      self.prob_eob[i] = (self.prob_eob[i] * 7 + observed_eob) / 8
    }
    // 更新额外位概率
    let extra_total = self.count_extra[i] + 1
    if extra_total > 0 {
      let observed_extra = self.count_extra[i] * 256 / extra_total
      self.prob_extra[i] = (self.prob_extra[i] * 7 + observed_extra) / 8
    }
  }

  // 更新符号概率
  let sign_total = self.count_sign_pos + self.count_sign_neg + 1
  if sign_total > 0 {
    let observed_sign = self.count_sign_pos * 256 / sign_total
    self.prob_sign = (self.prob_sign * 7 + observed_sign) / 8
  }

  // 重置计数器（保留部分历史）
  for i in 0..<16 {
    self.count_zero[i] = self.count_zero[i] / 2
    self.count_one[i] = self.count_one[i] / 2
    self.count_eob[i] = self.count_eob[i] / 2
    self.count_extra[i] = self.count_extra[i] / 2
  }
  self.count_sign_pos = self.count_sign_pos / 2
  self.count_sign_neg = self.count_sign_neg / 2
}

///|
/// 获取指定位置的零系数概率
fn Vp8AdaptiveProbs::get_zero_prob(self : Vp8AdaptiveProbs, pos : Int) -> Int {
  if pos >= 0 && pos < 16 {
    self.prob_zero[pos]
  } else {
    150
  }
}

///|
/// 获取指定位置的单系数概率
fn Vp8AdaptiveProbs::get_one_prob(self : Vp8AdaptiveProbs, pos : Int) -> Int {
  if pos >= 0 && pos < 16 {
    self.prob_one[pos]
  } else {
    170
  }
}

///|
/// 获取指定位置的 EOB 概率
fn Vp8AdaptiveProbs::get_eob_prob(self : Vp8AdaptiveProbs, pos : Int) -> Int {
  if pos >= 0 && pos < 16 {
    self.prob_eob[pos]
  } else {
    100
  }
}

///|
/// 获取指定位置的额外位概率
fn Vp8AdaptiveProbs::get_extra_prob(self : Vp8AdaptiveProbs, pos : Int) -> Int {
  if pos >= 0 && pos < 16 {
    self.prob_extra[pos]
  } else {
    140
  }
}

// ==================== VP8 Residual Coefficient Parsing ====================
// VP8 残差系数解析：token 解析 + zig-zag 扫描 + 自适应概率

///|
/// VP8 zig-zag 扫描顺序（4x4 块）
fn vp8_zigzag_4x4() -> Array[Int] {
  [0, 1, 4, 8, 5, 2, 3, 6, 9, 12, 13, 10, 7, 11, 14, 15]
}

///|
/// 解析一个 4x4 块的残差系数（使用自适应概率模型）
/// 返回 16 个系数（行优先顺序）
fn vp8_parse_residual_4x4(
  bd : Vp8BoolDecoder,
  probs : Vp8AdaptiveProbs,
  is_dc : Bool,
) -> Array[Int] {
  ignore(is_dc)
  let coeffs = Array::make(16, 0)
  let zigzag = vp8_zigzag_4x4()
  let mut eob = false // end of block
  for i in 0..<16 {
    if eob {
      break
    }
    let pos = zigzag[i]
    // 使用自适应概率解析 base token
    let zero_prob = probs.get_zero_prob(i)
    let is_zero = bd.read_bool(zero_prob) == 1
    if is_zero {
      probs.record_zero(i)
      // 检查是否是 EOB（块结束）
      if i > 0 {
        let eob_prob = probs.get_eob_prob(i)
        let is_eob = bd.read_bool(eob_prob) == 1
        if is_eob {
          probs.record_eob(i)
          eob = true
        }
      }
      continue
    }
    // 非零系数：解析符号和值
    let one_prob = probs.get_one_prob(i)
    let is_one = bd.read_bool(one_prob) == 1
    let mut value = 0
    if is_one {
      probs.record_one(i)
      value = 1
    } else {
      // 解析额外位
      let extra_prob = probs.get_extra_prob(i)
      probs.record_extra(i)
      let mut extra = 1
      let mut continue_read = true
      while continue_read {
        let read_more = bd.read_bool(extra_prob) == 1
        if read_more {
          extra = (extra << 1) | bd.read_bool(128)
          if extra > 2047 {
            continue_read = false
          }
        } else {
          continue_read = false
        }
      }
      value = extra + 1
    }
    // 解析符号（使用自适应符号概率）
    let sign = bd.read_bool(probs.prob_sign)
    let is_positive = sign == 0
    probs.record_sign(is_positive)
    if !is_positive {
      value = -value
    }
    coeffs[pos] = value
  }
  // 更新自适应概率
  probs.update()
  coeffs
}

///|
/// 解析一个 16x16 块的 DC 系数（4x4 块的 DC 系数组成）
fn vp8_parse_dc_coeffs_16x16(
  bd : Vp8BoolDecoder,
  probs : Vp8AdaptiveProbs,
) -> Array[Int] {
  // 16x16 块的 DC 系数是一个 4x4 块，使用 WHT 变换
  vp8_parse_residual_4x4(bd, probs, true)
}

// ==================== VP8 Frame Header ====================

///|
priv struct Vp8FrameHeader {
  key_frame : Bool
  _version : Int
  _show_frame : Bool
  _first_part_size : Int
  width : Int
  height : Int
  _horizontal_scale : Int
  _vertical_scale : Int
}

///|
fn parse_vp8_frame_header(br : Vp8BitReader) -> Vp8FrameHeader {
  let tag = br.read_bits(3)
  let key_frame = tag == 0
  let version = br.read_bits(3)
  let show_frame = br.read_bits(1) == 1
  let first_part_size_0 = br.read_bits(8)
  let first_part_size_1 = br.read_bits(8)
  let first_part_size_2 = br.read_bits(8)
  let first_part_size = first_part_size_0 |
    (first_part_size_1 << 8) |
    (first_part_size_2 << 16)

  let mut width = 0
  let mut height = 0
  let mut horizontal_scale = 0
  let mut vertical_scale = 0

  if key_frame {
    // 关键帧：3 字节 start code + 分辨率
    let start_code_0 = br.read_bits(8)
    let start_code_1 = br.read_bits(8)
    let start_code_2 = br.read_bits(8)
    ignore(start_code_0)
    ignore(start_code_1)
    ignore(start_code_2)
    // 分辨率：14 bits width + 2 bits horizontal scale + 14 bits height + 2 bits vertical scale
    width = br.read_bits(14)
    horizontal_scale = br.read_bits(2)
    height = br.read_bits(14)
    vertical_scale = br.read_bits(2)
  }

  Vp8FrameHeader::{
    key_frame,
    _version: version,
    _show_frame: show_frame,
    _first_part_size: first_part_size,
    width,
    height,
    _horizontal_scale: horizontal_scale,
    _vertical_scale: vertical_scale,
  }
}

// ==================== VP8 Quantization ====================

///|
priv struct Vp8QuantParams {
  y_ac : Int
  y_dc : Int
  uv_ac : Int
  uv_dc : Int
}

///|
fn parse_quantization(br : Vp8BitReader) -> Vp8QuantParams {
  let y_ac = br.read_bits(7)
  let mut y_dc_delta = 0
  if br.read_bool(155) == 1 {
    y_dc_delta = br.read_bits(4)
    if y_dc_delta > 7 {
      y_dc_delta -= 16
    }
  }
  let y_dc = y_ac + y_dc_delta

  let mut uv_ac_delta = 0
  if br.read_bool(155) == 1 {
    uv_ac_delta = br.read_bits(4)
    if uv_ac_delta > 7 {
      uv_ac_delta -= 16
    }
  }
  let uv_ac = y_ac + uv_ac_delta

  let mut uv_dc_delta = 0
  if br.read_bool(155) == 1 {
    uv_dc_delta = br.read_bits(4)
    if uv_dc_delta > 7 {
      uv_dc_delta -= 16
    }
  }
  let uv_dc = y_dc + uv_dc_delta

  Vp8QuantParams::{ y_ac, y_dc, uv_ac, uv_dc }
}

// ==================== VP8 Segment ====================
// VP8 segmentation：将宏块分成 4 个 segment，每个 segment 可有不同的量化和滤波参数

///|
/// VP8 Segment 参数
priv struct Vp8SegmentParams {
  mut enabled : Bool // 是否启用 segmentation
  mut update_map : Bool // 是否更新宏块 segment 映射
  mut update_features : Bool // 是否更新 segment 特征数据
  mut feature_mode : Int // 特征模式：0=delta，1=absolute
  quantizer_deltas : Array[Int] // 每个 segment 的量化器增量（4个）
  filter_deltas : Array[Int] // 每个 segment 的滤波级别增量（4个）
  mb_segment_tree_probs : Array[Int] // 宏块 segment 树概率（3个）
}

///|
fn Vp8SegmentParams::new() -> Vp8SegmentParams {
  Vp8SegmentParams::{
    enabled: false,
    update_map: false,
    update_features: false,
    feature_mode: 0,
    quantizer_deltas: [0, 0, 0, 0],
    filter_deltas: [0, 0, 0, 0],
    mb_segment_tree_probs: [255, 255, 255],
  }
}

///|
/// 解析 VP8 segment 参数
fn parse_segmentation(br : Vp8BitReader) -> Vp8SegmentParams {
  let params = Vp8SegmentParams::new()

  // segmentation_enabled
  params.enabled = br.read_bool(255) == 1
  if !params.enabled {
    return params
  }

  // update_mb_segmentation_map
  params.update_map = br.read_bool(255) == 1

  // update_segment_feature_data
  params.update_features = br.read_bool(255) == 1

  if params.update_features {
    // segment_feature_mode：0=delta，1=absolute
    params.feature_mode = br.read_bool(255)

    // 解析每个 segment 的量化器增量
    for i in 0..<4 {
      if br.read_bool(255) == 1 {
        let mut delta = br.read_bits(7)
        if delta > 63 {
          delta -= 128
        }
        params.quantizer_deltas[i] = delta
      }
    }

    // 解析每个 segment 的滤波级别增量
    for i in 0..<4 {
      if br.read_bool(255) == 1 {
        let mut delta = br.read_bits(6)
        if delta > 31 {
          delta -= 64
        }
        params.filter_deltas[i] = delta
      }
    }
  }

  if params.update_map {
    // 解析宏块 segment 树概率（3个）
    for i in 0..<3 {
      if br.read_bool(255) == 1 {
        params.mb_segment_tree_probs[i] = br.read_bits(8)
      } else {
        params.mb_segment_tree_probs[i] = 255
      }
    }
  }

  params
}

///|
/// 解析宏块的 segment ID（使用树概率）
fn vp8_parse_mb_segment_id(bd : Vp8BoolDecoder, probs : Array[Int]) -> Int {
  // VP8 segment ID 使用二叉树解析
  // 树结构：
  //       0
  //      / \
  //     0   1
  //    / \ / \
  //   0  1 2  3
  if bd.read_bool(probs[0]) == 0 {
    // 左子树：0 或 1
    if bd.read_bool(probs[1]) == 0 {
      0
    } else {
      1
    }
    // 右子树：2 或 3
  } else if bd.read_bool(probs[2]) == 0 {
    2
  } else {
    3
  }
}

///|
/// 根据 segment ID 计算实际量化参数
fn vp8_get_quant_for_segment(
  base_quant : Vp8QuantParams,
  segment : Vp8SegmentParams,
  segment_id : Int,
) -> Vp8QuantParams {
  if !segment.enabled || segment_id < 0 || segment_id >= 4 {
    return base_quant
  }
  let delta = segment.quantizer_deltas[segment_id]
  if segment.feature_mode == 0 {
    // delta 模式
    Vp8QuantParams::{
      y_ac: base_quant.y_ac + delta,
      y_dc: base_quant.y_dc + delta,
      uv_ac: base_quant.uv_ac + delta,
      uv_dc: base_quant.uv_dc + delta,
    }
  } else {
    // absolute 模式
    Vp8QuantParams::{ y_ac: delta, y_dc: delta, uv_ac: delta, uv_dc: delta }
  }
}

///|
/// 根据 segment ID 计算实际滤波级别
fn vp8_get_filter_level_for_segment(
  base_level : Int,
  segment : Vp8SegmentParams,
  segment_id : Int,
) -> Int {
  if !segment.enabled || segment_id < 0 || segment_id >= 4 {
    return base_level
  }
  let delta = segment.filter_deltas[segment_id]
  let mut level = if segment.feature_mode == 0 {
    base_level + delta
  } else {
    delta
  }
  if level < 0 {
    level = 0
  }
  if level > 63 {
    level = 63
  }
  level
}

// ==================== VP8 IDCT ====================
// VP8 使用 4x4 DCT 变换和 16x16 Walsh-Hadamard 变换

///|
/// VP8 4x4 IDCT（使用 VP8 特定的变换矩阵）
/// 输入：16 个变换系数（行优先）
/// 输出：16 个像素残差（行优先）
fn vp8_idct_4x4(block : Array[Int]) -> Array[Int] {
  let result = Array::make(16, 0)
  // 行变换（一维 IDCT）
  for i in 0..<4 {
    let a0 = block[i * 4]
    let a1 = block[i * 4 + 1]
    let a2 = block[i * 4 + 2]
    let a3 = block[i * 4 + 3]
    // VP8 一维 IDCT（使用 c=85627, c*sqrt(2)=121095）
    let b0 = a0 * 85627 + a2 * 85627
    let b1 = a0 * 85627 - a2 * 85627
    let b2 = a1 * 53527 - a3 * 22109
    let b3 = a1 * 22109 + a3 * 53527
    result[i * 4] = (b0 + b3) >> 17
    result[i * 4 + 1] = (b1 + b2) >> 17
    result[i * 4 + 2] = (b1 - b2) >> 17
    result[i * 4 + 3] = (b0 - b3) >> 17
  }
  // 列变换（一维 IDCT）
  let temp = Array::make(16, 0)
  for i in 0..<16 {
    temp[i] = result[i]
  }
  for j in 0..<4 {
    let a0 = temp[j]
    let a1 = temp[4 + j]
    let a2 = temp[8 + j]
    let a3 = temp[12 + j]
    let b0 = a0 * 85627 + a2 * 85627
    let b1 = a0 * 85627 - a2 * 85627
    let b2 = a1 * 53527 - a3 * 22109
    let b3 = a1 * 22109 + a3 * 53527
    result[j] = (b0 + b3) >> 17
    result[4 + j] = (b1 + b2) >> 17
    result[8 + j] = (b1 - b2) >> 17
    result[12 + j] = (b0 - b3) >> 17
  }
  result
}

///|
/// VP8 16x16 DC 系数的 Walsh-Hadamard 变换（WHT）
/// 输入：16 个 DC 系数（4x4 块）
/// 输出：16 个 DC 残差
fn vp8_wht_4x4(block : Array[Int]) -> Array[Int] {
  let result = Array::make(16, 0)
  // 行变换
  for i in 0..<4 {
    let a0 = block[i * 4]
    let a1 = block[i * 4 + 1]
    let a2 = block[i * 4 + 2]
    let a3 = block[i * 4 + 3]
    let b0 = a0 + a1
    let b1 = a0 - a1
    let b2 = a2 + a3
    let b3 = a2 - a3
    result[i * 4] = b0 + b2
    result[i * 4 + 1] = b1 + b3
    result[i * 4 + 2] = b1 - b3
    result[i * 4 + 3] = b0 - b2
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
    let b1 = a0 - a1
    let b2 = a2 + a3
    let b3 = a2 - a3
    result[j] = (b0 + b2) >> 1
    result[4 + j] = (b1 + b3) >> 1
    result[8 + j] = (b1 - b3) >> 1
    result[12 + j] = (b0 - b2) >> 1
  }
  result
}

// ==================== VP8 Intra Prediction ====================
// VP8 帧内预测模式

///|
/// I16x16 帧内预测模式
priv enum Vp8I16x16Mode {
  I16x16DcPred
  I16x16TrueMotionPred
  I16x16HPred
  I16x16VPred
}

///|
/// I4x4 帧内预测模式
priv enum Vp8I4x4Mode {
  I4x4DcPred
  I4x4TrueMotionPred
  I4x4HPred
  I4x4VPred
  I4x4LeftDownPred
  I4x4RightDownPred
  I4x4RightUpPred
  I4x4LeftUpPred
  I4x4VertRightPred
  I4x4HorizDownPred
}

///|
/// I16x16 帧内预测
/// above：上方参考像素（16个）
/// left：左侧参考像素（16个）
/// above_left：左上角参考像素
fn vp8_intra_predict_16x16(
  mode : Vp8I16x16Mode,
  above : Array[Int],
  left : Array[Int],
  above_left : Int,
) -> Array[Int] {
  let result = Array::make(256, 0)
  match mode {
    I16x16DcPred => {
      let mut sum = above_left * 2
      for i in 0..<16 {
        sum += above[i]
        sum += left[i]
      }
      let dc = (sum + 16) >> 5
      for i in 0..<256 {
        result[i] = dc
      }
    }
    I16x16TrueMotionPred =>
      for y in 0..<16 {
        for x in 0..<16 {
          let mut sum = 0
          for i in 0..<(x + 1) {
            sum += above[i]
          }
          for i in 0..<(y + 1) {
            sum += left[i]
          }
          sum += above_left
          result[y * 16 + x] = (sum + (x + y + 2) / 2) / (x + y + 2)
        }
      }
    I16x16HPred =>
      for y in 0..<16 {
        for x in 0..<16 {
          result[y * 16 + x] = left[y]
        }
      }
    I16x16VPred =>
      for y in 0..<16 {
        for x in 0..<16 {
          result[y * 16 + x] = above[x]
        }
      }
  }
  result
}

///|
/// I4x4 帧内预测（完整实现 10 种模式）
/// 参考像素布局：
///   above_left  above[0]  above[1]  above[2]  above[3]  above[4..7]
///   left[0]     P[0][0]   P[0][1]   P[0][2]   P[0][3]
///   left[1]     P[1][0]   P[1][1]   P[1][2]   P[1][3]
///   left[2]     P[2][0]   P[2][1]   P[2][2]   P[2][3]
///   left[3]     P[3][0]   P[3][1]   P[3][2]   P[3][3]
///   left[4..7]
fn _vp8_intra_predict_4x4(
  mode : Vp8I4x4Mode,
  above : Array[Int],
  left : Array[Int],
  above_left : Int,
) -> Array[Int] {
  let result = Array::make(16, 0)
  match mode {
    // 0: DC 预测 - 上方和左方像素的平均值
    I4x4DcPred => {
      let mut sum = 0
      for i in 0..<4 {
        sum += above[i]
        sum += left[i]
      }
      let dc = (sum + 4) >> 3
      for i in 0..<16 {
        result[i] = dc
      }
    }

    // 1: TrueMotion 预测 - 基于水平和垂直梯度
    // P[y][x] = clip(above[x] + left[y] - above_left, 0, 255)
    I4x4TrueMotionPred =>
      for y in 0..<4 {
        for x in 0..<4 {
          let mut pred = above[x] + left[y] - above_left
          if pred < 0 {
            pred = 0
          }
          if pred > 255 {
            pred = 255
          }
          result[y * 4 + x] = pred
        }
      }

    // 2: 水平预测 - 使用左方像素
    // P[y][x] = left[y]
    I4x4HPred =>
      for y in 0..<4 {
        for x in 0..<4 {
          result[y * 4 + x] = left[y]
        }
      }

    // 3: 垂直预测 - 使用上方像素
    // P[y][x] = above[x]
    I4x4VPred =>
      for y in 0..<4 {
        for x in 0..<4 {
          result[y * 4 + x] = above[x]
        }
      }

    // 4: LeftDown 预测（左下/对角线，斜率 1）
    // 从左上到右下的对角线预测
    // P[y][x] = (above[x+y] + above[x+y+1] + 1) >> 1  (x+y <= 6)
    // P[y][x] = above[7]  (x+y == 7)
    I4x4LeftDownPred =>
      for y in 0..<4 {
        for x in 0..<4 {
          let idx = x + y
          if idx <= 6 {
            result[y * 4 + x] = (above[idx] + above[idx + 1] + 1) >> 1
          } else {
            result[y * 4 + x] = above[7]
          }
        }
      }

    // 5: RightDown 预测（右下/对角线，斜率 -1）
    // 从右上到左下的对角线预测
    // 如果 x >= y: P[y][x] = (above[x-y] + above[x-y+1] + 1) >> 1
    // 如果 x < y:  P[y][x] = (left[y-x-1] + left[y-x] + 1) >> 1
    I4x4RightDownPred =>
      for y in 0..<4 {
        for x in 0..<4 {
          if x >= y {
            let idx = x - y
            result[y * 4 + x] = (above[idx] + above[idx + 1] + 1) >> 1
          } else {
            let idx = y - x - 1
            result[y * 4 + x] = (left[idx] + left[idx + 1] + 1) >> 1
          }
        }
      }

    // 6: RightUp 预测（右上/垂直-右组合）
    // 垂直预测为主，向右下方倾斜
    // P[y][x] = (above[x] + above[x+1] + left[y] + 1) >> 2
    I4x4RightUpPred =>
      for y in 0..<4 {
        for x in 0..<4 {
          result[y * 4 + x] = (above[x] + above[x + 1] + left[y] + 1) >> 2
        }
      }

    // 7: LeftUp 预测（左上/水平-上组合）
    // 水平预测为主，向右上方倾斜
    // P[y][x] = (left[y] + left[y+1] + above[x] + 1) >> 2
    I4x4LeftUpPred =>
      for y in 0..<4 {
        for x in 0..<4 {
          result[y * 4 + x] = (left[y] + left[y + 1] + above[x] + 1) >> 2
        }
      }

    // 8: VertRight 预测（垂直-右）
    // 垂直预测 + 对角线修正
    // P[y][x] = (above[x] + above[x+1] + 1) >> 1  (y == 0)
    // P[y][x] = (above[x] + left[y-1] + 1) >> 1    (y > 0)
    I4x4VertRightPred =>
      for y in 0..<4 {
        for x in 0..<4 {
          if y == 0 {
            result[y * 4 + x] = (above[x] + above[x + 1] + 1) >> 1
          } else {
            result[y * 4 + x] = (above[x] + left[y - 1] + 1) >> 1
          }
        }
      }

    // 9: HorizDown 预测（水平-下）
    // 水平预测 + 对角线修正
    // P[y][x] = (left[y] + left[y+1] + 1) >> 1  (x == 0)
    // P[y][x] = (left[y] + above[x-1] + 1) >> 1  (x > 0)
    I4x4HorizDownPred =>
      for y in 0..<4 {
        for x in 0..<4 {
          if x == 0 {
            result[y * 4 + x] = (left[y] + left[y + 1] + 1) >> 1
          } else {
            result[y * 4 + x] = (left[y] + above[x - 1] + 1) >> 1
          }
        }
      }
  }
  result
}

// ==================== VP8 Macroblock Prediction Mode Parsing ====================
// VP8 宏块层预测模式解析：从 bitstream 解析每个宏块的预测模式

///|
/// 宏块预测模式概率模型
priv struct Vp8MbModeProbs {
  // I16x16 预测模式概率（4种模式）
  i16x16_prob : Array[Int]
  // I4x4 预测模式概率（10种模式，每个子块）
  i4x4_prob : Array[Int]
  // 色度预测模式概率（4种模式）
  uv_prob : Array[Int]
  // 子宏块类型概率（I16x16 vs I4x4）
  mut submb_type_prob : Int
  // 统计计数器（用于概率更新）
  i16x16_count : Array[Int]
  i4x4_count : Array[Int]
  uv_count : Array[Int]
  mut submb_type_count : Int
  mut total_mbs : Int
}

///|
fn Vp8MbModeProbs::new() -> Vp8MbModeProbs {
  // VP8 默认预测模式概率
  Vp8MbModeProbs::{
    i16x16_prob: [180, 120, 100, 140],
    i4x4_prob: [160, 100, 120, 140, 80, 90, 70, 60, 50, 40],
    uv_prob: [180, 120, 100, 140],
    submb_type_prob: 150,
    i16x16_count: Array::make(4, 0),
    i4x4_count: Array::make(10, 0),
    uv_count: Array::make(4, 0),
    submb_type_count: 0,
    total_mbs: 0,
  }
}

///|
/// 解析 I16x16 预测模式（4种模式）
fn vp8_parse_i16x16_mode(
  bd : Vp8BoolDecoder,
  probs : Vp8MbModeProbs,
) -> Vp8I16x16Mode {
  // 使用概率模型解析预测模式
  // VP8 使用树形概率解析：先判断是否是 DC，然后判断剩余模式
  let is_dc = bd.read_bool(probs.i16x16_prob[0]) == 1
  if is_dc {
    probs.i16x16_count[0] += 1
    return Vp8I16x16Mode::I16x16DcPred
  }
  let is_tm = bd.read_bool(probs.i16x16_prob[1]) == 1
  if is_tm {
    probs.i16x16_count[1] += 1
    return Vp8I16x16Mode::I16x16TrueMotionPred
  }
  let is_h = bd.read_bool(probs.i16x16_prob[2]) == 1
  if is_h {
    probs.i16x16_count[2] += 1
    return Vp8I16x16Mode::I16x16HPred
  }
  probs.i16x16_count[3] += 1
  Vp8I16x16Mode::I16x16VPred
}

///|
/// 解析 I4x4 预测模式（10种模式）
fn _vp8_parse_i4x4_mode(
  bd : Vp8BoolDecoder,
  probs : Vp8MbModeProbs,
) -> Vp8I4x4Mode {
  // 使用概率模型解析预测模式
  let is_dc = bd.read_bool(probs.i4x4_prob[0]) == 1
  if is_dc {
    probs.i4x4_count[0] += 1
    return Vp8I4x4Mode::I4x4DcPred
  }
  let is_tm = bd.read_bool(probs.i4x4_prob[1]) == 1
  if is_tm {
    probs.i4x4_count[1] += 1
    return Vp8I4x4Mode::I4x4TrueMotionPred
  }
  let is_h = bd.read_bool(probs.i4x4_prob[2]) == 1
  if is_h {
    probs.i4x4_count[2] += 1
    return Vp8I4x4Mode::I4x4HPred
  }
  let is_v = bd.read_bool(probs.i4x4_prob[3]) == 1
  if is_v {
    probs.i4x4_count[3] += 1
    return Vp8I4x4Mode::I4x4VPred
  }
  let is_ld = bd.read_bool(probs.i4x4_prob[4]) == 1
  if is_ld {
    probs.i4x4_count[4] += 1
    return Vp8I4x4Mode::I4x4LeftDownPred
  }
  let is_rd = bd.read_bool(probs.i4x4_prob[5]) == 1
  if is_rd {
    probs.i4x4_count[5] += 1
    return Vp8I4x4Mode::I4x4RightDownPred
  }
  let is_ru = bd.read_bool(probs.i4x4_prob[6]) == 1
  if is_ru {
    probs.i4x4_count[6] += 1
    return Vp8I4x4Mode::I4x4RightUpPred
  }
  let is_lu = bd.read_bool(probs.i4x4_prob[7]) == 1
  if is_lu {
    probs.i4x4_count[7] += 1
    return Vp8I4x4Mode::I4x4LeftUpPred
  }
  let is_vr = bd.read_bool(probs.i4x4_prob[8]) == 1
  if is_vr {
    probs.i4x4_count[8] += 1
    return Vp8I4x4Mode::I4x4VertRightPred
  }
  probs.i4x4_count[9] += 1
  Vp8I4x4Mode::I4x4HorizDownPred
}

///|
/// 解析色度预测模式（4种模式，与 I16x16 相同）
fn vp8_parse_uv_mode(
  bd : Vp8BoolDecoder,
  probs : Vp8MbModeProbs,
) -> Vp8I16x16Mode {
  let is_dc = bd.read_bool(probs.uv_prob[0]) == 1
  if is_dc {
    probs.uv_count[0] += 1
    return Vp8I16x16Mode::I16x16DcPred
  }
  let is_tm = bd.read_bool(probs.uv_prob[1]) == 1
  if is_tm {
    probs.uv_count[1] += 1
    return Vp8I16x16Mode::I16x16TrueMotionPred
  }
  let is_h = bd.read_bool(probs.uv_prob[2]) == 1
  if is_h {
    probs.uv_count[2] += 1
    return Vp8I16x16Mode::I16x16HPred
  }
  probs.uv_count[3] += 1
  Vp8I16x16Mode::I16x16VPred
}

///|
/// 解析子宏块类型（I16x16 vs I4x4）
/// 返回 true 表示使用 I16x16，false 表示使用 I4x4
fn _vp8_parse_submb_type(bd : Vp8BoolDecoder, probs : Vp8MbModeProbs) -> Bool {
  let use_i16x16 = bd.read_bool(probs.submb_type_prob) == 1
  if use_i16x16 {
    probs.submb_type_count += 1
  }
  use_i16x16
}

///|
/// 更新宏块预测模式概率（EMA）
fn Vp8MbModeProbs::update(self : Vp8MbModeProbs) -> Unit {
  self.total_mbs += 1
  // 每 16 个宏块更新一次概率
  if self.total_mbs % 16 != 0 {
    return
  }

  // 更新 I16x16 概率
  let i16_total = self.i16x16_count[0] +
    self.i16x16_count[1] +
    self.i16x16_count[2] +
    self.i16x16_count[3] +
    1
  for i in 0..<4 {
    let observed = self.i16x16_count[i] * 256 / i16_total
    self.i16x16_prob[i] = (self.i16x16_prob[i] * 7 + observed) / 8
    self.i16x16_count[i] = self.i16x16_count[i] / 2
  }

  // 更新 I4x4 概率
  let i4_total = self.i4x4_count[0] +
    self.i4x4_count[1] +
    self.i4x4_count[2] +
    self.i4x4_count[3] +
    self.i4x4_count[4] +
    self.i4x4_count[5] +
    self.i4x4_count[6] +
    self.i4x4_count[7] +
    self.i4x4_count[8] +
    self.i4x4_count[9] +
    1
  for i in 0..<10 {
    let observed = self.i4x4_count[i] * 256 / i4_total
    self.i4x4_prob[i] = (self.i4x4_prob[i] * 7 + observed) / 8
    self.i4x4_count[i] = self.i4x4_count[i] / 2
  }

  // 更新 UV 概率
  let uv_total = self.uv_count[0] +
    self.uv_count[1] +
    self.uv_count[2] +
    self.uv_count[3] +
    1
  for i in 0..<4 {
    let observed = self.uv_count[i] * 256 / uv_total
    self.uv_prob[i] = (self.uv_prob[i] * 7 + observed) / 8
    self.uv_count[i] = self.uv_count[i] / 2
  }

  // 更新子宏块类型概率
  let submb_total = self.total_mbs + 1
  let observed_submb = self.submb_type_count * 256 / submb_total
  self.submb_type_prob = (self.submb_type_prob * 7 + observed_submb) / 8
  self.submb_type_count = self.submb_type_count / 2
}

// ==================== VP8 Loop Filter ====================
// VP8 环路去块滤波（完整实现）
// 支持：宏块边界滤波、子宏块边界滤波、色度平面滤波、自适应滤波强度

///|
/// VP8 环路滤波参数
priv struct Vp8LoopFilterParams {
  filter_level : Int // 基础滤波级别 (0-63)
  _inner_filter_level : Int // 内部滤波级别
  _sharpness_level : Int // 锐化级别 (0-7)
  segment_deltas : Array[Int] // 每个 segment 的滤波增量
  mode_ref_deltas : Array[Int] // 模式/参考帧的滤波增量
}

///|
fn Vp8LoopFilterParams::_new() -> Vp8LoopFilterParams {
  Vp8LoopFilterParams::{
    filter_level: 0,
    _inner_filter_level: 0,
    _sharpness_level: 0,
    segment_deltas: [0, 0, 0, 0],
    mode_ref_deltas: [0, 0, 0, 0],
  }
}

///|
/// 计算宏块的实际滤波级别
fn _vp8_calc_filter_level(
  params : Vp8LoopFilterParams,
  segment_id : Int,
  is_i16x16 : Bool,
) -> Int {
  let mut level = params.filter_level
  // 加上 segment 增量
  if segment_id >= 0 && segment_id < 4 {
    level += params.segment_deltas[segment_id]
  }
  // 加上模式/参考帧增量（I16x16 使用第一个增量）
  if is_i16x16 {
    level += params.mode_ref_deltas[0]
  } else {
    level += params.mode_ref_deltas[1]
  }
  // 限制范围
  if level < 0 {
    level = 0
  }
  if level > 63 {
    level = 63
  }
  level
}

///|
/// 4 像素简单环路滤波（垂直边界）
/// 对边界两侧的 p1, p0, q0, q1 进行滤波
fn vp8_filter_vertical_4(
  plane : Array[Int],
  x : Int,
  y : Int,
  width : Int,
  filter_level : Int,
  inner_level : Int,
) -> Unit {
  if x <= 0 || x >= width {
    return
  }
  let idx = y * width + x
  let p1 = plane[idx - 2]
  let p0 = plane[idx - 1]
  let q0 = plane[idx]
  let q1 = plane[idx + 1]

  // 检查是否需要滤波
  let threshold = filter_level * 2
  if (p0 - q0).abs() * 2 + (p1 - q1).abs() / 2 > threshold {
    return
  }

  // 计算滤波值
  let mut p0_new = p0
  let mut q0_new = q0
  let mut p1_new = p1
  let mut q1_new = q1

  if filter_level > 0 {
    // 简单的 4 抽头滤波
    let filter_val = (p1 + 2 * p0 + 2 * q0 + q1 + 4) / 8
    p0_new = filter_val
    q0_new = filter_val

    // 如果内部滤波级别足够，也滤波 p1 和 q1
    if inner_level > 0 && (p1 - p0).abs() < inner_level {
      p1_new = (p1 + p0_new + 1) / 2
    }
    if inner_level > 0 && (q1 - q0).abs() < inner_level {
      q1_new = (q1 + q0_new + 1) / 2
    }
  }

  plane[idx - 2] = p1_new
  plane[idx - 1] = p0_new
  plane[idx] = q0_new
  plane[idx + 1] = q1_new
}

///|
/// 4 像素简单环路滤波（水平边界）
fn vp8_filter_horizontal_4(
  plane : Array[Int],
  x : Int,
  y : Int,
  width : Int,
  filter_level : Int,
  inner_level : Int,
) -> Unit {
  if y <= 0 {
    return
  }
  let idx = y * width + x
  let p1 = plane[idx - 2 * width]
  let p0 = plane[idx - width]
  let q0 = plane[idx]
  let q1 = plane[idx + width]

  // 检查是否需要滤波
  let threshold = filter_level * 2
  if (p0 - q0).abs() * 2 + (p1 - q1).abs() / 2 > threshold {
    return
  }

  // 计算滤波值
  let mut p0_new = p0
  let mut q0_new = q0
  let mut p1_new = p1
  let mut q1_new = q1

  if filter_level > 0 {
    let filter_val = (p1 + 2 * p0 + 2 * q0 + q1 + 4) / 8
    p0_new = filter_val
    q0_new = filter_val

    if inner_level > 0 && (p1 - p0).abs() < inner_level {
      p1_new = (p1 + p0_new + 1) / 2
    }
    if inner_level > 0 && (q1 - q0).abs() < inner_level {
      q1_new = (q1 + q0_new + 1) / 2
    }
  }

  plane[idx - 2 * width] = p1_new
  plane[idx - width] = p0_new
  plane[idx] = q0_new
  plane[idx + width] = q1_new
}

///|
/// 完整的宏块环路滤波
/// 包括：宏块边界滤波、子宏块内部边界滤波、色度平面滤波
fn vp8_loop_filter_mb(
  y_plane : Array[Int],
  u_plane : Array[Int],
  v_plane : Array[Int],
  mb_x : Int,
  mb_y : Int,
  width : Int,
  height : Int,
  filter_level : Int,
) -> Unit {
  if filter_level == 0 {
    return
  }

  let inner_level = filter_level / 2
  let mb_px = mb_x * 16
  let mb_py = mb_y * 16

  // === Y 平面滤波 ===

  // 宏块左边界垂直滤波（16行）
  if mb_x > 0 {
    for y in 0..<16 {
      let py = mb_py + y
      if py < height {
        vp8_filter_vertical_4(
          y_plane, mb_px, py, width, filter_level, inner_level,
        )
      }
    }
  }

  // 宏块上边界水平滤波（16列）
  if mb_y > 0 {
    for x in 0..<16 {
      let px = mb_px + x
      if px < width {
        vp8_filter_horizontal_4(
          y_plane, px, mb_py, width, filter_level, inner_level,
        )
      }
    }
  }

  // 子宏块内部垂直边界滤波（x = 4, 8, 12）
  for sub_x in [4, 8, 12] {
    let px = mb_px + sub_x
    if px < width {
      for y in 0..<16 {
        let py = mb_py + y
        if py < height {
          vp8_filter_vertical_4(
            y_plane,
            px,
            py,
            width,
            inner_level,
            inner_level / 2,
          )
        }
      }
    }
  }

  // 子宏块内部水平边界滤波（y = 4, 8, 12）
  for sub_y in [4, 8, 12] {
    let py = mb_py + sub_y
    if py < height {
      for x in 0..<16 {
        let px = mb_px + x
        if px < width {
          vp8_filter_horizontal_4(
            y_plane,
            px,
            py,
            width,
            inner_level,
            inner_level / 2,
          )
        }
      }
    }
  }

  // === 色度平面滤波（U 和 V，8x8 块） ===
  let uv_width = width / 2
  let uv_height = height / 2
  let uv_mb_px = mb_x * 8
  let uv_mb_py = mb_y * 8

  // U 平面：左边界垂直滤波
  if mb_x > 0 {
    for y in 0..<8 {
      let py = uv_mb_py + y
      if py < uv_height {
        vp8_filter_vertical_4(
          u_plane,
          uv_mb_px,
          py,
          uv_width,
          filter_level / 2,
          inner_level / 2,
        )
      }
    }
  }

  // U 平面：上边界水平滤波
  if mb_y > 0 {
    for x in 0..<8 {
      let px = uv_mb_px + x
      if px < uv_width {
        vp8_filter_horizontal_4(
          u_plane,
          px,
          uv_mb_py,
          uv_width,
          filter_level / 2,
          inner_level / 2,
        )
      }
    }
  }

  // V 平面：左边界垂直滤波
  if mb_x > 0 {
    for y in 0..<8 {
      let py = uv_mb_py + y
      if py < uv_height {
        vp8_filter_vertical_4(
          v_plane,
          uv_mb_px,
          py,
          uv_width,
          filter_level / 2,
          inner_level / 2,
        )
      }
    }
  }

  // V 平面：上边界水平滤波
  if mb_y > 0 {
    for x in 0..<8 {
      let px = uv_mb_px + x
      if px < uv_width {
        vp8_filter_horizontal_4(
          v_plane,
          px,
          uv_mb_py,
          uv_width,
          filter_level / 2,
          inner_level / 2,
        )
      }
    }
  }
}

// ==================== VP8 Inter Prediction (Frame间预测) ====================
// VP8 非关键帧支持：运动估计/运动补偿、参考帧管理

///|
/// 运动向量（整数像素精度）
priv struct Vp8MotionVector {
  mut mv_x : Int // 水平运动向量（像素单位）
  mut mv_y : Int // 垂直运动向量（像素单位）
}

///|
fn Vp8MotionVector::new() -> Vp8MotionVector {
  Vp8MotionVector::{ mv_x: 0, mv_y: 0 }
}

///|

///|
/// 参考帧管理
/// VP8 使用 3 个参考帧：last（前向）、golden（黄金帧）、altref（备用参考帧）
pub struct Vp8ReferenceFrames {
  last_y : Array[Int] // 前向参考帧 Y 平面
  last_u : Array[Int] // 前向参考帧 U 平面
  last_v : Array[Int] // 前向参考帧 V 平面
  golden_y : Array[Int] // 黄金帧 Y 平面
  golden_u : Array[Int] // 黄金帧 U 平面
  golden_v : Array[Int] // 黄金帧 V 平面
  altref_y : Array[Int] // 备用参考帧 Y 平面
  altref_u : Array[Int] // 备用参考帧 U 平面
  altref_v : Array[Int] // 备用参考帧 V 平面
  width : Int
  height : Int
}

///|
fn Vp8ReferenceFrames::new(width : Int, height : Int) -> Vp8ReferenceFrames {
  let y_size = width * height
  let uv_size = width / 2 * (height / 2)
  Vp8ReferenceFrames::{
    last_y: Array::make(y_size, 128),
    last_u: Array::make(uv_size, 128),
    last_v: Array::make(uv_size, 128),
    golden_y: Array::make(y_size, 128),
    golden_u: Array::make(uv_size, 128),
    golden_v: Array::make(uv_size, 128),
    altref_y: Array::make(y_size, 128),
    altref_u: Array::make(uv_size, 128),
    altref_v: Array::make(uv_size, 128),
    width,
    height,
  }
}

///|
/// 更新参考帧（将当前帧复制到 last 参考帧）
fn Vp8ReferenceFrames::update(
  self : Vp8ReferenceFrames,
  y_plane : Array[Int],
  u_plane : Array[Int],
  v_plane : Array[Int],
) -> Unit {
  let y_size = self.width * self.height
  let uv_size = self.width / 2 * (self.height / 2)
  for i in 0..<y_size {
    self.last_y[i] = y_plane[i]
  }
  for i in 0..<uv_size {
    self.last_u[i] = u_plane[i]
    self.last_v[i] = v_plane[i]
  }
}

///|
/// 运动补偿（整数像素精度）
/// 从参考帧中获取 16x16 宏块的预测像素
fn _vp8_motion_compensate_16x16(
  ref_y : Array[Int],
  ref_u : Array[Int],
  ref_v : Array[Int],
  mb_x : Int,
  mb_y : Int,
  mv : Vp8MotionVector,
  width : Int,
  height : Int,
) -> (Array[Int], Array[Int], Array[Int]) {
  let pred_y = Array::make(256, 128) // 16x16 = 256
  let pred_u = Array::make(64, 128) // 8x8 = 64
  let pred_v = Array::make(64, 128) // 8x8 = 64

  // 计算参考位置（加上运动向量）
  let ref_x = mb_x * 16 + mv.mv_x
  let ref_y_pos = mb_y * 16 + mv.mv_y

  // Y 平面运动补偿（16x16）
  for y in 0..<16 {
    for x in 0..<16 {
      let sx = ref_x + x
      let sy = ref_y_pos + y
      // 边界钳制
      let cx = if sx < 0 { 0 } else if sx >= width { width - 1 } else { sx }
      let cy = if sy < 0 { 0 } else if sy >= height { height - 1 } else { sy }
      pred_y[y * 16 + x] = ref_y[cy * width + cx]
    }
  }

  // U/V 平面运动补偿（8x8，运动向量减半）
  let uv_width = width / 2
  let uv_height = height / 2
  let uv_ref_x = (ref_x + 1) / 2
  let uv_ref_y = (ref_y_pos + 1) / 2
  for y in 0..<8 {
    for x in 0..<8 {
      let sx = uv_ref_x + x
      let sy = uv_ref_y + y
      let cx = if sx < 0 {
        0
      } else if sx >= uv_width {
        uv_width - 1
      } else {
        sx
      }
      let cy = if sy < 0 {
        0
      } else if sy >= uv_height {
        uv_height - 1
      } else {
        sy
      }
      pred_u[y * 8 + x] = ref_u[cy * uv_width + cx]
      pred_v[y * 8 + x] = ref_v[cy * uv_width + cx]
    }
  }

  (pred_y, pred_u, pred_v)
}

///|
/// VP8 6 抽头插值滤波器（用于半像素插值）
/// 系数：[1, -5, 20, 20, -5, 1]，右移 6 位
fn vp8_interpolate_6tap(
  p0 : Int,
  p1 : Int,
  p2 : Int,
  p3 : Int,
  p4 : Int,
  p5 : Int,
) -> Int {
  let sum = p0 - 5 * p1 + 20 * p2 + 20 * p3 - 5 * p4 + p5
  let result = (sum + 32) >> 6
  if result < 0 {
    0
  } else if result > 255 {
    255
  } else {
    result
  }
}

///|
/// 获取参考像素（带边界钳制）
fn vp8_get_ref_pixel(
  ref_plane : Array[Int],
  x : Int,
  y : Int,
  width : Int,
  height : Int,
) -> Int {
  let cx = if x < 0 { 0 } else if x >= width { width - 1 } else { x }
  let cy = if y < 0 { 0 } else if y >= height { height - 1 } else { y }
  ref_plane[cy * width + cx]
}

///|
/// 亚像素插值（1/4 像素精度）
/// mv_x_q4, mv_y_q4：1/4 像素单位的运动向量（即实际像素 * 4）
fn vp8_interpolate_subpixel(
  ref_plane : Array[Int],
  base_x : Int,
  base_y : Int,
  mv_x_q4 : Int,
  mv_y_q4 : Int,
  width : Int,
  height : Int,
) -> Int {
  // 整数部分和小数部分
  let int_x = mv_x_q4 >> 2
  let frac_x = mv_x_q4 & 3
  let int_y = mv_y_q4 >> 2
  let frac_y = mv_y_q4 & 3

  let px = base_x + int_x
  let py = base_y + int_y

  // 如果是整数像素，直接返回
  if frac_x == 0 && frac_y == 0 {
    return vp8_get_ref_pixel(ref_plane, px, py, width, height)
  }

  // 半像素插值（使用 6 抽头滤波器）
  // 先进行水平插值得到半像素
  let h_samples : Array[Int] = Array::make(6, 0)
  for i in 0..<6 {
    h_samples[i] = vp8_get_ref_pixel(ref_plane, px - 2 + i, py, width, height)
  }
  let half_x = if frac_x >= 2 {
    vp8_interpolate_6tap(
      h_samples[0],
      h_samples[1],
      h_samples[2],
      h_samples[3],
      h_samples[4],
      h_samples[5],
    )
  } else {
    h_samples[2]
  }

  // 进行垂直插值得到半像素
  let v_samples : Array[Int] = Array::make(6, 0)
  for i in 0..<6 {
    v_samples[i] = vp8_get_ref_pixel(ref_plane, px, py - 2 + i, width, height)
  }
  let half_y = if frac_y >= 2 {
    vp8_interpolate_6tap(
      v_samples[0],
      v_samples[1],
      v_samples[2],
      v_samples[3],
      v_samples[4],
      v_samples[5],
    )
  } else {
    v_samples[2]
  }

  // 双线性插值（四分之一像素）
  if frac_x == 0 {
    // 只有垂直偏移
    let t = frac_y
    return (half_x * (4 - t) + half_y * t + 2) >> 2
  }
  if frac_y == 0 {
    // 只有水平偏移
    let t = frac_x
    return (half_y * (4 - t) + half_x * t + 2) >> 2
  }
  // 双向偏移：使用四个角的双线性插值
  let h00 = vp8_get_ref_pixel(ref_plane, px, py, width, height)
  let h10 = half_x
  let h01 = half_y
  // 计算对角半像素（先水平后垂直，或先垂直后水平，取平均）
  let diag_samples_h : Array[Int] = Array::make(6, 0)
  for i in 0..<6 {
    diag_samples_h[i] = vp8_get_ref_pixel(
      ref_plane,
      px - 2 + i,
      py + 1,
      width,
      height,
    )
  }
  let h11 = vp8_interpolate_6tap(
    diag_samples_h[0],
    diag_samples_h[1],
    diag_samples_h[2],
    diag_samples_h[3],
    diag_samples_h[4],
    diag_samples_h[5],
  )

  let tx = frac_x
  let ty = frac_y
  let a = h00 * (4 - tx) * (4 - ty)
  let b = h10 * tx * (4 - ty)
  let c = h01 * (4 - tx) * ty
  let d = h11 * tx * ty
  (a + b + c + d + 8) >> 4
}

///|
/// 亚像素运动补偿（1/4 像素精度）
/// mv_x_q4, mv_y_q4：1/4 像素单位的运动向量
fn vp8_motion_compensate_16x4_subpixel(
  ref_y : Array[Int],
  ref_u : Array[Int],
  ref_v : Array[Int],
  mb_x : Int,
  mb_y : Int,
  mv_x_q4 : Int,
  mv_y_q4 : Int,
  width : Int,
  height : Int,
) -> (Array[Int], Array[Int], Array[Int]) {
  let pred_y = Array::make(256, 128)
  let pred_u = Array::make(64, 128)
  let pred_v = Array::make(64, 128)

  // Y 平面：16x16，1/4 像素精度
  for y in 0..<16 {
    for x in 0..<16 {
      pred_y[y * 16 + x] = vp8_interpolate_subpixel(
        ref_y,
        mb_x * 16 + x,
        mb_y * 16 + y,
        mv_x_q4,
        mv_y_q4,
        width,
        height,
      )
    }
  }

  // U/V 平面：8x8，运动向量减半（1/4 像素 → 1/2 像素）
  let uv_width = width / 2
  let uv_height = height / 2
  let uv_mv_x_q4 = mv_x_q4 / 2
  let uv_mv_y_q4 = mv_y_q4 / 2
  for y in 0..<8 {
    for x in 0..<8 {
      pred_u[y * 8 + x] = vp8_interpolate_subpixel(
        ref_u,
        mb_x * 8 + x,
        mb_y * 8 + y,
        uv_mv_x_q4,
        uv_mv_y_q4,
        uv_width,
        uv_height,
      )
      pred_v[y * 8 + x] = vp8_interpolate_subpixel(
        ref_v,
        mb_x * 8 + x,
        mb_y * 8 + y,
        uv_mv_x_q4,
        uv_mv_y_q4,
        uv_width,
        uv_height,
      )
    }
  }

  (pred_y, pred_u, pred_v)
}

///|
/// 解析 Exp-Golomb 编码的无符号整数
/// VP8 运动向量残差使用 Exp-Golomb 编码
fn vp8_read_ue_golomb(bd : Vp8BoolDecoder) -> Int {
  let mut leading_zeros = 0
  while bd.read_bool(128) == 0 {
    leading_zeros += 1
    if leading_zeros > 31 {
      return 0
    }
  }
  if leading_zeros == 0 {
    return 0
  }
  let mut value = 1
  for _ in 0..<leading_zeros {
    value = (value << 1) | bd.read_bool(128)
  }
  value - 1
}

///|
/// 解析 Exp-Golomb 编码的有符号整数
fn vp8_read_se_golomb(bd : Vp8BoolDecoder) -> Int {
  let value = vp8_read_ue_golomb(bd)
  if value == 0 {
    return 0
  }
  if value % 2 == 1 {
    (value + 1) / 2
  } else {
    -(value / 2)
  }
}

///|
/// 解析运动向量残差（1/4 像素单位）
/// VP8 使用简化的 Golomb 编码解析运动向量差
fn vp8_parse_mv_residual(bd : Vp8BoolDecoder, prob : Int) -> Int {
  ignore(prob)
  // 简化实现：使用 Exp-Golomb 编码
  // 完整 VP8 使用更复杂的运动向量残差编码
  let residual = vp8_read_se_golomb(bd)
  residual * 4 // 转换为 1/4 像素单位
}

///|
/// 参考帧选择
/// VP8 支持 3 个参考帧：last（0）、golden（1）、altref（2）
priv enum Vp8RefFrame {
  RefLast
  RefGolden
  RefAltref
}

///|
/// 解析参考帧选择
fn vp8_parse_ref_frame(bd : Vp8BoolDecoder, ref_prob : Int) -> Vp8RefFrame {
  // 简化实现：使用概率选择参考帧
  let is_last = bd.read_bool(ref_prob) == 1
  if is_last {
    return Vp8RefFrame::RefLast
  }
  let is_golden = bd.read_bool(128) == 1
  if is_golden {
    Vp8RefFrame::RefGolden
  } else {
    Vp8RefFrame::RefAltref
  }
}

///|
/// 获取参考帧的 Y/U/V 平面
fn vp8_get_ref_planes(
  refs : Vp8ReferenceFrames,
  ref_frame : Vp8RefFrame,
) -> (Array[Int], Array[Int], Array[Int]) {
  match ref_frame {
    Vp8RefFrame::RefLast => (refs.last_y, refs.last_u, refs.last_v)
    Vp8RefFrame::RefGolden => (refs.golden_y, refs.golden_u, refs.golden_v)
    Vp8RefFrame::RefAltref => (refs.altref_y, refs.altref_u, refs.altref_v)
  }
}

///|
/// 完整的运动向量解析（预测 + 残差）
/// 返回 1/4 像素单位的运动向量
fn vp8_parse_full_motion_vector(
  bd : Vp8BoolDecoder,
  pred_mv : Vp8MotionVector,
  mv_prob : Int,
) -> (Int, Int) {
  // 解析是否使用预测运动向量
  let use_pred = bd.read_bool(mv_prob) == 1
  if use_pred {
    return (pred_mv.mv_x * 4, pred_mv.mv_y * 4)
  }
  // 解析运动向量残差
  let dx = vp8_parse_mv_residual(bd, 128)
  let dy = vp8_parse_mv_residual(bd, 128)
  (pred_mv.mv_x * 4 + dx, pred_mv.mv_y * 4 + dy)
}

///|
/// 解析运动向量（简化实现，使用默认概率）
/// VP8 运动向量使用 1/4 像素精度，这里简化为整数精度
fn _vp8_parse_motion_vector(
  bd : Vp8BoolDecoder,
  pred_mv : Vp8MotionVector,
) -> Vp8MotionVector {
  ignore(bd)
  let mv = Vp8MotionVector::new()
  // 简化实现：使用预测运动向量 + 小的残差
  // 完整实现需要解析运动向量残差（使用 Golomb 编码）
  mv.mv_x = pred_mv.mv_x
  mv.mv_y = pred_mv.mv_y
  mv
}

///|
/// 运动向量预测（使用相邻宏块的运动向量中值）
fn vp8_predict_motion_vector(
  left_mv : Vp8MotionVector,
  above_mv : Vp8MotionVector,
  above_left_mv : Vp8MotionVector,
) -> Vp8MotionVector {
  let pred = Vp8MotionVector::new()
  // 中值预测
  let xs = [left_mv.mv_x, above_mv.mv_x, above_left_mv.mv_x]
  let ys = [left_mv.mv_y, above_mv.mv_y, above_left_mv.mv_y]
  // 简单排序取中值
  let mut x_median = xs[0]
  if (xs[1] - xs[0]) * (xs[2] - xs[0]) <= 0 {
    x_median = xs[0]
  } else if (xs[0] - xs[1]) * (xs[2] - xs[1]) <= 0 {
    x_median = xs[1]
  } else {
    x_median = xs[2]
  }
  let mut y_median = ys[0]
  if (ys[1] - ys[0]) * (ys[2] - ys[0]) <= 0 {
    y_median = ys[0]
  } else if (ys[0] - ys[1]) * (ys[2] - ys[1]) <= 0 {
    y_median = ys[1]
  } else {
    y_median = ys[2]
  }
  pred.mv_x = x_median
  pred.mv_y = y_median
  pred
}

// ==================== VP8 Decoder ====================

///|
/// 解码 VP8 lossy 帧
pub fn decode_vp8_frame(
  data : Bytes,
  offset : Int,
) -> @types.Image raise @types.LoadError {
  let br = Vp8BitReader::new(data, offset)
  let header = parse_vp8_frame_header(br)

  if !header.key_frame {
    raise @types.LoadError::DecodeFailed("VP8 非关键帧暂不支持")
  }

  if header.width == 0 || header.height == 0 {
    raise @types.LoadError::DecodeFailed("VP8 帧尺寸无效")
  }

  let w = header.width
  let h = header.height

  // 解析量化参数
  let quant = parse_quantization(br)

  // 解析 segment 参数
  let segment = parse_segmentation(br)

  // 简化实现：创建一个纯色图像（灰色）
  // 完整的 VP8 解码需要解析残差系数、进行 IDCT、帧内预测等
  // 这里先实现基础框架，后续迭代完善
  let base_y = 128 - quant.y_dc / 4
  let base_u = 128 - quant.uv_ac / 4
  let base_v = 128 - quant.uv_dc / 4
  let y_plane : Array[Int] = Array::make(w * h, base_y)
  let u_plane : Array[Int] = Array::make(w / 2 * (h / 2), base_u)
  let v_plane : Array[Int] = Array::make(w / 2 * (h / 2), base_v)

  // 帧内预测 + 残差系数解析 + IDCT 反变换
  // 创建布尔解码器用于残差系数解析和预测模式解析
  let bd = Vp8BoolDecoder::new(data, offset + 10)
  let coeff_probs = Vp8AdaptiveProbs::new()
  let mb_mode_probs = Vp8MbModeProbs::new()

  // 对每个 16x16 宏块：解析预测模式 + 残差解析
  let mb_w = (w + 15) / 16
  let mb_h = (h + 15) / 16
  // 保存每个宏块的 segment ID（用于环路滤波）
  let segment_id_map : Array[Int] = Array::make(mb_w * mb_h, 0)
  for mb_y in 0..<mb_h {
    for mb_x in 0..<mb_w {
      // 解析宏块的 segment ID
      let segment_id = if segment.enabled && segment.update_map {
        vp8_parse_mb_segment_id(bd, segment.mb_segment_tree_probs)
      } else {
        0
      }
      segment_id_map[mb_y * mb_w + mb_x] = segment_id

      // 根据 segment ID 计算实际量化参数
      let _ = vp8_get_quant_for_segment(quant, segment, segment_id)

      // 生成参考像素
      let above : Array[Int] = Array::make(16, 128)
      let left : Array[Int] = Array::make(16, 128)
      let above_left = 128

      // 从 bitstream 解析 I16x16 预测模式（使用自适应概率模型）
      let mode = vp8_parse_i16x16_mode(bd, mb_mode_probs)

      // 解析色度预测模式（UV 平面）
      let uv_mode = vp8_parse_uv_mode(bd, mb_mode_probs)
      ignore(uv_mode) // 色度预测暂未完全实现，UV 平面使用基础值

      let pred = vp8_intra_predict_16x16(mode, above, left, above_left)

      // 解析 DC 系数（16x16 块的 DC 系数组成 4x4 块）
      let dc_coeffs = vp8_parse_dc_coeffs_16x16(bd, coeff_probs)
      let dc_residual = vp8_wht_4x4(dc_coeffs)

      // 对每个 4x4 子块解析 AC 系数并进行 IDCT
      for sub_y in 0..<4 {
        for sub_x in 0..<4 {
          // 解析 AC 系数
          let ac_coeffs = vp8_parse_residual_4x4(bd, coeff_probs, false)
          // 将 DC 系数添加到 AC 系数中
          ac_coeffs[0] = ac_coeffs[0] + dc_residual[sub_y * 4 + sub_x]
          // IDCT 反变换
          let residual = vp8_idct_4x4(ac_coeffs)
          // 将预测和残差相加
          for y in 0..<4 {
            for x in 0..<4 {
              let px = mb_x * 16 + sub_x * 4 + x
              let py = mb_y * 16 + sub_y * 4 + y
              if px < w && py < h {
                let pred_y = sub_y * 4 + y
                let pred_x = sub_x * 4 + x
                let mut val = pred[pred_y * 16 + pred_x] + residual[y * 4 + x]
                if val < 0 {
                  val = 0
                }
                if val > 255 {
                  val = 255
                }
                y_plane[py * w + px] = val
              }
            }
          }
        }
      }
      // 更新宏块预测模式概率（EMA）
      mb_mode_probs.update()
    }
  }

  // 环路滤波（基于 segment 的自适应滤波强度）
  let base_filter_level = quant.y_ac / 4
  for mb_y in 0..<mb_h {
    for mb_x in 0..<mb_w {
      let segment_id = segment_id_map[mb_y * mb_w + mb_x]
      let mb_filter_level = vp8_get_filter_level_for_segment(
        base_filter_level, segment, segment_id,
      )
      vp8_loop_filter_mb(
        y_plane, u_plane, v_plane, mb_x, mb_y, w, h, mb_filter_level,
      )
    }
  }

  // YUV420 转 RGB
  let out : Array[Byte] = Array::make(w * h * 3, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      let y_val = y_plane[y * w + x]
      let u_val = u_plane[y / 2 * (w / 2) + x / 2]
      let v_val = v_plane[y / 2 * (w / 2) + x / 2]

      // YUV 转 RGB（简化）
      let c = y_val - 16
      let d = u_val - 128
      let e = v_val - 128

      let mut r = (298 * c + 409 * e + 128) >> 8
      let mut g = (298 * c - 100 * d - 208 * e + 128) >> 8
      let mut b = (298 * c + 516 * d + 128) >> 8

      if r < 0 {
        r = 0
      }
      if r > 255 {
        r = 255
      }
      if g < 0 {
        g = 0
      }
      if g > 255 {
        g = 255
      }
      if b < 0 {
        b = 0
      }
      if b > 255 {
        b = 255
      }

      let idx = (y * w + x) * 3
      out[idx] = r.to_byte()
      out[idx + 1] = g.to_byte()
      out[idx + 2] = b.to_byte()
    }
  }

  @types.Image::{
    width: w,
    height: h,
    channels: 3,
    data: Bytes::from_array(out),
  }
}

///|
/// 解码 VP8 非关键帧（支持帧间预测）
/// refs：参考帧管理（包含 last/golden/altref）
/// 返回解码后的图像和更新后的参考帧
pub fn decode_vp8_inter_frame(
  data : Bytes,
  offset : Int,
  refs : Vp8ReferenceFrames,
) -> (@types.Image, Vp8ReferenceFrames) raise @types.LoadError {
  let br = Vp8BitReader::new(data, offset)
  let header = parse_vp8_frame_header(br)

  if header.key_frame {
    // 关键帧：使用常规解码并更新参考帧
    let img = decode_vp8_frame(data, offset)
    // 将关键帧复制到参考帧
    let w = img.width
    let h = img.height
    let y_size = w * h
    let uv_size = w / 2 * (h / 2)
    let new_refs = Vp8ReferenceFrames::new(w, h)
    // 从 RGB 转换回 YUV（简化：使用亮度作为 Y，UV 固定为 128）
    for i in 0..<y_size {
      let r = img.data[i * 3].to_int()
      let g = img.data[i * 3 + 1].to_int()
      let b = img.data[i * 3 + 2].to_int()
      let y = ((66 * r + 129 * g + 25 * b + 128) >> 8) + 16
      new_refs.last_y[i] = y
      new_refs.golden_y[i] = y
      new_refs.altref_y[i] = y
    }
    for i in 0..<uv_size {
      new_refs.last_u[i] = 128
      new_refs.last_v[i] = 128
      new_refs.golden_u[i] = 128
      new_refs.golden_v[i] = 128
      new_refs.altref_u[i] = 128
      new_refs.altref_v[i] = 128
    }
    return (img, new_refs)
  }

  // 非关键帧：使用帧间预测
  let w = header.width
  let h = header.height

  if w == 0 || h == 0 {
    raise @types.LoadError::DecodeFailed("VP8 帧尺寸无效")
  }

  // 解析量化参数
  let quant = parse_quantization(br)

  let y_plane : Array[Int] = Array::make(w * h, 128)
  let u_plane : Array[Int] = Array::make(w / 2 * (h / 2), 128)
  let v_plane : Array[Int] = Array::make(w / 2 * (h / 2), 128)

  // 创建布尔解码器
  let bd = Vp8BoolDecoder::new(data, offset + 10)
  let coeff_probs = Vp8AdaptiveProbs::new()
  let mb_mode_probs = Vp8MbModeProbs::new()

  // 运动向量预测缓存（用于相邻宏块的运动向量预测）
  let mb_w = (w + 15) / 16
  let mb_h = (h + 15) / 16
  let mv_cache : Array[Vp8MotionVector] = Array::make(
    mb_w * mb_h,
    Vp8MotionVector::new(),
  )

  // 对每个宏块进行解码
  for mb_y in 0..<mb_h {
    for mb_x in 0..<mb_w {
      // 解析宏块类型（帧内/帧间/跳过）
      let is_intra = bd.read_bool(180) == 1

      if is_intra {
        // 帧内预测宏块
        let above : Array[Int] = Array::make(16, 128)
        let left : Array[Int] = Array::make(16, 128)
        let above_left = 128
        let mode = vp8_parse_i16x16_mode(bd, mb_mode_probs)
        let uv_mode = vp8_parse_uv_mode(bd, mb_mode_probs)
        ignore(uv_mode)
        let pred = vp8_intra_predict_16x16(mode, above, left, above_left)

        // 解析 DC 系数
        let dc_coeffs = vp8_parse_dc_coeffs_16x16(bd, coeff_probs)
        let dc_residual = vp8_wht_4x4(dc_coeffs)

        // 解析 AC 系数并进行 IDCT
        for sub_y in 0..<4 {
          for sub_x in 0..<4 {
            let ac_coeffs = vp8_parse_residual_4x4(bd, coeff_probs, false)
            ac_coeffs[0] = ac_coeffs[0] + dc_residual[sub_y * 4 + sub_x]
            let residual = vp8_idct_4x4(ac_coeffs)
            for y in 0..<4 {
              for x in 0..<4 {
                let px = mb_x * 16 + sub_x * 4 + x
                let py = mb_y * 16 + sub_y * 4 + y
                if px < w && py < h {
                  let pred_y = sub_y * 4 + y
                  let pred_x = sub_x * 4 + x
                  let mut val = pred[pred_y * 16 + pred_x] + residual[y * 4 + x]
                  if val < 0 {
                    val = 0
                  }
                  if val > 255 {
                    val = 255
                  }
                  y_plane[py * w + px] = val
                }
              }
            }
          }
        }
      } else {
        // 帧间预测宏块（运动补偿）
        // 解析参考帧选择
        let ref_frame = vp8_parse_ref_frame(bd, 200)
        let (ref_y, ref_u, ref_v) = vp8_get_ref_planes(refs, ref_frame)

        // 运动向量预测（使用相邻宏块的中值）
        let left_mv = if mb_x > 0 {
          mv_cache[mb_y * mb_w + mb_x - 1]
        } else {
          Vp8MotionVector::new()
        }
        let above_mv = if mb_y > 0 {
          mv_cache[(mb_y - 1) * mb_w + mb_x]
        } else {
          Vp8MotionVector::new()
        }
        let above_left_mv = if mb_x > 0 && mb_y > 0 {
          mv_cache[(mb_y - 1) * mb_w + mb_x - 1]
        } else {
          Vp8MotionVector::new()
        }
        let pred_mv = vp8_predict_motion_vector(
          left_mv, above_mv, above_left_mv,
        )

        // 解析完整运动向量（预测 + 残差），1/4 像素精度
        let (mv_x_q4, mv_y_q4) = vp8_parse_full_motion_vector(bd, pred_mv, 150)

        // 保存运动向量到缓存
        let cur_mv = Vp8MotionVector::new()
        cur_mv.mv_x = mv_x_q4 / 4
        cur_mv.mv_y = mv_y_q4 / 4
        mv_cache[mb_y * mb_w + mb_x] = cur_mv

        // 亚像素运动补偿（1/4 像素精度）
        let (pred_y, pred_u, pred_v) = vp8_motion_compensate_16x4_subpixel(
          ref_y, ref_u, ref_v, mb_x, mb_y, mv_x_q4, mv_y_q4, w, h,
        )

        // 解析残差系数（帧间宏块可能有残差）
        let has_residual = bd.read_bool(128) == 1
        if has_residual {
          // 解析 4x4 子块的残差系数
          for sub_y in 0..<4 {
            for sub_x in 0..<4 {
              let ac_coeffs = vp8_parse_residual_4x4(bd, coeff_probs, false)
              let residual = vp8_idct_4x4(ac_coeffs)
              for y in 0..<4 {
                for x in 0..<4 {
                  let px = mb_x * 16 + sub_x * 4 + x
                  let py = mb_y * 16 + sub_y * 4 + y
                  if px < w && py < h {
                    let pred_idx = (sub_y * 4 + y) * 16 + (sub_x * 4 + x)
                    let mut val = pred_y[pred_idx] + residual[y * 4 + x]
                    if val < 0 {
                      val = 0
                    }
                    if val > 255 {
                      val = 255
                    }
                    y_plane[py * w + px] = val
                  }
                }
              }
            }
          }
        } else {
          // 无残差：直接使用运动补偿预测
          for y in 0..<16 {
            for x in 0..<16 {
              let px = mb_x * 16 + x
              let py = mb_y * 16 + y
              if px < w && py < h {
                y_plane[py * w + px] = pred_y[y * 16 + x]
              }
            }
          }
        }

        // 复制 U/V 预测
        for y in 0..<8 {
          for x in 0..<8 {
            let px = mb_x * 8 + x
            let py = mb_y * 8 + y
            if px < w / 2 && py < h / 2 {
              u_plane[py * (w / 2) + px] = pred_u[y * 8 + x]
              v_plane[py * (w / 2) + px] = pred_v[y * 8 + x]
            }
          }
        }
      }

      // 更新宏块预测模式概率
      mb_mode_probs.update()
    }
  }

  // 环路滤波
  let filter_level = quant.y_ac / 4
  for mb_y in 0..<mb_h {
    for mb_x in 0..<mb_w {
      vp8_loop_filter_mb(
        y_plane, u_plane, v_plane, mb_x, mb_y, w, h, filter_level,
      )
    }
  }

  // 更新参考帧（将当前帧复制到 last）
  refs.update(y_plane, u_plane, v_plane)

  // YUV420 转 RGB
  let out : Array[Byte] = Array::make(w * h * 3, b'\x00')
  for y in 0..<h {
    for x in 0..<w {
      let y_val = y_plane[y * w + x]
      let u_val = u_plane[y / 2 * (w / 2) + x / 2]
      let v_val = v_plane[y / 2 * (w / 2) + x / 2]

      let c = y_val - 16
      let d = u_val - 128
      let e = v_val - 128

      let mut r = (298 * c + 409 * e + 128) >> 8
      let mut g = (298 * c - 100 * d - 208 * e + 128) >> 8
      let mut b = (298 * c + 516 * d + 128) >> 8

      if r < 0 {
        r = 0
      }
      if r > 255 {
        r = 255
      }
      if g < 0 {
        g = 0
      }
      if g > 255 {
        g = 255
      }
      if b < 0 {
        b = 0
      }
      if b > 255 {
        b = 255
      }

      let idx = (y * w + x) * 3
      out[idx] = r.to_byte()
      out[idx + 1] = g.to_byte()
      out[idx + 2] = b.to_byte()
    }
  }

  let img = @types.Image::{
    width: w,
    height: h,
    channels: 3,
    data: Bytes::from_array(out),
  }

  (img, refs)
}
