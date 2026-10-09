// 目标检测基础（v12.4.0）
// 检测框 + IoU + NMS 非极大值抑制 + 检测框绘制

///|
/// 检测框
pub(all) struct BoundingBox {
  x : Int // 左上角 x
  y : Int // 左上角 y
  width : Int // 宽度
  height : Int // 高度
  score : Double // 置信度
  class_id : Int // 类别 ID
}

///|
/// 创建检测框
pub fn bbox_new(
  x : Int,
  y : Int,
  width : Int,
  height : Int,
  score? : Double = 0.0,
  class_id? : Int = 0,
) -> BoundingBox raise @types.LoadError {
  // 输入验证
  if width <= 0 {
    raise @types.LoadError::DecodeFailed("bbox_new: width必须大于0")
  }
  if height <= 0 {
    raise @types.LoadError::DecodeFailed("bbox_new: height必须大于0")
  }
  if score < 0.0 || score > 1.0 {
    raise @types.LoadError::DecodeFailed("bbox_new: score必须在0-1之间")
  }
  if class_id < 0 {
    raise @types.LoadError::DecodeFailed(
      "bbox_new: class_id必须大于等于0",
    )
  }

  BoundingBox::{ x, y, width, height, score, class_id }
}

///|
/// 计算两个检测框的 IoU（交并比）
pub fn bbox_iou(
  a : BoundingBox,
  b : BoundingBox,
) -> Double raise @types.LoadError {
  // 输入验证
  if a.width <= 0 || a.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "bbox_iou: 检测框a的尺寸必须大于0",
    )
  }
  if b.width <= 0 || b.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "bbox_iou: 检测框b的尺寸必须大于0",
    )
  }

  let x1 = a.x.max(b.x)
  let y1 = a.y.max(b.y)
  let x2 = (a.x + a.width).min(b.x + b.width)
  let y2 = (a.y + a.height).min(b.y + b.height)
  let intersection_w = (x2 - x1).max(0)
  let intersection_h = (y2 - y1).max(0)
  let intersection = intersection_w.to_double() * intersection_h.to_double()
  let area_a = a.width.to_double() * a.height.to_double()
  let area_b = b.width.to_double() * b.height.to_double()
  let union = area_a + area_b - intersection
  if union > 0.0 {
    intersection / union
  } else {
    0.0
  }
}

///|
/// NMS 非极大值抑制
pub fn nms(
  boxes : Array[BoundingBox],
  iou_threshold? : Double = 0.5,
) -> Array[BoundingBox] raise @types.LoadError {
  // 输入验证
  if boxes.length() == 0 {
    raise @types.LoadError::DecodeFailed("nms: 检测框列表不能为空")
  }
  if iou_threshold < 0.0 || iou_threshold > 1.0 {
    raise @types.LoadError::DecodeFailed("nms: iou_threshold必须在0-1之间")
  }

  let threshold = iou_threshold
  // 按置信度降序排序（选择排序）
  let sorted = boxes
  let n = sorted.length()
  for i in 0..<n {
    let mut max_idx = i
    for j in (i + 1)..<n {
      if sorted[j].score > sorted[max_idx].score {
        max_idx = j
      }
    }
    if max_idx != i {
      let tmp = sorted[i]
      sorted[i] = sorted[max_idx]
      sorted[max_idx] = tmp
    }
  }
  // NMS
  let suppressed : Array[Bool] = Array::make(n, false)
  let result : Array[BoundingBox] = []
  for i in 0..<n {
    if suppressed[i] {
      continue
    }
    result.push(sorted[i])
    for j in (i + 1)..<n {
      if suppressed[j] {
        continue
      }
      if bbox_iou(sorted[i], sorted[j]) > threshold {
        suppressed[j] = true
      }
    }
  }
  result
}

///|
/// 将检测结果可视化为带框图像
pub fn draw_detections(
  img : @types.Image,
  boxes : Array[BoundingBox],
) -> @types.Image raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "draw_detections: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "draw_detections: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "draw_detections: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }

  let w = img.width
  let h = img.height
  let channels = img.channels
  let out_data : Array[Byte] = Array::make(w * h * channels, b'\x00')
  // 复制原图
  for i in 0..<(w * h * channels) {
    out_data[i] = img.data[i]
  }
  // 绘制检测框（红色，2像素宽）
  for bbox in boxes {
    let color = if channels >= 3 {
      [b'\xFF', b'\x00', b'\x00']
    } else {
      [b'\xFF']
    }
    // 上下边
    for x in bbox.x..<(bbox.x + bbox.width) {
      for dy in 0..<2 {
        let y_top = bbox.y + dy
        let y_bottom = bbox.y + bbox.height - 1 - dy
        if y_top >= 0 && y_top < h && x >= 0 && x < w {
          let idx = (y_top * w + x) * channels
          for c in 0..<channels.min(color.length()) {
            out_data[idx + c] = color[c]
          }
        }
        if y_bottom >= 0 && y_bottom < h && x >= 0 && x < w {
          let idx = (y_bottom * w + x) * channels
          for c in 0..<channels.min(color.length()) {
            out_data[idx + c] = color[c]
          }
        }
      }
    }
    // 左右边
    for y in bbox.y..<(bbox.y + bbox.height) {
      for dx in 0..<2 {
        let x_left = bbox.x + dx
        let x_right = bbox.x + bbox.width - 1 - dx
        if x_left >= 0 && x_left < w && y >= 0 && y < h {
          let idx = (y * w + x_left) * channels
          for c in 0..<channels.min(color.length()) {
            out_data[idx + c] = color[c]
          }
        }
        if x_right >= 0 && x_right < w && y >= 0 && y < h {
          let idx = (y * w + x_right) * channels
          for c in 0..<channels.min(color.length()) {
            out_data[idx + c] = color[c]
          }
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
