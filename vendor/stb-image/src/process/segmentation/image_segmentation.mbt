// 图像分割增强（v17.0.0）
// 语义分割、实例分割、超像素分割、分水岭算法、K-Means 聚类分割、GrabCut

///|
/// 分割标签
pub(all) struct SegmentationLabel {
  id : Int
  name : String
  color : (Int, Int, Int)
  pixel_count : Int
}

///|
/// 语义分割结果
pub(all) struct SemanticSegmentationResult {
  width : Int
  height : Int
  labels : Array[Int] // 每个像素的标签 ID
  label_info : Array[SegmentationLabel]
  num_classes : Int
  inference_time_ms : Double
}

///|
/// 实例分割结果
pub(all) struct InstanceSegmentationResult {
  width : Int
  height : Int
  masks : Array[Array[Bool]] // 每个实例的掩码
  boxes : Array[(Int, Int, Int, Int)] // 每个实例的边界框 (x, y, w, h)
  class_ids : Array[Int]
  class_names : Array[String]
  confidences : Array[Double]
  num_instances : Int
}

///|
/// 超像素
pub(all) struct Superpixel {
  id : Int
  center_x : Double
  center_y : Double
  size : Int
  mean_color : Double
  label : Int
}

///|
/// 超像素分割结果
pub(all) struct SuperpixelResult {
  width : Int
  height : Int
  labels : Array[Int] // 每个像素的超像素 ID
  superpixels : Array[Superpixel]
  num_superpixels : Int
}

///|
/// 分水岭分割配置
pub(all) struct WatershedConfig {
  min_region_size : Int
  max_regions : Int
  use_markers : Bool
  connectivity : Int // 4 或 8
}

///|
/// K-Means 分割配置
pub(all) struct KMeansConfig {
  num_clusters : Int
  max_iterations : Int
  tolerance : Double
  use_color_space : Bool
  random_seed : Int
}

///|
/// GrabCut 配置
pub(all) struct GrabCutConfig {
  num_iterations : Int
  gamma : Double
  use_gmm : Bool
}

///|
/// 分割评估指标
pub(all) struct SegmentationMetrics {
  pixel_accuracy : Double
  mean_iou : Double
  mean_accuracy : Double
  frequency_weighted_iou : Double
  dice_coefficient : Double
  true_positives : Int
  false_positives : Int
  false_negatives : Int
}

///|
/// 创建默认分水岭配置
pub fn create_default_watershed_config() -> WatershedConfig {
  WatershedConfig::{
    min_region_size: 50,
    max_regions: 100,
    use_markers: true,
    connectivity: 8,
  }
}

///|
/// 创建默认 K-Means 配置
pub fn create_default_kmeans_config() -> KMeansConfig {
  KMeansConfig::{
    num_clusters: 5,
    max_iterations: 100,
    tolerance: 0.001,
    use_color_space: true,
    random_seed: 42,
  }
}

///|
/// 创建默认 GrabCut 配置
pub fn create_default_grabcut_config() -> GrabCutConfig {
  GrabCutConfig::{ num_iterations: 5, gamma: 50.0, use_gmm: true }
}

///|
/// 简单阈值分割
pub fn threshold_segmentation(
  img : @types.Image,
  threshold : Double,
) -> SemanticSegmentationResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "threshold_segmentation: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "threshold_segmentation: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "threshold_segmentation: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let labels : Array[Int] = []
  let mut fg_count = 0
  let mut bg_count = 0

  for y in 0..<h {
    for x in 0..<w {
      let pixel = img.data[y * w + x].to_double()
      if pixel > threshold {
        labels.push(1)
        fg_count += 1
      } else {
        labels.push(0)
        bg_count += 1
      }
    }
  }

  let label_info : Array[SegmentationLabel] = [
    SegmentationLabel::{
      id: 0,
      name: "background",
      color: (0, 0, 0),
      pixel_count: bg_count,
    },
    SegmentationLabel::{
      id: 1,
      name: "foreground",
      color: (255, 255, 255),
      pixel_count: fg_count,
    },
  ]

  SemanticSegmentationResult::{
    width: w,
    height: h,
    labels,
    label_info,
    num_classes: 2,
    inference_time_ms: 0.0,
  }
}

///|
/// Otsu 自动阈值分割
pub fn otsu_threshold_value(
  img : @types.Image,
) -> Double raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "otsu_threshold_value: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "otsu_threshold_value: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "otsu_threshold_value: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let histogram : Array[Int] = []
  for _ in 0..<256 {
    histogram.push(0)
  }

  for y in 0..<h {
    for x in 0..<w {
      let pixel = img.data[y * w + x].to_int()
      histogram[pixel] += 1
    }
  }

  let total = w * h
  let mut sum = 0.0
  for i in 0..<256 {
    sum += i.to_double() * histogram[i].to_double()
  }

  let mut sum_b = 0.0
  let mut w_b = 0
  let mut max_variance = 0.0
  let mut threshold = 128.0

  for i in 0..<256 {
    w_b += histogram[i]
    if w_b == 0 {
      continue
    }
    let w_f = total - w_b
    if w_f == 0 {
      break
    }
    sum_b += i.to_double() * histogram[i].to_double()
    let m_b = sum_b / w_b.to_double()
    let m_f = (sum - sum_b) / w_f.to_double()
    let variance = w_b.to_double() * w_f.to_double() * (m_b - m_f) * (m_b - m_f)
    if variance > max_variance {
      max_variance = variance
      threshold = i.to_double()
    }
  }

  threshold
}

///|
/// K-Means 聚类分割
pub fn kmeans_segmentation(
  img : @types.Image,
  config : KMeansConfig,
) -> SemanticSegmentationResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "kmeans_segmentation: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "kmeans_segmentation: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "kmeans_segmentation: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let k = config.num_clusters
  let total = w * h

  // 初始化聚类中心
  let centers : Array[Double] = []
  for i in 0..<k {
    centers.push(i.to_double() * 255.0 / k.to_double() + 128.0 / k.to_double())
  }

  let labels : Array[Int] = []
  for _ in 0..<total {
    labels.push(0)
  }

  // K-Means 迭代
  for _ in 0..<config.max_iterations {
    // 分配标签
    for i in 0..<total {
      let pixel = img.data[i].to_double()
      let mut min_dist = 1000000.0
      let mut best_cluster = 0
      for c in 0..<k {
        let dist = (pixel - centers[c]) * (pixel - centers[c])
        if dist < min_dist {
          min_dist = dist
          best_cluster = c
        }
      }
      labels[i] = best_cluster
    }

    // 更新聚类中心
    let sums : Array[Double] = []
    let counts : Array[Int] = []
    for _ in 0..<k {
      sums.push(0.0)
      counts.push(0)
    }
    for i in 0..<total {
      let pixel = img.data[i].to_double()
      let cluster = labels[i]
      sums[cluster] += pixel
      counts[cluster] += 1
    }
    for c in 0..<k {
      if counts[c] > 0 {
        centers[c] = sums[c] / counts[c].to_double()
      }
    }
  }

  // 统计每个类别的像素数
  let pixel_counts : Array[Int] = []
  for _ in 0..<k {
    pixel_counts.push(0)
  }
  for i in 0..<total {
    pixel_counts[labels[i]] += 1
  }

  let label_info : Array[SegmentationLabel] = []
  let colors = [
    (255, 0, 0),
    (0, 255, 0),
    (0, 0, 255),
    (255, 255, 0),
    (255, 0, 255),
    (0, 255, 255),
    (128, 0, 0),
    (0, 128, 0),
    (0, 0, 128),
    (128, 128, 128),
  ]
  for c in 0..<k {
    label_info.push(SegmentationLabel::{
      id: c,
      name: "class_" + c.to_string(),
      color: colors[c % colors.length()],
      pixel_count: pixel_counts[c],
    })
  }

  SemanticSegmentationResult::{
    width: w,
    height: h,
    labels,
    label_info,
    num_classes: k,
    inference_time_ms: 0.0,
  }
}

///|
/// 超像素分割（简化版 SLIC）
pub fn superpixel_segmentation(
  img : @types.Image,
  num_superpixels : Int,
) -> SuperpixelResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "superpixel_segmentation: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "superpixel_segmentation: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "superpixel_segmentation: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let total = w * h
  let step = (total.to_double() / num_superpixels.to_double()).sqrt().to_int()
  let _ = w / step * (h / step)

  let labels : Array[Int] = []
  for _ in 0..<total {
    labels.push(-1)
  }

  // 初始化超像素中心
  let centers_x : Array[Double] = []
  let centers_y : Array[Double] = []
  let centers_color : Array[Double] = []
  let mut sp_id = 0
  let mut cy = step / 2
  while cy < h {
    let mut cx = step / 2
    while cx < w {
      centers_x.push(cx.to_double())
      centers_y.push(cy.to_double())
      centers_color.push(img.data[cy * w + cx].to_double())
      sp_id += 1
      cx += step
    }
    cy += step
  }

  // 简化的 SLIC 迭代
  for _ in 0..<5 {
    for sp in 0..<sp_id {
      let cx = centers_x[sp].to_int()
      let cy = centers_y[sp].to_int()
      for y in (cy - step)..<(cy + step) {
        if y < 0 || y >= h {
          continue
        }
        for x in (cx - step)..<(cx + step) {
          if x < 0 || x >= w {
            continue
          }
          let idx = y * w + x
          let pixel = img.data[idx].to_double()
          let color_dist = (pixel - centers_color[sp]).abs()
          let spatial_dist = (
              (x.to_double() - centers_x[sp]).abs() +
              (y.to_double() - centers_y[sp]).abs()
            ) /
            step.to_double()
          let dist = color_dist + spatial_dist * 10.0
          if labels[idx] == -1 || dist < 50.0 {
            labels[idx] = sp
          }
        }
      }
    }
  }

  // 计算超像素信息
  let superpixels : Array[Superpixel] = []
  for sp in 0..<sp_id {
    let mut sum_x = 0.0
    let mut sum_y = 0.0
    let mut sum_color = 0.0
    let mut count = 0
    for y in 0..<h {
      for x in 0..<w {
        if labels[y * w + x] == sp {
          sum_x += x.to_double()
          sum_y += y.to_double()
          sum_color += img.data[y * w + x].to_double()
          count += 1
        }
      }
    }
    if count > 0 {
      superpixels.push(Superpixel::{
        id: sp,
        center_x: sum_x / count.to_double(),
        center_y: sum_y / count.to_double(),
        size: count,
        mean_color: sum_color / count.to_double(),
        label: sp,
      })
    }
  }

  SuperpixelResult::{
    width: w,
    height: h,
    labels,
    superpixels,
    num_superpixels: superpixels.length(),
  }
}

///|
/// 分水岭分割（简化版）
pub fn watershed_segmentation(
  img : @types.Image,
  config : WatershedConfig,
) -> SemanticSegmentationResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "watershed_segmentation: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "watershed_segmentation: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "watershed_segmentation: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let total = w * h

  // 简化版：基于梯度的区域生长
  let labels : Array[Int] = []
  for _ in 0..<total {
    labels.push(-1)
  }

  // 找局部最小值作为种子点
  let mut region_id = 0
  for y in 1..<(h - 1) {
    for x in 1..<(w - 1) {
      let idx = y * w + x
      let pixel = img.data[idx].to_double()
      let mut is_min = true
      for dy in -1..<2 {
        for dx in -1..<2 {
          if dx == 0 && dy == 0 {
            continue
          }
          let neighbor = img.data[(y + dy) * w + (x + dx)].to_double()
          if neighbor < pixel {
            is_min = false
          }
        }
      }
      if is_min && labels[idx] == -1 {
        // 区域生长
        let queue_x : Array[Int] = [x]
        let queue_y : Array[Int] = [y]
        labels[idx] = region_id
        let mut queue_idx = 0
        while queue_idx < queue_x.length() {
          let cx = queue_x[queue_idx]
          let cy = queue_y[queue_idx]
          queue_idx += 1
          for dy in -1..<2 {
            for dx in -1..<2 {
              if dx == 0 && dy == 0 {
                continue
              }
              let nx = cx + dx
              let ny = cy + dy
              if nx < 0 || nx >= w || ny < 0 || ny >= h {
                continue
              }
              let nidx = ny * w + nx
              if labels[nidx] == -1 {
                let npixel = img.data[nidx].to_double()
                if npixel < pixel + 30.0 {
                  labels[nidx] = region_id
                  queue_x.push(nx)
                  queue_y.push(ny)
                }
              }
            }
          }
        }
        region_id += 1
        if region_id >= config.max_regions {
          break
        }
      }
    }
    if region_id >= config.max_regions {
      break
    }
  }

  // 未标记的像素归为背景
  for i in 0..<total {
    if labels[i] == -1 {
      labels[i] = region_id // 背景
    }
  }

  // 统计
  let pixel_counts : Array[Int] = []
  for _ in 0..<(region_id + 1) {
    pixel_counts.push(0)
  }
  for i in 0..<total {
    pixel_counts[labels[i]] += 1
  }

  let label_info : Array[SegmentationLabel] = []
  for r in 0..<(region_id + 1) {
    let name = if r == region_id {
      "background"
    } else {
      "region_" + r.to_string()
    }
    label_info.push(SegmentationLabel::{
      id: r,
      name,
      color: (r * 37 % 256, r * 73 % 256, r * 113 % 256),
      pixel_count: pixel_counts[r],
    })
  }

  SemanticSegmentationResult::{
    width: w,
    height: h,
    labels,
    label_info,
    num_classes: region_id + 1,
    inference_time_ms: 0.0,
  }
}

///|
/// GrabCut 前景提取（简化版）
pub fn grabcut_segmentation(
  img : @types.Image,
  rect_x : Int,
  rect_y : Int,
  rect_w : Int,
  rect_h : Int,
  config : GrabCutConfig,
) -> SemanticSegmentationResult raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "grabcut_segmentation: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "grabcut_segmentation: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "grabcut_segmentation: 数据大小不匹配",
    )
  }
  let w = img.width
  let h = img.height
  let total = w * h
  let labels : Array[Int] = []

  // 初始化：矩形内为可能前景，外为背景
  for y in 0..<h {
    for x in 0..<w {
      if x >= rect_x &&
        x < rect_x + rect_w &&
        y >= rect_y &&
        y < rect_y + rect_h {
        labels.push(1) // 可能前景
      } else {
        labels.push(0) // 背景
      }
    }
  }

  // 简化迭代：基于颜色相似度的前景/背景分类
  for _ in 0..<config.num_iterations {
    // 计算前景和背景的平均颜色
    let mut fg_sum = 0.0
    let mut fg_count = 0
    let mut bg_sum = 0.0
    let mut bg_count = 0
    for i in 0..<total {
      let pixel = img.data[i].to_double()
      if labels[i] == 1 {
        fg_sum += pixel
        fg_count += 1
      } else {
        bg_sum += pixel
        bg_count += 1
      }
    }
    let fg_mean = if fg_count > 0 {
      fg_sum / fg_count.to_double()
    } else {
      128.0
    }
    let bg_mean = if bg_count > 0 {
      bg_sum / bg_count.to_double()
    } else {
      128.0
    }

    // 重新分类
    for i in 0..<total {
      let pixel = img.data[i].to_double()
      let fg_dist = (pixel - fg_mean).abs()
      let bg_dist = (pixel - bg_mean).abs()
      if fg_dist < bg_dist {
        labels[i] = 1
      } else {
        labels[i] = 0
      }
    }
  }

  // 统计
  let mut fg_count = 0
  let mut bg_count = 0
  for i in 0..<total {
    if labels[i] == 1 {
      fg_count += 1
    } else {
      bg_count += 1
    }
  }

  let label_info : Array[SegmentationLabel] = [
    SegmentationLabel::{
      id: 0,
      name: "background",
      color: (0, 0, 0),
      pixel_count: bg_count,
    },
    SegmentationLabel::{
      id: 1,
      name: "foreground",
      color: (255, 255, 255),
      pixel_count: fg_count,
    },
  ]

  SemanticSegmentationResult::{
    width: w,
    height: h,
    labels,
    label_info,
    num_classes: 2,
    inference_time_ms: 0.0,
  }
}

///|
/// 计算分割评估指标
pub fn calculate_segmentation_metrics(
  prediction : Array[Int],
  ground_truth : Array[Int],
  num_classes : Int,
) -> SegmentationMetrics {
  ignore(num_classes)
  let total = prediction.length()
  let mut tp = 0
  let mut fp = 0
  let mut false_neg = 0
  let mut correct = 0

  for i in 0..<total {
    if prediction[i] == ground_truth[i] {
      correct += 1
    }
    if prediction[i] == 1 && ground_truth[i] == 1 {
      tp += 1
    } else if prediction[i] == 1 && ground_truth[i] == 0 {
      fp += 1
    } else if prediction[i] == 0 && ground_truth[i] == 1 {
      false_neg += 1
    }
  }

  let pixel_accuracy = if total > 0 {
    correct.to_double() / total.to_double()
  } else {
    0.0
  }
  let iou = if tp + fp + false_neg > 0 {
    tp.to_double() / (tp + fp + false_neg).to_double()
  } else {
    0.0
  }
  let dice = if 2 * tp + fp + false_neg > 0 {
    (2 * tp).to_double() / (2 * tp + fp + false_neg).to_double()
  } else {
    0.0
  }

  SegmentationMetrics::{
    pixel_accuracy,
    mean_iou: iou,
    mean_accuracy: pixel_accuracy,
    frequency_weighted_iou: iou,
    dice_coefficient: dice,
    true_positives: tp,
    false_positives: fp,
    false_negatives: false_neg,
  }
}

///|
/// 生成分割可视化图像
pub fn segmentation_to_image(
  result : SemanticSegmentationResult,
) -> @types.Image {
  let w = result.width
  let h = result.height
  let out : Array[Byte] = []
  for i in 0..<(w * h) {
    let label = result.labels[i]
    let mut color = 0
    for info in result.label_info {
      if info.id == label {
        color = (info.color.0 + info.color.1 + info.color.2) / 3
      }
    }
    out.push(if color > 127 { b'\xFF' } else { b'\x00' })
  }
  @types.Image::{
    width: w,
    height: h,
    channels: 1,
    data: Bytes::from_array(out),
  }
}

///|
/// 生成分割报告
pub fn segmentation_report_to_string(
  result : SemanticSegmentationResult,
  metrics : SegmentationMetrics,
) -> String {
  let mut report = "## 图像分割报告\n\n"
  report = report + "### 分割结果\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report +
    "| 图像尺寸 | " +
    result.width.to_string() +
    "x" +
    result.height.to_string() +
    " |\n"
  report = report + "| 类别数 | " + result.num_classes.to_string() + " |\n"
  report = report +
    "| 推理耗时 | " +
    result.inference_time_ms.to_string() +
    "ms |\n\n"

  report = report + "### 类别统计\n\n"
  report = report + "| ID | 名称 | 颜色(RGB) | 像素数 | 占比 |\n"
  report = report + "|----|------|-----------|--------|------|\n"
  let total = result.width * result.height
  for info in result.label_info {
    let ratio = if total > 0 {
      info.pixel_count.to_double() / total.to_double() * 100.0
    } else {
      0.0
    }
    report = report +
      "| " +
      info.id.to_string() +
      " | " +
      info.name +
      " | " +
      info.color.0.to_string() +
      "," +
      info.color.1.to_string() +
      "," +
      info.color.2.to_string() +
      " | " +
      info.pixel_count.to_string() +
      " | " +
      ratio.to_string() +
      "% |\n"
  }

  report = report + "\n### 评估指标\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report +
    "| Pixel Accuracy | " +
    (metrics.pixel_accuracy * 100.0).to_string() +
    "% |\n"
  report = report +
    "| Mean IoU | " +
    (metrics.mean_iou * 100.0).to_string() +
    "% |\n"
  report = report +
    "| Mean Accuracy | " +
    (metrics.mean_accuracy * 100.0).to_string() +
    "% |\n"
  report = report +
    "| Dice Coefficient | " +
    (metrics.dice_coefficient * 100.0).to_string() +
    "% |\n"
  report = report + "| TP | " + metrics.true_positives.to_string() + " |\n"
  report = report + "| FP | " + metrics.false_positives.to_string() + " |\n"
  report = report + "| FN | " + metrics.false_negatives.to_string() + " |\n"

  report
}
