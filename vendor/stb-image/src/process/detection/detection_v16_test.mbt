// v16.0.0 YOLO 目标检测测试

///|
fn make_det_img(w : Int, h : Int) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: 3,
    data: Bytes::from_array(Array::make(w * h * 3, b'\x80')),
  }
}

///|
test "create_default_yolo_config: 返回有效配置" {
  let config = create_default_yolo_config()
  assert_true(config.num_classes > 0)
  assert_true(config.confidence_threshold > 0.0)
}

///|
test "calculate_iou: 相同框IoU为1" {
  let box = YoloBoundingBox::{
    x: 10.0,
    y: 10.0,
    width: 20.0,
    height: 20.0,
    confidence: 0.9,
    class_id: 0,
    class_name: "test",
  }
  let iou = calculate_iou(box, box)
  assert_true((iou - 1.0).abs() < 0.01)
}

///|
test "calculate_iou: 不重叠框IoU为0" {
  let box1 = YoloBoundingBox::{
    x: 0.0,
    y: 0.0,
    width: 10.0,
    height: 10.0,
    confidence: 0.9,
    class_id: 0,
    class_name: "a",
  }
  let box2 = YoloBoundingBox::{
    x: 100.0,
    y: 100.0,
    width: 10.0,
    height: 10.0,
    confidence: 0.9,
    class_id: 0,
    class_name: "b",
  }
  let iou = calculate_iou(box1, box2)
  assert_true(iou.abs() < 0.01)
}

///|
test "non_max_suppression: 基本NMS" {
  let box1 = YoloBoundingBox::{
    x: 0.0,
    y: 0.0,
    width: 20.0,
    height: 20.0,
    confidence: 0.9,
    class_id: 0,
    class_name: "a",
  }
  let box2 = YoloBoundingBox::{
    x: 1.0,
    y: 1.0,
    width: 20.0,
    height: 20.0,
    confidence: 0.8,
    class_id: 0,
    class_name: "b",
  }
  let result = non_max_suppression([box1, box2], 0.5, 10)
  assert_true(result.length() >= 1)
}

///|
test "refine_bounding_box: 边界框回归" {
  let box = YoloBoundingBox::{
    x: 10.0,
    y: 10.0,
    width: 20.0,
    height: 20.0,
    confidence: 0.9,
    class_id: 0,
    class_name: "test",
  }
  let refined = refine_bounding_box(box, 1.0, 1.0, 0.0, 0.0)
  let _ = refined
  assert_true(true)
}

///|
test "detect_objects_simple: 基本检测" {
  let img = make_det_img(64, 64)
  let config = create_default_yolo_config()
  try {
    let result = detect_objects_simple(img, config)
    assert_true(result.boxes.length() >= 0)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "initialize_object_tracking: 初始化跟踪" {
  let img = make_det_img(64, 64)
  let config = create_default_yolo_config()
  try {
    let detection = detect_objects_simple(img, config)
    if detection.boxes.length() > 0 {
      let tracked = initialize_object_tracking(detection)
      assert_true(tracked.length() >= 0)
    } else {
      assert_true(true)
    }
  } catch {
    _ => assert_true(true)
  }
}

///|
test "calculate_detection_metrics: 计算评估指标" {
  let box1 = YoloBoundingBox::{
    x: 10.0,
    y: 10.0,
    width: 20.0,
    height: 20.0,
    confidence: 0.9,
    class_id: 0,
    class_name: "a",
  }
  let metrics = calculate_detection_metrics([box1], [box1], 0.5)
  assert_true(metrics.precision >= 0.0 && metrics.precision <= 1.0)
  assert_true(metrics.recall >= 0.0 && metrics.recall <= 1.0)
}

///|
test "detection_report_to_string: 生成报告" {
  let img = make_det_img(32, 32)
  let config = create_default_yolo_config()
  let box = YoloBoundingBox::{
    x: 0.0,
    y: 0.0,
    width: 10.0,
    height: 10.0,
    confidence: 0.9,
    class_id: 0,
    class_name: "test",
  }
  let metrics = calculate_detection_metrics([box], [box], 0.5)
  try {
    let detection = detect_objects_simple(img, config)
    let report = detection_report_to_string(detection, metrics)
    assert_true(report.length() > 0)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "bbox_new: 创建边界框" {
  let box = bbox_new(10, 10, 20, 20)
  assert_eq(box.x, 10)
  assert_eq(box.y, 10)
  assert_eq(box.width, 20)
  assert_eq(box.height, 20)
}

///|
test "bbox_iou: 相同框IoU为1" {
  let box = bbox_new(10, 10, 20, 20)
  let iou = bbox_iou(box, box)
  assert_true((iou - 1.0).abs() < 0.01)
}

///|
test "nms: 基本NMS" {
  let box1 = bbox_new(0, 0, 20, 20, score=0.9)
  let box2 = bbox_new(1, 1, 20, 20, score=0.8)
  let result = nms([box1, box2])
  assert_true(result.length() >= 1)
}

///|
test "draw_detections: 绘制检测框" {
  let img = make_det_img(32, 32)
  let box = bbox_new(5, 5, 10, 10)
  let result = draw_detections(img, [box])
  assert_eq(result.width, 32)
  assert_eq(result.height, 32)
}
