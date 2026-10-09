// v17.0.0 图像分割增强测试
// 语义分割与实例分割：阈值分割、Otsu、K-Means、超像素、分水岭、GrabCut、评估指标、可视化、报告

///|
fn make_seg_img(w : Int, h : Int, value : Byte) -> @types.Image {
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(Array::make(w * h, value)),
  }
}

///|
fn make_bimodal_img(w : Int, h : Int) -> @types.Image {
  let arr : Array[Byte] = []
  for y in 0..<h {
    for _ in 0..<w {
      if y < h / 2 {
        arr.push(b'\x20')
      } else {
        arr.push(b'\xC0')
      }
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(arr),
  }
}

///|
fn make_gradient_img(w : Int, h : Int) -> @types.Image {
  let arr : Array[Byte] = []
  for _ in 0..<h {
    for x in 0..<w {
      let v = (x * 255 / (w - 1)).clamp(min=0, max=255)
      arr.push(v.to_byte())
    }
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(arr),
  }
}

///|
test "create_default_watershed_config: 返回有效配置" {
  let config = create_default_watershed_config()
  assert_true(config.min_region_size > 0)
  assert_true(config.max_regions > 0)
  assert_true(config.connectivity == 4 || config.connectivity == 8)
}

///|
test "create_default_kmeans_config: 返回有效配置" {
  let config = create_default_kmeans_config()
  assert_true(config.num_clusters > 0)
  assert_true(config.max_iterations > 0)
  assert_true(config.tolerance > 0.0)
}

///|
test "create_default_grabcut_config: 返回有效配置" {
  let config = create_default_grabcut_config()
  assert_true(config.num_iterations > 0)
  assert_true(config.gamma > 0.0)
}

///|
test "threshold_segmentation: 基本阈值分割" {
  let img = make_bimodal_img(8, 8)
  let result = threshold_segmentation(img, 128.0)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.num_classes, 2)
  assert_eq(result.labels.length(), 64)
  assert_eq(result.label_info.length(), 2)
  let mut fg_count = 0
  let mut bg_count = 0
  for l in result.labels {
    if l == 1 {
      fg_count += 1
    } else {
      bg_count += 1
    }
  }
  assert_eq(fg_count, 32)
  assert_eq(bg_count, 32)
}

///|
test "threshold_segmentation: 全黑图像" {
  let img = make_seg_img(4, 4, b'\x00')
  let result = threshold_segmentation(img, 128.0)
  assert_eq(result.num_classes, 2)
  let mut all_bg = true
  for l in result.labels {
    if l != 0 {
      all_bg = false
    }
  }
  assert_true(all_bg)
}

///|
test "threshold_segmentation: 全白图像" {
  let img = make_seg_img(4, 4, b'\xFF')
  let result = threshold_segmentation(img, 128.0)
  assert_eq(result.num_classes, 2)
  let mut all_fg = true
  for l in result.labels {
    if l != 1 {
      all_fg = false
    }
  }
  assert_true(all_fg)
}

///|
test "otsu_threshold_value: 双峰图像" {
  let img = make_bimodal_img(16, 16)
  let threshold = otsu_threshold_value(img)
  assert_true(threshold >= 32.0 && threshold <= 192.0)
}

///|
test "otsu_threshold_value: 均匀图像" {
  let img = make_seg_img(8, 8, b'\x80')
  let threshold = otsu_threshold_value(img)
  assert_true(threshold >= 0.0 && threshold <= 255.0)
}

///|
test "otsu_threshold_value: 梯度图像" {
  let img = make_gradient_img(16, 4)
  let threshold = otsu_threshold_value(img)
  assert_true(threshold >= 0.0 && threshold <= 255.0)
}

///|
test "kmeans_segmentation: 基本聚类" {
  let img = make_bimodal_img(8, 8)
  let config = KMeansConfig::{
    num_clusters: 2,
    max_iterations: 10,
    tolerance: 0.001,
    use_color_space: false,
    random_seed: 42,
  }
  let result = kmeans_segmentation(img, config)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.num_classes, 2)
  assert_eq(result.labels.length(), 64)
  assert_eq(result.label_info.length(), 2)
}

///|
test "kmeans_segmentation: 单聚类" {
  let img = make_seg_img(4, 4, b'\x80')
  let config = KMeansConfig::{
    num_clusters: 1,
    max_iterations: 5,
    tolerance: 0.001,
    use_color_space: false,
    random_seed: 42,
  }
  let result = kmeans_segmentation(img, config)
  assert_eq(result.num_classes, 1)
  let mut all_same = true
  for l in result.labels {
    if l != 0 {
      all_same = false
    }
  }
  assert_true(all_same)
}

///|
test "superpixel_segmentation: 基本超像素" {
  let img = make_gradient_img(16, 16)
  let result = superpixel_segmentation(img, 4)
  assert_eq(result.width, 16)
  assert_eq(result.height, 16)
  assert_eq(result.labels.length(), 256)
  assert_true(result.num_superpixels >= 0)
}

///|
test "superpixel_segmentation: 均匀图像" {
  let img = make_seg_img(8, 8, b'\x80')
  let result = superpixel_segmentation(img, 2)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.labels.length(), 64)
}

///|
test "watershed_segmentation: 基本分水岭" {
  let img = make_bimodal_img(8, 8)
  let config = WatershedConfig::{
    min_region_size: 1,
    max_regions: 10,
    use_markers: false,
    connectivity: 8,
  }
  let result = watershed_segmentation(img, config)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.labels.length(), 64)
  assert_true(result.num_classes >= 1)
  assert_eq(result.label_info.length(), result.num_classes)
}

///|
test "watershed_segmentation: 梯度图像" {
  let img = make_gradient_img(8, 8)
  let config = create_default_watershed_config()
  let result = watershed_segmentation(img, config)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_true(result.num_classes >= 1)
}

///|
test "grabcut_segmentation: 基本GrabCut" {
  let img = make_bimodal_img(8, 8)
  let config = GrabCutConfig::{ num_iterations: 3, gamma: 50.0, use_gmm: false }
  let result = grabcut_segmentation(img, 2, 2, 4, 4, config)
  assert_eq(result.width, 8)
  assert_eq(result.height, 8)
  assert_eq(result.num_classes, 2)
  assert_eq(result.labels.length(), 64)
  assert_eq(result.label_info.length(), 2)
}

///|
test "grabcut_segmentation: 全图矩形" {
  let img = make_seg_img(6, 6, b'\x80')
  let config = create_default_grabcut_config()
  let result = grabcut_segmentation(img, 0, 0, 6, 6, config)
  assert_eq(result.width, 6)
  assert_eq(result.height, 6)
  assert_eq(result.num_classes, 2)
}

///|
test "calculate_segmentation_metrics: 完美预测" {
  let pred = [0, 0, 1, 1, 0, 0, 1, 1]
  let gt = [0, 0, 1, 1, 0, 0, 1, 1]
  let metrics = calculate_segmentation_metrics(pred, gt, 2)
  assert_true((metrics.pixel_accuracy - 1.0).abs() < 0.001)
  assert_true(metrics.true_positives == 4)
  assert_true(metrics.false_positives == 0)
  assert_true(metrics.false_negatives == 0)
}

///|
test "calculate_segmentation_metrics: 完全错误" {
  let pred = [1, 1, 0, 0]
  let gt = [0, 0, 1, 1]
  let metrics = calculate_segmentation_metrics(pred, gt, 2)
  assert_true(metrics.pixel_accuracy < 0.001)
  assert_true(metrics.true_positives == 0)
  assert_true(metrics.dice_coefficient < 0.001)
}

///|
test "calculate_segmentation_metrics: 部分正确" {
  let pred = [1, 1, 0, 0, 1, 0]
  let gt = [1, 0, 0, 0, 1, 1]
  let metrics = calculate_segmentation_metrics(pred, gt, 2)
  assert_true(metrics.pixel_accuracy > 0.0 && metrics.pixel_accuracy < 1.0)
  assert_true(metrics.true_positives == 2)
  assert_true(metrics.false_positives == 1)
  assert_true(metrics.false_negatives == 1)
  let expected_dice = 2.0 * 2.0 / (2.0 * 2.0 + 1.0 + 1.0)
  assert_true((metrics.dice_coefficient - expected_dice).abs() < 0.001)
}

///|
test "calculate_segmentation_metrics: 空数组" {
  let pred : Array[Int] = []
  let gt : Array[Int] = []
  let metrics = calculate_segmentation_metrics(pred, gt, 2)
  assert_true(metrics.pixel_accuracy == 0.0)
  assert_true(metrics.mean_iou == 0.0)
}

///|
test "segmentation_to_image: 可视化" {
  let img = make_bimodal_img(4, 4)
  let result = threshold_segmentation(img, 128.0)
  let vis = segmentation_to_image(result)
  assert_eq(vis.width, 4)
  assert_eq(vis.height, 4)
  assert_eq(vis.channels, 1)
  assert_eq(vis.data.length(), 16)
}

///|
test "segmentation_to_image: 单类别" {
  let result = SemanticSegmentationResult::{
    width: 2,
    height: 2,
    labels: [0, 0, 0, 0],
    label_info: [
      SegmentationLabel::{ id: 0, name: "bg", color: (0, 0, 0), pixel_count: 4 },
    ],
    num_classes: 1,
    inference_time_ms: 0.0,
  }
  let vis = segmentation_to_image(result)
  assert_eq(vis.width, 2)
  assert_eq(vis.height, 2)
  assert_eq(vis.data.length(), 4)
}

///|
test "segmentation_report_to_string: 报告生成" {
  let result = SemanticSegmentationResult::{
    width: 4,
    height: 4,
    labels: Array::make(8, 0) + Array::make(8, 1),
    label_info: [
      SegmentationLabel::{
        id: 0,
        name: "background",
        color: (0, 0, 0),
        pixel_count: 8,
      },
      SegmentationLabel::{
        id: 1,
        name: "foreground",
        color: (255, 255, 255),
        pixel_count: 8,
      },
    ],
    num_classes: 2,
    inference_time_ms: 1.5,
  }
  let metrics = SegmentationMetrics::{
    pixel_accuracy: 0.9,
    mean_iou: 0.8,
    mean_accuracy: 0.9,
    frequency_weighted_iou: 0.8,
    dice_coefficient: 0.85,
    true_positives: 7,
    false_positives: 1,
    false_negatives: 1,
  }
  let report = segmentation_report_to_string(result, metrics)
  assert_true(report.contains("图像分割报告"))
  assert_true(report.contains("Pixel Accuracy"))
  assert_true(report.contains("Mean IoU"))
  assert_true(report.contains("Dice Coefficient"))
  assert_true(report.contains("background"))
  assert_true(report.contains("foreground"))
}

///|
test "segmentation_report_to_string: 空分割" {
  let result = SemanticSegmentationResult::{
    width: 1,
    height: 1,
    labels: [0],
    label_info: [
      SegmentationLabel::{ id: 0, name: "bg", color: (0, 0, 0), pixel_count: 1 },
    ],
    num_classes: 1,
    inference_time_ms: 0.0,
  }
  let metrics = SegmentationMetrics::{
    pixel_accuracy: 1.0,
    mean_iou: 1.0,
    mean_accuracy: 1.0,
    frequency_weighted_iou: 1.0,
    dice_coefficient: 1.0,
    true_positives: 1,
    false_positives: 0,
    false_negatives: 0,
  }
  let report = segmentation_report_to_string(result, metrics)
  assert_true(report.length() > 0)
  assert_true(report.contains("图像分割报告"))
}
