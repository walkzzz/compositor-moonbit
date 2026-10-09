// 可解释AI与模型可视化（v41.0.0）
// LIME、SHAP、Grad-CAM、特征可视化、模型分析

///|
/// 可解释AI方法类型
pub(all) enum ExplainabilityMethod {
  LIME
  SHAP
  GradCAM
  IntegratedGradients
  SaliencyMap
  OcclusionSensitivity
  FeatureVisualization
  ActivationMaximization
  ConceptActivationVectors
  Unknown
} derive(Eq)

///|
/// 模型可视化类型
pub(all) enum ModelVisualizationType {
  FeatureMap
  Filter
  Activation
  Embedding
  ConfusionMatrix
  ROCCurve
  PRCurve
  LossCurve
  AccuracyCurve
  Unknown
} derive(Eq)

///|
/// 特征重要性结果
pub(all) struct FeatureImportanceResult {
  feature_names : Array[String]
  importance_scores : Array[Double]
  num_features : Int
  method_type : ExplainabilityMethod
  top_features : Array[String]
  top_scores : Array[Double]
}

///|
/// 显著性图结果
pub(all) struct SaliencyMapResult {
  saliency_map : @types.Image
  method_type : ExplainabilityMethod
  target_class : String
  confidence : Double
  num_iterations : Int
}

///|
/// 混淆矩阵
pub(all) struct ConfusionMatrix {
  matrix : Array[Array[Int]]
  num_classes : Int
  class_names : Array[String]
  accuracy : Double
  precision : Array[Double]
  recall : Array[Double]
  f1_scores : Array[Double]
}

///|
/// ROC曲线数据
pub(all) struct ROCCurveData {
  fpr : Array[Double]
  tpr : Array[Double]
  thresholds : Array[Double]
  auc : Double
  num_points : Int
}

///|
/// 模型性能指标
pub(all) struct ModelPerformanceMetrics {
  accuracy : Double
  precision : Double
  recall : Double
  f1_score : Double
  auc_roc : Double
  auc_pr : Double
  loss : Double
  inference_time_ms : Double
  memory_mb : Double
  model_size_mb : Double
  num_parameters : Int
  flops : Int
}

///|
/// 特征图可视化结果
pub(all) struct FeatureMapVisualization {
  feature_maps : Array[@types.Image]
  num_maps : Int
  layer_name : String
  map_size : Int
  num_channels : Int
}

///|
/// 嵌入可视化结果
pub(all) struct EmbeddingVisualization {
  points : Array[Array[Double]]
  labels : Array[Int]
  num_points : Int
  dimensions : Int
  method_type : String
  perplexity : Double
}

///|
/// 可解释AI配置
pub(all) struct ExplainableAIConfig {
  method_type : ExplainabilityMethod
  num_samples : Int
  num_features : Int
  perturbation_scale : Double
  target_class : Int
  use_smoothing : Bool
  smoothing_sigma : Double
  normalize : Bool
}

///|
/// 创建默认可解释AI配置
pub fn create_default_explainable_ai_config() -> ExplainableAIConfig {
  ExplainableAIConfig::{
    method_type: ExplainabilityMethod::GradCAM,
    num_samples: 1000,
    num_features: 10,
    perturbation_scale: 0.1,
    target_class: 0,
    use_smoothing: true,
    smoothing_sigma: 1.0,
    normalize: true,
  }
}

///|
/// 计算特征重要性（简化版）
pub fn compute_feature_importance(
  image : @types.Image,
  config : ExplainableAIConfig,
) -> FeatureImportanceResult raise @types.LoadError {
  // 输入验证
  if image.width <= 0 || image.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "compute_feature_importance: 图像尺寸必须大于0",
    )
  }
  if image.channels < 1 || image.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "compute_feature_importance: 通道数必须在1-4之间",
    )
  }
  let expected_size = image.width * image.height * image.channels
  if image.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "compute_feature_importance: 数据大小不匹配",
    )
  }
  let w = image.width
  let h = image.height
  let _ = w * h

  // 简化的特征重要性：基于区域对比度
  let grid_size = 32
  let num_regions_x = w / grid_size
  let num_regions_y = h / grid_size
  let num_regions = num_regions_x * num_regions_y

  let feature_names : Array[String] = []
  let importance_scores : Array[Double] = []

  for ry in 0..<num_regions_y {
    for rx in 0..<num_regions_x {
      let mut sum = 0.0
      let mut sum_sq = 0.0
      let count = grid_size * grid_size

      for y in 0..<grid_size {
        for x in 0..<grid_size {
          let idx = (ry * grid_size + y) * w + (rx * grid_size + x)
          let v = image.data[idx].to_double()
          sum += v
          sum_sq += v * v
        }
      }

      let mean = sum / count.to_double()
      let variance = sum_sq / count.to_double() - mean * mean
      let std_dev = if variance > 0.0 { variance.sqrt() } else { 0.0 }

      feature_names.push("region_" + rx.to_string() + "_" + ry.to_string())
      importance_scores.push(std_dev)
    }
  }

  // 排序获取Top特征
  let top_features : Array[String] = []
  let top_scores : Array[Double] = []
  let indices : Array[Int] = []
  for i in 0..<num_regions {
    indices.push(i)
  }

  // 简单的选择排序
  for i in 0..<config.num_features {
    if i < num_regions {
      let mut max_idx = i
      let mut max_val = importance_scores[indices[i]]
      for j in (i + 1)..<num_regions {
        if importance_scores[indices[j]] > max_val {
          max_val = importance_scores[indices[j]]
          max_idx = j
        }
      }
      let temp = indices[i]
      indices[i] = indices[max_idx]
      indices[max_idx] = temp
      top_features.push(feature_names[indices[i]])
      top_scores.push(importance_scores[indices[i]])
    }
  }

  FeatureImportanceResult::{
    feature_names,
    importance_scores,
    num_features: num_regions,
    method_type: config.method_type,
    top_features,
    top_scores,
  }
}

///|
/// 生成显著性图（简化版）
pub fn generate_saliency_map(
  image : @types.Image,
  config : ExplainableAIConfig,
) -> SaliencyMapResult raise @types.LoadError {
  // 输入验证
  if image.width <= 0 || image.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "generate_saliency_map: 图像尺寸必须大于0",
    )
  }
  if image.channels < 1 || image.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "generate_saliency_map: 通道数必须在1-4之间",
    )
  }
  let expected_size = image.width * image.height * image.channels
  if image.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "generate_saliency_map: 数据大小不匹配",
    )
  }
  let w = image.width
  let h = image.height
  let _ = w * h
  let out : Array[Byte] = []

  // 简化的显著性图：基于梯度近似
  for y in 0..<h {
    for x in 0..<w {
      let idx = y * w + x

      // 计算局部梯度
      let mut gx = 0.0
      let mut gy = 0.0

      if x > 0 && x < w - 1 {
        gx = image.data[idx + 1].to_double() - image.data[idx - 1].to_double()
      }
      if y > 0 && y < h - 1 {
        gy = image.data[idx + w].to_double() - image.data[idx - w].to_double()
      }

      let gradient_magnitude = (gx * gx + gy * gy).sqrt()
      let normalized = if config.normalize {
        gradient_magnitude / 255.0 * 255.0
      } else {
        gradient_magnitude
      }

      let clamped = if normalized > 255.0 { 255.0 } else { normalized }
      out.push(clamped.to_int().to_byte())
    }
  }

  SaliencyMapResult::{
    saliency_map: @types.Image::{
      width: w,
      height: h,
      channels: 1,
      data: Bytes::from_array(out),
    },
    method_type: config.method_type,
    target_class: "class_" + config.target_class.to_string(),
    confidence: 0.7,
    num_iterations: config.num_samples,
  }
}

///|
/// 生成混淆矩阵（简化版）
pub fn generate_confusion_matrix(
  predictions : Array[Int],
  ground_truth : Array[Int],
  num_classes : Int,
  class_names : Array[String],
) -> ConfusionMatrix {
  let matrix : Array[Array[Int]] = []
  for _ in 0..<num_classes {
    let row : Array[Int] = []
    for _ in 0..<num_classes {
      row.push(0)
    }
    matrix.push(row)
  }

  let mut correct = 0
  let total = if predictions.length() < ground_truth.length() {
    predictions.length()
  } else {
    ground_truth.length()
  }

  for i in 0..<total {
    let pred = predictions[i]
    let gt = ground_truth[i]
    if pred >= 0 && pred < num_classes && gt >= 0 && gt < num_classes {
      matrix[gt][pred] += 1
      if pred == gt {
        correct += 1
      }
    }
  }

  let accuracy = if total > 0 {
    correct.to_double() / total.to_double()
  } else {
    0.0
  }

  // 计算每个类别的精确率、召回率、F1
  let precision : Array[Double] = []
  let recall : Array[Double] = []
  let f1_scores : Array[Double] = []

  for c in 0..<num_classes {
    let mut tp = 0
    let mut fp = 0
    let mut false_neg = 0

    for i in 0..<num_classes {
      if i == c {
        tp = matrix[c][i]
      } else {
        fp += matrix[i][c]
        false_neg += matrix[c][i]
      }
    }

    let p = if tp + fp > 0 {
      tp.to_double() / (tp + fp).to_double()
    } else {
      0.0
    }
    let r = if tp + false_neg > 0 {
      tp.to_double() / (tp + false_neg).to_double()
    } else {
      0.0
    }
    let f1 = if p + r > 0.0 { 2.0 * p * r / (p + r) } else { 0.0 }

    precision.push(p)
    recall.push(r)
    f1_scores.push(f1)
  }

  ConfusionMatrix::{
    matrix,
    num_classes,
    class_names,
    accuracy,
    precision,
    recall,
    f1_scores,
  }
}

///|
/// 生成ROC曲线数据（简化版）
pub fn generate_roc_curve(
  scores : Array[Double],
  labels : Array[Int],
  num_thresholds : Int,
) -> ROCCurveData {
  let fpr : Array[Double] = []
  let tpr : Array[Double] = []
  let thresholds : Array[Double] = []

  let total = if scores.length() < labels.length() {
    scores.length()
  } else {
    labels.length()
  }

  let mut positives = 0
  let mut negatives = 0
  for i in 0..<total {
    if labels[i] == 1 {
      positives += 1
    } else {
      negatives += 1
    }
  }

  for t_idx in 0..<num_thresholds {
    let threshold = t_idx.to_double() / (num_thresholds - 1).to_double()
    thresholds.push(threshold)

    let mut tp = 0
    let mut fp = 0
    let mut tn = 0
    ignore(tn)
    let mut false_neg = 0
    ignore(false_neg)

    for i in 0..<total {
      let predicted = if scores[i] >= threshold { 1 } else { 0 }
      if predicted == 1 && labels[i] == 1 {
        tp += 1
      } else if predicted == 1 && labels[i] == 0 {
        fp += 1
      } else if predicted == 0 && labels[i] == 0 {
        tn += 1
      } else {
        false_neg += 1
      }
    }

    let fpr_val = if negatives > 0 {
      fp.to_double() / negatives.to_double()
    } else {
      0.0
    }
    let tpr_val = if positives > 0 {
      tp.to_double() / positives.to_double()
    } else {
      0.0
    }
    fpr.push(fpr_val)
    tpr.push(tpr_val)
  }

  // 简化的AUC计算（梯形法则）
  let mut auc = 0.0
  for i in 1..<num_thresholds {
    auc += (fpr[i] - fpr[i - 1]) * (tpr[i] + tpr[i - 1]) / 2.0
  }

  ROCCurveData::{ fpr, tpr, thresholds, auc, num_points: num_thresholds }
}

///|
/// 可视化特征图（简化版）
pub fn visualize_feature_maps(
  image : @types.Image,
  num_maps : Int,
  layer_name : String,
) -> FeatureMapVisualization raise @types.LoadError {
  // 输入验证
  if image.width <= 0 || image.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "visualize_feature_maps: 图像尺寸必须大于0",
    )
  }
  if image.channels < 1 || image.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "visualize_feature_maps: 通道数必须在1-4之间",
    )
  }
  let expected_size = image.width * image.height * image.channels
  if image.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "visualize_feature_maps: 数据大小不匹配",
    )
  }
  let w = image.width
  let h = image.height
  let feature_maps : Array[@types.Image] = []

  for map_idx in 0..<num_maps {
    let out : Array[Byte] = []
    let offset = map_idx * 7

    for y in 0..<h {
      for x in 0..<w {
        let idx = y * w + x
        let base = image.data[idx].to_double()
        // 简化的特征图：不同的滤波响应
        let response = if (x + y + offset) % 3 == 0 {
          base * 1.2
        } else if (x + y + offset) % 3 == 1 {
          base * 0.8
        } else {
          base
        }
        let clamped = if response > 255.0 { 255.0 } else { response }
        out.push(clamped.to_int().to_byte())
      }
    }

    feature_maps.push(@types.Image::{
      width: w,
      height: h,
      channels: 1,
      data: Bytes::from_array(out),
    })
  }

  FeatureMapVisualization::{
    feature_maps,
    num_maps,
    layer_name,
    map_size: w,
    num_channels: num_maps,
  }
}

///|
/// 生成可解释AI报告
pub fn explainable_ai_report_to_string(
  importance : FeatureImportanceResult,
  saliency : SaliencyMapResult,
  metrics : ModelPerformanceMetrics,
) -> String {
  let mut report = "## 可解释AI与模型可视化报告\n\n"

  report = report + "### 特征重要性\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report +
    "| 方法 | " +
    (match importance.method_type {
      ExplainabilityMethod::LIME => "LIME"
      ExplainabilityMethod::SHAP => "SHAP"
      ExplainabilityMethod::GradCAM => "Grad-CAM"
      ExplainabilityMethod::IntegratedGradients => "Integrated Gradients"
      ExplainabilityMethod::SaliencyMap => "Saliency Map"
      _ => "未知"
    }) +
    " |\n"
  report = report +
    "| 特征数量 | " +
    importance.num_features.to_string() +
    " |\n"
  report = report +
    "| Top特征数 | " +
    importance.top_features.length().to_string() +
    " |\n\n"

  report = report + "### Top 特征\n\n"
  report = report + "| 排名 | 特征 | 重要性 |\n|------|------|------|\n"
  for i in 0..<importance.top_features.length() {
    report = report +
      "| " +
      (i + 1).to_string() +
      " | " +
      importance.top_features[i] +
      " | " +
      (importance.top_scores[i] * 100.0).to_string() +
      "% |\n"
  }

  report = report + "\n### 显著性图\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report +
    "| 方法 | " +
    (match saliency.method_type {
      ExplainabilityMethod::GradCAM => "Grad-CAM"
      ExplainabilityMethod::SaliencyMap => "Saliency Map"
      _ => "未知"
    }) +
    " |\n"
  report = report + "| 目标类别 | " + saliency.target_class + " |\n"
  report = report +
    "| 置信度 | " +
    (saliency.confidence * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 迭代次数 | " +
    saliency.num_iterations.to_string() +
    " |\n"

  report = report + "\n### 模型性能\n\n"
  report = report + "| 指标 | 值 |\n|------|------|\n"
  report = report +
    "| 准确率 | " +
    (metrics.accuracy * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 精确率 | " +
    (metrics.precision * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 召回率 | " +
    (metrics.recall * 100.0).to_string() +
    "% |\n"
  report = report +
    "| F1分数 | " +
    (metrics.f1_score * 100.0).to_string() +
    "% |\n"
  report = report + "| AUC-ROC | " + metrics.auc_roc.to_string() + " |\n"
  report = report +
    "| 推理时间 | " +
    metrics.inference_time_ms.to_string() +
    " ms |\n"
  report = report +
    "| 内存占用 | " +
    metrics.memory_mb.to_string() +
    " MB |\n"
  report = report +
    "| 模型大小 | " +
    metrics.model_size_mb.to_string() +
    " MB |\n"
  report = report +
    "| 参数数量 | " +
    metrics.num_parameters.to_string() +
    " |\n"

  report
}
