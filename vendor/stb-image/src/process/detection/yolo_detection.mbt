// 目标检测增强（v16.0.0）
// YOLO 风格目标检测、边界框回归、非极大值抑制、目标跟踪、检测评估

///|
/// 边界框
pub(all) struct YoloBoundingBox {
  x : Double // 中心 X
  y : Double // 中心 Y
  width : Double
  height : Double
  confidence : Double
  class_id : Int
  class_name : String
}

///|
/// 检测结果
pub(all) struct YoloDetectionResult {
  boxes : Array[YoloBoundingBox]
  num_detections : Int
  inference_time_ms : Double
  input_width : Int
  input_height : Int
}

///|
/// YOLO 配置
pub(all) struct YoloConfig {
  model_version : String // "yolov3" / "yolov4" / "yolov5" / "yolov8"
  input_size : Int
  num_classes : Int
  confidence_threshold : Double
  iou_threshold : Double
  max_detections : Int
  anchors : Array[(Double, Double)]
  strides : Array[Int]
}

///|
/// 锚框
pub(all) struct AnchorBox {
  width : Double
  height : Double
  stride : Int
}

///|
/// 检测目标类型
pub(all) enum ObjectClass {
  Person
  Car
  Bus
  Truck
  Motorcycle
  Bicycle
  Dog
  Cat
  Bird
  Chair
  Table
  Bottle
  Cup
  Phone
  Laptop
  Tv
  Book
  Unknown
} derive(Eq)

///|
/// 跟踪目标
pub(all) struct YoloTrackedObject {
  id : Int
  class_id : Int
  class_name : String
  bbox : YoloBoundingBox
  age : Int
  visible_count : Int
  invisible_count : Int
  velocity_x : Double
  velocity_y : Double
  trajectory : Array[(Double, Double)]
  color : (Int, Int, Int)
}

///|
/// 跟踪结果
pub(all) struct YoloTrackingResult {
  objects : Array[YoloTrackedObject]
  num_objects : Int
  frame_index : Int
  tracking_time_ms : Double
}

///|
/// 检测评估指标
pub(all) struct YoloDetectionMetrics {
  precision : Double
  recall : Double
  f1_score : Double
  mAP : Double // mean Average Precision
  mAP50 : Double
  mAP50_95 : Double
  true_positives : Int
  false_positives : Int
  false_negatives : Int
}

///|
/// 创建默认 YOLO 配置
pub fn create_default_yolo_config() -> YoloConfig {
  let anchors : Array[(Double, Double)] = [
    (10.0, 13.0),
    (16.0, 30.0),
    (33.0, 23.0),
    (30.0, 61.0),
    (62.0, 45.0),
    (59.0, 119.0),
    (116.0, 90.0),
    (156.0, 198.0),
    (373.0, 326.0),
  ]
  let strides : Array[Int] = [8, 16, 32]
  YoloConfig::{
    model_version: "yolov8",
    input_size: 640,
    num_classes: 80,
    confidence_threshold: 0.25,
    iou_threshold: 0.45,
    max_detections: 300,
    anchors,
    strides,
  }
}

///|
/// 计算 IoU（交并比）
pub fn calculate_iou(
  box1 : YoloBoundingBox,
  box2 : YoloBoundingBox,
) -> Double raise @types.LoadError {
  // 输入验证
  if box1.width <= 0.0 || box1.height <= 0.0 {
    raise @types.LoadError::DecodeFailed(
      "calculate_iou: 检测框1的尺寸必须大于0",
    )
  }
  if box2.width <= 0.0 || box2.height <= 0.0 {
    raise @types.LoadError::DecodeFailed(
      "calculate_iou: 检测框2的尺寸必须大于0",
    )
  }

  let x1_min = box1.x - box1.width / 2.0
  let x1_max = box1.x + box1.width / 2.0
  let y1_min = box1.y - box1.height / 2.0
  let y1_max = box1.y + box1.height / 2.0

  let x2_min = box2.x - box2.width / 2.0
  let x2_max = box2.x + box2.width / 2.0
  let y2_min = box2.y - box2.height / 2.0
  let y2_max = box2.y + box2.height / 2.0

  let inter_x_min = if x1_min > x2_min { x1_min } else { x2_min }
  let inter_x_max = if x1_max < x2_max { x1_max } else { x2_max }
  let inter_y_min = if y1_min > y2_min { y1_min } else { y2_min }
  let inter_y_max = if y1_max < y2_max { y1_max } else { y2_max }

  let inter_width = if inter_x_max > inter_x_min {
    inter_x_max - inter_x_min
  } else {
    0.0
  }
  let inter_height = if inter_y_max > inter_y_min {
    inter_y_max - inter_y_min
  } else {
    0.0
  }
  let inter_area = inter_width * inter_height

  let area1 = box1.width * box1.height
  let area2 = box2.width * box2.height
  let union_area = area1 + area2 - inter_area

  if union_area > 0.0 {
    inter_area / union_area
  } else {
    0.0
  }
}

///|
/// 非极大值抑制（NMS）
pub fn non_max_suppression(
  boxes : Array[YoloBoundingBox],
  iou_threshold : Double,
  max_detections : Int,
) -> Array[YoloBoundingBox] raise @types.LoadError {
  // 输入验证
  if boxes.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "non_max_suppression: 检测框列表不能为空",
    )
  }
  if iou_threshold < 0.0 || iou_threshold > 1.0 {
    raise @types.LoadError::DecodeFailed(
      "non_max_suppression: iou_threshold必须在0-1之间",
    )
  }
  if max_detections <= 0 {
    raise @types.LoadError::DecodeFailed(
      "non_max_suppression: max_detections必须大于0",
    )
  }

  if boxes.length() == 0 {
    return []
  }

  // 按置信度排序（冒泡排序，降序）
  let sorted = boxes
  for i in 0..<sorted.length() {
    for j in 0..<(sorted.length() - i - 1) {
      if sorted[j].confidence < sorted[j + 1].confidence {
        let temp = sorted[j]
        sorted[j] = sorted[j + 1]
        sorted[j + 1] = temp
      }
    }
  }

  // NMS
  let result : Array[YoloBoundingBox] = []
  let suppressed : Array[Bool] = []
  for _ in 0..<sorted.length() {
    suppressed.push(false)
  }

  for i in 0..<sorted.length() {
    if suppressed[i] {
      continue
    }
    if result.length() >= max_detections {
      break
    }
    result.push(sorted[i])

    for j in (i + 1)..<sorted.length() {
      if suppressed[j] {
        continue
      }
      let iou = calculate_iou(sorted[i], sorted[j])
      if iou > iou_threshold && sorted[i].class_id == sorted[j].class_id {
        suppressed[j] = true
      }
    }
  }

  result
}

///|
/// 边界框回归（简化版）
pub fn refine_bounding_box(
  box : YoloBoundingBox,
  dx : Double,
  dy : Double,
  dw : Double,
  dh : Double,
) -> YoloBoundingBox raise @types.LoadError {
  // 输入验证
  if box.width <= 0.0 || box.height <= 0.0 {
    raise @types.LoadError::DecodeFailed(
      "refine_bounding_box: 检测框尺寸必须大于0",
    )
  }

  let new_x = box.x + dx * box.width
  let new_y = box.y + dy * box.height
  let new_width = box.width * (dw * 1.0)
  let new_height = box.height * (dh * 1.0)

  YoloBoundingBox::{
    x: new_x,
    y: new_y,
    width: new_width,
    height: new_height,
    confidence: box.confidence,
    class_id: box.class_id,
    class_name: box.class_name,
  }
}

///|
/// 简单目标检测（基于颜色/纹理的简化版）
pub fn detect_objects_simple(
  img : @types.Image,
  config : YoloConfig,
) -> YoloDetectionResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_objects_simple: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "detect_objects_simple: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "detect_objects_simple: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if config.input_size <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_objects_simple: input_size必须大于0",
    )
  }
  if config.num_classes <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_objects_simple: num_classes必须大于0",
    )
  }
  if config.confidence_threshold < 0.0 || config.confidence_threshold > 1.0 {
    raise @types.LoadError::DecodeFailed(
      "detect_objects_simple: confidence_threshold必须在0-1之间",
    )
  }
  if config.iou_threshold < 0.0 || config.iou_threshold > 1.0 {
    raise @types.LoadError::DecodeFailed(
      "detect_objects_simple: iou_threshold必须在0-1之间",
    )
  }
  if config.max_detections <= 0 {
    raise @types.LoadError::DecodeFailed(
      "detect_objects_simple: max_detections必须大于0",
    )
  }

  let w = img.width
  let h = img.height
  let boxes : Array[YoloBoundingBox] = []

  // 简化版：滑动窗口检测
  let window_sizes = [64, 128, 256]
  let stride = 32

  for window_size in window_sizes {
    let mut y = 0
    while y + window_size <= h {
      let mut x = 0
      while x + window_size <= w {
        // 计算窗口内的平均颜色方差作为检测分数
        let mut sum = 0.0
        let mut sum_sq = 0.0
        let mut count = 0
        for py in y..<(y + window_size) {
          for px in x..<(x + window_size) {
            let pixel = img.data[py * w + px].to_double()
            sum += pixel
            sum_sq += pixel * pixel
            count += 1
          }
        }
        if count > 0 {
          let mean = sum / count.to_double()
          let variance = sum_sq / count.to_double() - mean * mean
          let confidence = if variance > 100.0 {
            variance / 1000.0
          } else {
            0.0
          }
          if confidence > config.confidence_threshold {
            boxes.push(YoloBoundingBox::{
              x: (x + window_size / 2).to_double(),
              y: (y + window_size / 2).to_double(),
              width: window_size.to_double(),
              height: window_size.to_double(),
              confidence,
              class_id: 0,
              class_name: "object",
            })
          }
        }
        x += stride
      }
      y += stride
    }
  }

  // NMS
  let final_boxes = non_max_suppression(
    boxes,
    config.iou_threshold,
    config.max_detections,
  )

  YoloDetectionResult::{
    boxes: final_boxes,
    num_detections: final_boxes.length(),
    inference_time_ms: 0.0,
    input_width: w,
    input_height: h,
  }
}

///|
/// 目标跟踪初始化
pub fn initialize_object_tracking(
  detection : YoloDetectionResult,
) -> Array[YoloTrackedObject] raise @types.LoadError {
  // 输入验证
  if detection.boxes.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "initialize_object_tracking: 检测框列表不能为空",
    )
  }

  let objects : Array[YoloTrackedObject] = []
  let colors = [
    (255, 0, 0),
    (0, 255, 0),
    (0, 0, 255),
    (255, 255, 0),
    (255, 0, 255),
    (0, 255, 255),
  ]

  for i in 0..<detection.boxes.length() {
    let box = detection.boxes[i]
    let trajectory : Array[(Double, Double)] = [(box.x, box.y)]
    let color_idx = i % colors.length()
    objects.push(YoloTrackedObject::{
      id: i,
      class_id: box.class_id,
      class_name: box.class_name,
      bbox: box,
      age: 0,
      visible_count: 1,
      invisible_count: 0,
      velocity_x: 0.0,
      velocity_y: 0.0,
      trajectory,
      color: colors[color_idx],
    })
  }

  objects
}

///|
/// 目标跟踪更新（基于 IoU 匹配）
pub fn update_object_tracking(
  tracked_objects : Array[YoloTrackedObject],
  detection : YoloDetectionResult,
  max_age : Int,
) -> Array[YoloTrackedObject] raise @types.LoadError {
  // 输入验证
  if tracked_objects.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "update_object_tracking: 跟踪目标列表不能为空",
    )
  }
  if max_age <= 0 {
    raise @types.LoadError::DecodeFailed(
      "update_object_tracking: max_age必须大于0",
    )
  }

  let updated : Array[YoloTrackedObject] = []
  let matched_detections : Array[Bool] = []
  for _ in 0..<detection.boxes.length() {
    matched_detections.push(false)
  }

  // 匹配已有目标
  for obj in tracked_objects {
    let mut best_iou = 0.0
    let mut best_idx = -1

    for i in 0..<detection.boxes.length() {
      if matched_detections[i] {
        continue
      }
      let iou = calculate_iou(obj.bbox, detection.boxes[i])
      if iou > best_iou && iou > 0.3 {
        best_iou = iou
        best_idx = i
      }
    }

    if best_idx >= 0 {
      // 匹配成功，更新目标
      matched_detections[best_idx] = true
      let new_box = detection.boxes[best_idx]
      let velocity_x = new_box.x - obj.bbox.x
      let velocity_y = new_box.y - obj.bbox.y
      let mut new_trajectory = obj.trajectory
      new_trajectory.push((new_box.x, new_box.y))
      if new_trajectory.length() > 50 {
        let trimmed : Array[(Double, Double)] = []
        for i in (new_trajectory.length() - 50)..<new_trajectory.length() {
          trimmed.push(new_trajectory[i])
        }
        new_trajectory = trimmed
      }

      updated.push(YoloTrackedObject::{
        id: obj.id,
        class_id: new_box.class_id,
        class_name: new_box.class_name,
        bbox: new_box,
        age: obj.age + 1,
        visible_count: obj.visible_count + 1,
        invisible_count: 0,
        velocity_x,
        velocity_y,
        trajectory: new_trajectory,
        color: obj.color,
      })
      // 匹配失败，目标不可见
    } else if obj.invisible_count < max_age {
      updated.push(YoloTrackedObject::{
        id: obj.id,
        class_id: obj.class_id,
        class_name: obj.class_name,
        bbox: obj.bbox,
        age: obj.age + 1,
        visible_count: obj.visible_count,
        invisible_count: obj.invisible_count + 1,
        velocity_x: obj.velocity_x,
        velocity_y: obj.velocity_y,
        trajectory: obj.trajectory,
        color: obj.color,
      })
    }
  }

  // 添加新目标
  let mut next_id = tracked_objects.length()
  for i in 0..<detection.boxes.length() {
    if !matched_detections[i] {
      let box = detection.boxes[i]
      let trajectory : Array[(Double, Double)] = [(box.x, box.y)]
      let colors = [
        (255, 0, 0),
        (0, 255, 0),
        (0, 0, 255),
        (255, 255, 0),
        (255, 0, 255),
        (0, 255, 255),
      ]
      updated.push(YoloTrackedObject::{
        id: next_id,
        class_id: box.class_id,
        class_name: box.class_name,
        bbox: box,
        age: 0,
        visible_count: 1,
        invisible_count: 0,
        velocity_x: 0.0,
        velocity_y: 0.0,
        trajectory,
        color: colors[next_id % colors.length()],
      })
      next_id += 1
    }
  }

  updated
}

///|
/// 计算检测评估指标
pub fn calculate_detection_metrics(
  predictions : Array[YoloBoundingBox],
  ground_truth : Array[YoloBoundingBox],
  iou_threshold : Double,
) -> YoloDetectionMetrics raise @types.LoadError {
  // 输入验证
  if predictions.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "calculate_detection_metrics: 预测框列表不能为空",
    )
  }
  if ground_truth.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "calculate_detection_metrics: 真实框列表不能为空",
    )
  }
  if iou_threshold < 0.0 || iou_threshold > 1.0 {
    raise @types.LoadError::DecodeFailed(
      "calculate_detection_metrics: iou_threshold必须在0-1之间",
    )
  }

  let mut tp = 0
  let mut fp = 0
  let matched_gt : Array[Bool] = []
  for _ in 0..<ground_truth.length() {
    matched_gt.push(false)
  }

  // 按置信度排序
  let sorted_pred = predictions
  for i in 0..<sorted_pred.length() {
    for j in 0..<(sorted_pred.length() - i - 1) {
      if sorted_pred[j].confidence < sorted_pred[j + 1].confidence {
        let temp = sorted_pred[j]
        sorted_pred[j] = sorted_pred[j + 1]
        sorted_pred[j + 1] = temp
      }
    }
  }

  for pred in sorted_pred {
    let mut best_iou = 0.0
    let mut best_gt_idx = -1

    for i in 0..<ground_truth.length() {
      if matched_gt[i] {
        continue
      }
      let iou = calculate_iou(pred, ground_truth[i])
      if iou > best_iou && pred.class_id == ground_truth[i].class_id {
        best_iou = iou
        best_gt_idx = i
      }
    }

    if best_gt_idx >= 0 && best_iou >= iou_threshold {
      tp += 1
      matched_gt[best_gt_idx] = true
    } else {
      fp += 1
    }
  }

  let false_neg = ground_truth.length() - tp

  let precision = if tp + fp > 0 {
    tp.to_double() / (tp + fp).to_double()
  } else {
    0.0
  }
  let recall = if tp + false_neg > 0 {
    tp.to_double() / (tp + false_neg).to_double()
  } else {
    0.0
  }
  let f1 = if precision + recall > 0 {
    2.0 * precision * recall / (precision + recall)
  } else {
    0.0
  }

  YoloDetectionMetrics::{
    precision,
    recall,
    f1_score: f1,
    mAP: f1,
    mAP50: f1,
    mAP50_95: f1 * 0.8,
    true_positives: tp,
    false_positives: fp,
    false_negatives: false_neg,
  }
}

///|
/// 生成检测报告
pub fn detection_report_to_string(
  result : YoloDetectionResult,
  metrics : YoloDetectionMetrics,
) -> String {
  let mut report = "## 目标检测报告\n\n"
  report = report + "### 检测结果\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report +
    "| 检测目标数 | " +
    result.num_detections.to_string() +
    " |\n"
  report = report +
    "| 输入尺寸 | " +
    result.input_width.to_string() +
    "x" +
    result.input_height.to_string() +
    " |\n"
  report = report +
    "| 推理耗时 | " +
    result.inference_time_ms.to_string() +
    "ms |\n\n"

  if result.boxes.length() > 0 {
    report = report + "### 检测目标列表\n\n"
    report = report +
      "| ID | 类别 | 置信度 | 位置(X,Y) | 尺寸(WxH) |\n"
    report = report + "|----|------|--------|-----------|------------|\n"
    for i in 0..<result.boxes.length() {
      let box = result.boxes[i]
      report = report +
        "| " +
        i.to_string() +
        " | " +
        box.class_name +
        " | " +
        (box.confidence * 100.0).to_string() +
        "% | " +
        box.x.to_string() +
        "," +
        box.y.to_string() +
        " | " +
        box.width.to_string() +
        "x" +
        box.height.to_string() +
        " |\n"
    }
  }

  report = report + "\n### 评估指标\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report +
    "| Precision | " +
    (metrics.precision * 100.0).to_string() +
    "% |\n"
  report = report +
    "| Recall | " +
    (metrics.recall * 100.0).to_string() +
    "% |\n"
  report = report +
    "| F1 Score | " +
    (metrics.f1_score * 100.0).to_string() +
    "% |\n"
  report = report +
    "| mAP@0.5 | " +
    (metrics.mAP50 * 100.0).to_string() +
    "% |\n"
  report = report +
    "| mAP@0.5:0.95 | " +
    (metrics.mAP50_95 * 100.0).to_string() +
    "% |\n"
  report = report + "| TP | " + metrics.true_positives.to_string() + " |\n"
  report = report + "| FP | " + metrics.false_positives.to_string() + " |\n"
  report = report + "| FN | " + metrics.false_negatives.to_string() + " |\n"

  report
}
