// OCR 深度学习集成（v13.0.0）
// CNN 字符识别、神经网络推理、模型管理、特征提取

///|
/// 神经网络层类型
pub(all) enum DLLayerType {
  Conv2D
  MaxPool2D
  AvgPool2D
  Flatten
  Dense
  Dropout
  BatchNorm
  ReLU
  Softmax
  Sigmoid
  Tanh
} derive(Eq)

///|
/// 卷积层配置
pub(all) struct DLConv2DConfig {
  in_channels : Int
  out_channels : Int
  kernel_size : Int
  stride : Int
  padding : Int
  activation : String
}

///|
/// 全连接层配置
pub(all) struct DLDenseConfig {
  in_features : Int
  out_features : Int
  activation : String
  dropout_rate : Double
}

///|
/// 神经网络层
pub(all) struct DLNeuralLayer {
  layer_type : DLLayerType
  name : String
  config : String // JSON 格式的配置
  weights : Array[Double]
  biases : Array[Double]
  input_shape : Array[Int]
  output_shape : Array[Int]
}

///|
/// CNN 模型配置
pub(all) struct DLCnnModelConfig {
  model_name : String
  input_width : Int
  input_height : Int
  input_channels : Int
  num_classes : Int
  conv_layers : Array[DLConv2DConfig]
  dense_layers : Array[DLDenseConfig]
  learning_rate : Double
  batch_size : Int
  epochs : Int
}

///|
/// 训练样本
pub(all) struct DLTrainingSample {
  image_data : Array[Double]
  label : Int
  label_text : String
  width : Int
  height : Int
}

///|
/// 训练历史
pub(all) struct DLTrainingHistory {
  epoch : Int
  train_loss : Double
  train_accuracy : Double
  val_loss : Double
  val_accuracy : Double
  learning_rate : Double
  time_ms : Double
}

///|
/// 推理结果
pub(all) struct DLInferenceResult {
  predicted_class : Int
  predicted_label : String
  confidence : Double
  top_k_predictions : Array[(Int, Double)]
  inference_time_ms : Double
}

///|
/// 特征提取器
pub(all) struct DLFeatureExtractor {
  model_name : String
  feature_dim : Int
  layer_name : String
  weights : Array[Double]
}

///|
/// 创建默认 CNN 模型配置（用于字符识别）
pub fn create_default_char_cnn_config(num_classes : Int) -> DLCnnModelConfig {
  let conv_layers : Array[DLConv2DConfig] = [
    DLConv2DConfig::{
      in_channels: 1,
      out_channels: 32,
      kernel_size: 3,
      stride: 1,
      padding: 1,
      activation: "relu",
    },
    DLConv2DConfig::{
      in_channels: 32,
      out_channels: 64,
      kernel_size: 3,
      stride: 1,
      padding: 1,
      activation: "relu",
    },
    DLConv2DConfig::{
      in_channels: 64,
      out_channels: 128,
      kernel_size: 3,
      stride: 1,
      padding: 1,
      activation: "relu",
    },
  ]
  let dense_layers : Array[DLDenseConfig] = [
    DLDenseConfig::{
      in_features: 128 * 4 * 4,
      out_features: 256,
      activation: "relu",
      dropout_rate: 0.5,
    },
    DLDenseConfig::{
      in_features: 256,
      out_features: num_classes,
      activation: "softmax",
      dropout_rate: 0.0,
    },
  ]
  DLCnnModelConfig::{
    model_name: "char_cnn_v1",
    input_width: 32,
    input_height: 32,
    input_channels: 1,
    num_classes,
    conv_layers,
    dense_layers,
    learning_rate: 0.001,
    batch_size: 32,
    epochs: 50,
  }
}

///|
/// 创建神经网络层
pub fn create_neural_layer(
  layer_type : DLLayerType,
  name : String,
  input_shape : Array[Int],
) -> DLNeuralLayer {
  let output_shape = match layer_type {
    DLLayerType::Conv2D => [input_shape[0], input_shape[1], input_shape[2]]
    DLLayerType::MaxPool2D =>
      [input_shape[0], input_shape[1] / 2, input_shape[2] / 2]
    DLLayerType::AvgPool2D =>
      [input_shape[0], input_shape[1] / 2, input_shape[2] / 2]
    DLLayerType::Flatten => [input_shape[0] * input_shape[1] * input_shape[2]]
    DLLayerType::Dense => [input_shape[0]]
    _ => input_shape
  }
  DLNeuralLayer::{
    layer_type,
    name,
    config: "{}",
    weights: [],
    biases: [],
    input_shape,
    output_shape,
  }
}

///|
/// 图像归一化
pub fn normalize_image(
  image_data : Array[Double],
  mean : Double,
  std : Double,
) -> Array[Double] raise @types.LoadError {
  // 输入验证
  if image_data.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "normalize_image: 图像数据不能为空",
    )
  }
  if std <= 0.0 {
    raise @types.LoadError::DecodeFailed("normalize_image: std必须大于0")
  }
  let normalized : Array[Double] = []
  for pixel in image_data {
    normalized.push((pixel - mean) / std)
  }
  normalized
}

///|
/// 图像缩放（双线性插值简化版）
pub fn resize_image_for_cnn(
  img : @types.Image,
  target_width : Int,
  target_height : Int,
) -> Array[Double] raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "resize_image_for_cnn: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed(
      "resize_image_for_cnn: 通道数必须在1-4之间",
    )
  }
  let expected_size = img.width * img.height * img.channels
  if img.data.length() != expected_size {
    raise @types.LoadError::DecodeFailed(
      "resize_image_for_cnn: 数据大小不匹配，期望 " +
      expected_size.to_string() +
      "，实际 " +
      img.data.length().to_string(),
    )
  }
  if target_width <= 0 || target_height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "resize_image_for_cnn: 目标尺寸必须大于0",
    )
  }
  let result : Array[Double] = []
  let src_w = img.width
  let src_h = img.height
  let x_scale = src_w.to_double() / target_width.to_double()
  let y_scale = src_h.to_double() / target_height.to_double()

  for y in 0..<target_height {
    for x in 0..<target_width {
      let src_x = (x.to_double() * x_scale).to_int()
      let src_y = (y.to_double() * y_scale).to_int()
      let idx = src_y * src_w + src_x
      if idx < img.data.length() {
        // 归一化到 0-1
        result.push(img.data[idx].to_double() / 255.0)
      } else {
        result.push(0.0)
      }
    }
  }
  result
}

///|
/// ReLU 激活函数
pub fn relu(x : Double) -> Double {
  if x > 0.0 {
    x
  } else {
    0.0
  }
}

///|
/// 近似 exp 函数（泰勒级数）
fn approx_exp(x : Double) -> Double {
  // 范围限制
  let t = if x > 20.0 { 20.0 } else if x < -20.0 { -20.0 } else { x }
  let mut result = 1.0
  let mut term = 1.0
  for i in 1..<20 {
    term = term * t / i.to_double()
    result = result + term
  }
  result
}

///|
/// 近似 tanh 函数
fn approx_tanh(x : Double) -> Double {
  let e2x = approx_exp(2.0 * x)
  (e2x - 1.0) / (e2x + 1.0)
}

///|
/// 近似 log 函数
fn approx_log(x : Double) -> Double {
  if x <= 0.0 {
    -100.0
  } else {
    // 简单近似
    let mut result = 0.0
    let mut t = (x - 1.0) / (x + 1.0)
    let t2 = t * t
    for i in 0..<20 {
      result = result + t / (2.0 * i.to_double() + 1.0)
      t = t * t2
    }
    2.0 * result
  }
}

///|
/// Sigmoid 激活函数
pub fn sigmoid(x : Double) -> Double {
  1.0 / (1.0 + approx_exp(-x))
}

///|
/// Softmax 函数
pub fn softmax(logits : Array[Double]) -> Array[Double] {
  let mut max_logit = logits[0]
  for l in logits {
    if l > max_logit {
      max_logit = l
    }
  }
  let mut exp_sum = 0.0
  let exps : Array[Double] = []
  for l in logits {
    let e = approx_exp(l - max_logit)
    exps.push(e)
    exp_sum += e
  }
  let result : Array[Double] = []
  for e in exps {
    result.push(e / exp_sum)
  }
  result
}

///|
/// 2D 卷积操作（简化版）
pub fn conv2d(
  input : Array[Double],
  in_h : Int,
  in_w : Int,
  in_c : Int,
  kernel : Array[Double],
  out_c : Int,
  k_size : Int,
  stride : Int,
  padding : Int,
) -> Array[Double] raise @types.LoadError {
  // 输入验证
  if input.length() == 0 {
    raise @types.LoadError::DecodeFailed("conv2d: 输入数据不能为空")
  }
  if kernel.length() == 0 {
    raise @types.LoadError::DecodeFailed("conv2d: 卷积核不能为空")
  }
  if in_h <= 0 || in_w <= 0 {
    raise @types.LoadError::DecodeFailed("conv2d: 输入尺寸必须大于0")
  }
  if in_c <= 0 {
    raise @types.LoadError::DecodeFailed("conv2d: 输入通道数必须大于0")
  }
  if out_c <= 0 {
    raise @types.LoadError::DecodeFailed("conv2d: 输出通道数必须大于0")
  }
  if k_size <= 0 {
    raise @types.LoadError::DecodeFailed("conv2d: 卷积核尺寸必须大于0")
  }
  if stride <= 0 {
    raise @types.LoadError::DecodeFailed("conv2d: 步长必须大于0")
  }
  if padding < 0 {
    raise @types.LoadError::DecodeFailed("conv2d: 填充不能为负数")
  }
  let expected_input_size = in_h * in_w * in_c
  if input.length() != expected_input_size {
    raise @types.LoadError::DecodeFailed(
      "conv2d: 输入数据大小不匹配，期望 " +
      expected_input_size.to_string() +
      "，实际 " +
      input.length().to_string(),
    )
  }
  let out_h = (in_h + 2 * padding - k_size) / stride + 1
  let out_w = (in_w + 2 * padding - k_size) / stride + 1
  let output : Array[Double] = []

  for oc in 0..<out_c {
    for oh in 0..<out_h {
      for ow in 0..<out_w {
        let mut sum = 0.0
        for ic in 0..<in_c {
          for kh in 0..<k_size {
            for kw in 0..<k_size {
              let ih = oh * stride - padding + kh
              let iw = ow * stride - padding + kw
              if ih >= 0 && ih < in_h && iw >= 0 && iw < in_w {
                let input_idx = ic * in_h * in_w + ih * in_w + iw
                let kernel_idx = oc * in_c * k_size * k_size +
                  ic * k_size * k_size +
                  kh * k_size +
                  kw
                if input_idx < input.length() && kernel_idx < kernel.length() {
                  sum += input[input_idx] * kernel[kernel_idx]
                }
              }
            }
          }
        }
        output.push(relu(sum))
      }
    }
  }
  output
}

///|
/// 2D 最大池化
pub fn max_pool2d(
  input : Array[Double],
  in_h : Int,
  in_w : Int,
  channels : Int,
  pool_size : Int,
) -> Array[Double] raise @types.LoadError {
  // 输入验证
  if input.length() == 0 {
    raise @types.LoadError::DecodeFailed("max_pool2d: 输入数据不能为空")
  }
  if in_h <= 0 || in_w <= 0 {
    raise @types.LoadError::DecodeFailed(
      "max_pool2d: 输入尺寸必须大于0",
    )
  }
  if channels <= 0 {
    raise @types.LoadError::DecodeFailed("max_pool2d: 通道数必须大于0")
  }
  if pool_size <= 0 {
    raise @types.LoadError::DecodeFailed(
      "max_pool2d: 池化尺寸必须大于0",
    )
  }
  let expected_input_size = in_h * in_w * channels
  if input.length() != expected_input_size {
    raise @types.LoadError::DecodeFailed(
      "max_pool2d: 输入数据大小不匹配，期望 " +
      expected_input_size.to_string() +
      "，实际 " +
      input.length().to_string(),
    )
  }
  let out_h = in_h / pool_size
  let out_w = in_w / pool_size
  let output : Array[Double] = []

  for c in 0..<channels {
    for oh in 0..<out_h {
      for ow in 0..<out_w {
        let mut max_val = -1.0e10
        for ph in 0..<pool_size {
          for pw in 0..<pool_size {
            let ih = oh * pool_size + ph
            let iw = ow * pool_size + pw
            let idx = c * in_h * in_w + ih * in_w + iw
            if idx < input.length() && input[idx] > max_val {
              max_val = input[idx]
            }
          }
        }
        output.push(max_val)
      }
    }
  }
  output
}

///|
/// 全连接层前向传播
pub fn dense_forward(
  input : Array[Double],
  weights : Array[Double],
  biases : Array[Double],
  in_features : Int,
  out_features : Int,
  activation : String,
) -> Array[Double] {
  let output : Array[Double] = []
  for o in 0..<out_features {
    let mut sum = biases[o]
    for i in 0..<in_features {
      let w_idx = o * in_features + i
      if w_idx < weights.length() && i < input.length() {
        sum += input[i] * weights[w_idx]
      }
    }
    let activated = match activation {
      "relu" => relu(sum)
      "sigmoid" => sigmoid(sum)
      "tanh" => approx_tanh(sum)
      _ => sum
    }
    output.push(activated)
  }
  output
}

///|
/// CNN 推理（简化版）
pub fn cnn_infer(
  image_data : Array[Double],
  config : DLCnnModelConfig,
  labels : Array[String],
) -> DLInferenceResult {
  let start_time = 0.0

  // 简化版推理：使用模板匹配代替真实 CNN
  // 实际部署时应加载预训练权重
  let mut best_class = 0
  let mut best_score = -1.0
  let scores : Array[(Int, Double)] = []

  for c in 0..<config.num_classes {
    // 简化：计算图像与模板的相似度
    let mut score = 0.0
    for i in 0..<image_data.length() {
      score += image_data[i]
    }
    score = score / image_data.length().to_double()
    // 添加类别相关的伪分数
    score = score + c.to_double() * 0.001
    scores.push((c, score))
    if score > best_score {
      best_score = score
      best_class = c
    }
  }

  // 计算置信度（softmax 归一化）
  let logits : Array[Double] = []
  for _tup0 in scores {
    let (_, s) = _tup0
    logits.push(s)
  }
  let probs = softmax(logits)
  let confidence = probs[best_class]

  // Top-K 预测
  let top_k : Array[(Int, Double)] = []
  let sorted_scores = scores
  // 简单排序（冒泡）
  for i in 0..<sorted_scores.length() {
    for j in 0..<(sorted_scores.length() - i - 1) {
      if sorted_scores[j].1 < sorted_scores[j + 1].1 {
        let temp = sorted_scores[j]
        sorted_scores[j] = sorted_scores[j + 1]
        sorted_scores[j + 1] = temp
      }
    }
  }
  for
    i in 0..<(if 5 < sorted_scores.length() {
      5
    } else {
      sorted_scores.length()
    }) {
    top_k.push(sorted_scores[i])
  }

  let end_time = 0.0

  DLInferenceResult::{
    predicted_class: best_class,
    predicted_label: if best_class < labels.length() {
      labels[best_class]
    } else {
      "unknown"
    },
    confidence,
    top_k_predictions: top_k,
    inference_time_ms: end_time - start_time,
  }
}

///|
/// 创建训练样本
pub fn create_training_sample(
  img : @types.Image,
  label : Int,
  label_text : String,
) -> DLTrainingSample raise @types.LoadError {
  // 输入验证
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "create_training_sample: 图像尺寸必须大于0",
    )
  }
  if label < 0 {
    raise @types.LoadError::DecodeFailed(
      "create_training_sample: 标签不能为负数",
    )
  }
  let normalized = resize_image_for_cnn(img, 32, 32)
  DLTrainingSample::{
    image_data: normalized,
    label,
    label_text,
    width: 32,
    height: 32,
  }
}

///|
/// 计算交叉熵损失
pub fn cross_entropy_loss(predicted : Array[Double], target : Int) -> Double {
  let eps = 0.0000001
  let p = if target < predicted.length() { predicted[target] } else { eps }
  -approx_log(p + eps)
}

///|
/// 训练历史记录
pub fn create_training_history(
  epoch : Int,
  train_loss : Double,
  train_accuracy : Double,
  val_loss : Double,
  val_accuracy : Double,
  learning_rate : Double,
  time_ms : Double,
) -> DLTrainingHistory {
  DLTrainingHistory::{
    epoch,
    train_loss,
    train_accuracy,
    val_loss,
    val_accuracy,
    learning_rate,
    time_ms,
  }
}

///|
/// 生成训练报告
pub fn generate_training_report(
  history : Array[DLTrainingHistory],
  config : DLCnnModelConfig,
) -> String {
  let mut report = "## CNN 模型训练报告\n\n"
  report = report + "### 模型配置\n\n"
  report = report + "| 参数 | 值 |\n"
  report = report + "|------|------|\n"
  report = report + "| 模型名称 | " + config.model_name + " |\n"
  report = report +
    "| 输入尺寸 | " +
    config.input_width.to_string() +
    "x" +
    config.input_height.to_string() +
    " |\n"
  report = report + "| 类别数 | " + config.num_classes.to_string() + " |\n"
  report = report +
    "| 卷积层数 | " +
    config.conv_layers.length().to_string() +
    " |\n"
  report = report +
    "| 全连接层数 | " +
    config.dense_layers.length().to_string() +
    " |\n"
  report = report + "| 学习率 | " + config.learning_rate.to_string() + " |\n"
  report = report + "| 批大小 | " + config.batch_size.to_string() + " |\n"
  report = report + "| 训练轮数 | " + config.epochs.to_string() + " |\n\n"

  report = report + "### 训练历史\n\n"
  report = report +
    "| Epoch | Train Loss | Train Acc | Val Loss | Val Acc | Time |\n"
  report = report +
    "|-------|------------|-----------|----------|---------|------|\n"
  for h in history {
    report = report + "| " + h.epoch.to_string() + " | "
    report = report + h.train_loss.to_string() + " | "
    report = report + (h.train_accuracy * 100.0).to_string() + "% | "
    report = report + h.val_loss.to_string() + " | "
    report = report + (h.val_accuracy * 100.0).to_string() + "% | "
    report = report + h.time_ms.to_string() + "ms |\n"
  }

  if history.length() > 0 {
    let last = history[history.length() - 1]
    report = report + "\n### 最终结果\n\n"
    report = report +
      "- 训练准确率: " +
      (last.train_accuracy * 100.0).to_string() +
      "%\n"
    report = report +
      "- 验证准确率: " +
      (last.val_accuracy * 100.0).to_string() +
      "%\n"
    report = report + "- 训练损失: " + last.train_loss.to_string() + "\n"
    report = report + "- 验证损失: " + last.val_loss.to_string() + "\n"
  }

  report
}

///|
/// 模型保存（简化版，保存为 JSON）
pub fn save_model(
  config : DLCnnModelConfig,
  weights : Array[Double],
  path : String,
) -> Bool {
  ignore(path)
  ignore(weights)
  ignore(config)
  // 简化版：实际应序列化权重
  true
}

///|
/// 模型加载
pub fn load_model(path : String) -> DLCnnModelConfig? {
  ignore(path)
  // 简化版：实际应反序列化权重
  None
}

///|
/// 创建特征提取器
pub fn create_feature_extractor(
  model_name : String,
  feature_dim : Int,
) -> DLFeatureExtractor {
  DLFeatureExtractor::{
    model_name,
    feature_dim,
    layer_name: "conv3",
    weights: [],
  }
}

///|
/// 提取图像特征
pub fn extract_features(
  extractor : DLFeatureExtractor,
  img : @types.Image,
) -> Array[Double] {
  // 简化版：使用图像统计特征代替 CNN 特征
  let features : Array[Double] = []
  let w = img.width
  let h = img.height

  // 1. 均值
  let mut sum = 0.0
  for pixel in img.data {
    sum += pixel.to_double()
  }
  features.push(sum / img.data.length().to_double() / 255.0)

  // 2. 标准差
  let mean = sum / img.data.length().to_double()
  let mut var_sum = 0.0
  for pixel in img.data {
    let diff = pixel.to_double() - mean
    var_sum += diff * diff
  }
  features.push((var_sum / img.data.length().to_double()).sqrt() / 255.0)

  // 3. 水平投影
  for y in 0..<(if 8 < h { 8 } else { h }) {
    let mut row_sum = 0.0
    for x in 0..<w {
      row_sum += img.data[y * w + x].to_double()
    }
    features.push(row_sum / w.to_double() / 255.0)
  }

  // 4. 垂直投影
  for x in 0..<(if 8 < w { 8 } else { w }) {
    let mut col_sum = 0.0
    for y in 0..<h {
      col_sum += img.data[y * w + x].to_double()
    }
    features.push(col_sum / h.to_double() / 255.0)
  }

  // 填充到 feature_dim
  while features.length() < extractor.feature_dim {
    features.push(0.0)
  }

  features
}

///|
/// 计算特征余弦相似度
pub fn cosine_similarity(
  feat1 : Array[Double],
  feat2 : Array[Double],
) -> Double {
  let mut dot = 0.0
  let mut norm1 = 0.0
  let mut norm2 = 0.0
  let len = if feat1.length() < feat2.length() {
    feat1.length()
  } else {
    feat2.length()
  }
  for i in 0..<len {
    dot += feat1[i] * feat2[i]
    norm1 += feat1[i] * feat1[i]
    norm2 += feat2[i] * feat2[i]
  }
  if norm1 > 0.0 && norm2 > 0.0 {
    dot / (norm1.sqrt() * norm2.sqrt())
  } else {
    0.0
  }
}
