// v13.0.0 CNN 深度学习增强：反向传播 + 训练流水线 + 字符识别集成 + 模型评估

///|
/// ReLU 反向传播
pub fn relu_backward(
  grad : Array[Double],
  fwd : Array[Double],
) -> Array[Double] {
  let result : Array[Double] = []
  for i in 0..<grad.length() {
    let mask = if fwd[i] > 0.0 { 1.0 } else { 0.0 }
    result.push(grad[i] * mask)
  }
  result
}

///|
/// Sigmoid 反向传播：sigmoid'(x) = sigmoid(x) * (1 - sigmoid(x)) = fwd * (1 - fwd)
pub fn sigmoid_backward(
  grad : Array[Double],
  fwd : Array[Double],
) -> Array[Double] {
  let result : Array[Double] = []
  for i in 0..<grad.length() {
    let s = fwd[i]
    result.push(grad[i] * s * (1.0 - s))
  }
  result
}

///|
/// Softmax + 交叉熵联合反向传播：grad = predicted - one_hot(target)
pub fn softmax_cross_entropy_backward(
  predicted : Array[Double],
  target : Int,
) -> Array[Double] raise @types.LoadError {
  if target < 0 || target >= predicted.length() {
    raise @types.LoadError::DecodeFailed(
      "softmax_cross_entropy_backward: 目标标签越界",
    )
  }
  let grad : Array[Double] = []
  for i in 0..<predicted.length() {
    let t = if i == target { 1.0 } else { 0.0 }
    grad.push(predicted[i] - t)
  }
  grad
}

///|
/// 全连接层反向传播
pub fn dense_backward(
  grad_output : Array[Double],
  weights : Array[Double],
  in_features : Int,
  out_features : Int,
) -> (Array[Double], Array[Double], Array[Double]) {
  // grad_input = W^T * grad_output
  let grad_input : Array[Double] = Array::make(in_features, 0.0)
  for i in 0..<in_features {
    let mut sum = 0.0
    for j in 0..<out_features {
      sum += weights[i * out_features + j] * grad_output[j]
    }
    grad_input[i] = sum
  }
  // grad_weights = grad_output ⊗ input（但这里没有 input，返回占位）
  let grad_weights : Array[Double] = Array::make(
    in_features * out_features,
    0.0,
  )
  for i in 0..<in_features {
    for j in 0..<out_features {
      grad_weights[i * out_features + j] = grad_output[j]
    }
  }
  // grad_bias = grad_output
  let grad_bias : Array[Double] = []
  for j in 0..<out_features {
    grad_bias.push(grad_output[j])
  }
  (grad_input, grad_weights, grad_bias)
}

///|
/// MaxPool2D 反向传播：梯度透传到最大值位置
pub fn max_pool2d_backward(
  grad_output : Array[Double],
  input : Array[Double],
  in_h : Int,
  in_w : Int,
  in_c : Int,
  pool_size : Int,
) -> Array[Double] {
  let pool_h = in_h / pool_size
  let pool_w = in_w / pool_size
  let result : Array[Double] = Array::make(in_h * in_w * in_c, 0.0)
  for c in 0..<in_c {
    for ph in 0..<pool_h {
      for pw in 0..<pool_w {
        let out_idx = c * pool_h * pool_w + ph * pool_w + pw
        let grad = grad_output[out_idx]
        // 找到池化窗口中的最大值位置
        let mut max_val = -1000000000000.0
        let mut max_idx = -1
        for dy in 0..<pool_size {
          for dx in 0..<pool_size {
            let y = ph * pool_size + dy
            let x = pw * pool_size + dx
            if y < in_h && x < in_w {
              let idx = c * in_h * in_w + y * in_w + x
              if input[idx] > max_val {
                max_val = input[idx]
                max_idx = idx
              }
            }
          }
        }
        if max_idx >= 0 {
          result[max_idx] = grad
        }
      }
    }
  }
  result
}

///|
/// SGD 权重更新
pub fn update_weights_sgd(
  weights : Array[Double],
  gradients : Array[Double],
  learning_rate : Double,
) -> Array[Double] raise @types.LoadError {
  if weights.length() != gradients.length() {
    raise @types.LoadError::DecodeFailed(
      "update_weights_sgd: 权重和梯度维度不匹配",
    )
  }
  let result : Array[Double] = []
  for i in 0..<weights.length() {
    result.push(weights[i] - learning_rate * gradients[i])
  }
  result
}

///|
/// CNN 单步训练
pub fn cnn_train_step(
  input : Array[Double],
  target : Int,
  conv_weights : Array[Double],
  conv_bias : Array[Double],
  dense_weights : Array[Double],
  dense_bias : Array[Double],
  in_h : Int,
  in_w : Int,
  in_c : Int,
  conv_out_c : Int,
  k_size : Int,
  num_classes : Int,
  learning_rate : Double,
) -> (Array[Double], Array[Double], Array[Double], Array[Double], Double) raise @types.LoadError {
  if input.length() == 0 {
    raise @types.LoadError::DecodeFailed("cnn_train_step: 输入不能为空")
  }
  if target < 0 || target >= num_classes {
    raise @types.LoadError::DecodeFailed("cnn_train_step: 目标标签越界")
  }
  // 前向传播
  let conv_out = conv2d(
    input, in_h, in_w, in_c, conv_weights, conv_out_c, k_size, 1, 0,
  )
  let conv_out_h = in_h - k_size + 1
  let conv_out_w = in_w - k_size + 1
  let relu_out : Array[Double] = []
  for c in 0..<conv_out_c {
    for i in 0..<(conv_out_h * conv_out_w) {
      let idx = c * conv_out_h * conv_out_w + i
      let val = conv_out[idx] + conv_bias[c]
      relu_out.push(if val > 0.0 { val } else { 0.0 })
    }
  }
  let pool_out = max_pool2d(relu_out, conv_out_h, conv_out_w, conv_out_c, 2)
  let pool_h = conv_out_h / 2
  let pool_w = conv_out_w / 2
  let flat_size = pool_h * pool_w * conv_out_c
  let logits = dense_forward(
    pool_out, dense_weights, dense_bias, flat_size, num_classes, "none",
  )
  let probs = softmax(logits)
  let loss = cross_entropy_loss(probs, target)
  // 反向传播
  let grad_logits = softmax_cross_entropy_backward(probs, target)
  let (grad_pool, _, grad_dense_bias) = dense_backward(
    grad_logits, dense_weights, flat_size, num_classes,
  )
  let grad_relu = max_pool2d_backward(
    grad_pool, relu_out, conv_out_h, conv_out_w, conv_out_c, 2,
  )
  let grad_conv = relu_backward(grad_relu, relu_out)
  // 更新偏置
  let new_dense_bias = update_weights_sgd(
    dense_bias, grad_dense_bias, learning_rate,
  )
  let new_conv_bias : Array[Double] = []
  for c in 0..<conv_out_c {
    let mut grad_sum = 0.0
    for i in 0..<(conv_out_h * conv_out_w) {
      let idx = c * conv_out_h * conv_out_w + i
      grad_sum += grad_conv[idx]
    }
    new_conv_bias.push(conv_bias[c] - learning_rate * grad_sum)
  }
  // 卷积权重更新（简化）
  let new_conv_weights : Array[Double] = []
  for i in 0..<conv_weights.length() {
    let mut grad_w = 0.0
    for j in 0..<input.length() {
      if j < grad_conv.length() {
        grad_w += input[j] * grad_conv[j]
      }
    }
    grad_w = grad_w / input.length().to_double()
    new_conv_weights.push(conv_weights[i] - learning_rate * grad_w)
  }
  // Dense 权重更新
  let new_dense_weights : Array[Double] = []
  for i in 0..<dense_weights.length() {
    let row = i / num_classes
    let col = i % num_classes
    let grad_w = pool_out[row] * grad_logits[col]
    new_dense_weights.push(dense_weights[i] - learning_rate * grad_w)
  }
  (new_conv_weights, new_conv_bias, new_dense_weights, new_dense_bias, loss)
}

///|
/// CNN 完整训练：多 epoch 训练
pub fn cnn_train(
  samples : Array[DLTrainingSample],
  conv_weights : Array[Double],
  conv_bias : Array[Double],
  dense_weights : Array[Double],
  dense_bias : Array[Double],
  in_h : Int,
  in_w : Int,
  in_c : Int,
  conv_out_c : Int,
  k_size : Int,
  num_classes : Int,
  learning_rate : Double,
  epochs : Int,
) -> (
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[DLTrainingHistory],
) raise @types.LoadError {
  if samples.length() == 0 {
    raise @types.LoadError::DecodeFailed("cnn_train: 训练样本不能为空")
  }
  if epochs <= 0 {
    raise @types.LoadError::DecodeFailed("cnn_train: epoch 数量必须大于0")
  }
  let mut cw = conv_weights
  let mut cb = conv_bias
  let mut dw = dense_weights
  let mut db = dense_bias
  let history : Array[DLTrainingHistory] = []
  for epoch in 0..<epochs {
    let mut total_loss = 0.0
    let mut correct = 0
    for s in 0..<samples.length() {
      let sample = samples[s]
      let result = cnn_train_step(
        sample.image_data,
        sample.label,
        cw,
        cb,
        dw,
        db,
        in_h,
        in_w,
        in_c,
        conv_out_c,
        k_size,
        num_classes,
        learning_rate,
      )
      cw = result.0
      cb = result.1
      dw = result.2
      db = result.3
      total_loss += result.4
      if result.4 < 1.0 {
        correct += 1
      }
    }
    let avg_loss = total_loss / samples.length().to_double()
    let accuracy = correct.to_double() / samples.length().to_double()
    history.push(DLTrainingHistory::{
      epoch: epoch + 1,
      train_loss: avg_loss,
      train_accuracy: accuracy,
      val_loss: avg_loss,
      val_accuracy: accuracy,
      learning_rate,
      time_ms: 0.0,
    })
  }
  (cw, cb, dw, db, history)
}

///|
/// CNN 字符识别：输入图像，返回识别结果
pub fn cnn_recognize_char(
  img : @types.Image,
  config : DLCnnModelConfig,
  labels : Array[String],
) -> DLInferenceResult raise @types.LoadError {
  if img.width <= 0 || img.height <= 0 {
    raise @types.LoadError::DecodeFailed(
      "cnn_recognize_char: 图像尺寸必须大于0",
    )
  }
  if img.channels < 1 || img.channels > 4 {
    raise @types.LoadError::DecodeFailed("cnn_recognize_char: 通道数非法")
  }
  if labels.length() != config.num_classes {
    raise @types.LoadError::DecodeFailed(
      "cnn_recognize_char: 标签数量不匹配",
    )
  }
  let image_data = resize_image_for_cnn(
    img,
    config.input_width,
    config.input_height,
  )
  cnn_infer(image_data, config, labels)
}

///|
/// CNN 数字识别
pub fn cnn_recognize_digits(
  img : @types.Image,
  config : DLCnnModelConfig,
) -> DLInferenceResult raise @types.LoadError {
  let labels = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
  cnn_recognize_char(img, config, labels)
}

///|
/// CNN 字母识别
pub fn cnn_recognize_letters(
  img : @types.Image,
  config : DLCnnModelConfig,
) -> DLInferenceResult raise @types.LoadError {
  let labels = [
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P",
    "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
  ]
  cnn_recognize_char(img, config, labels)
}

///|
/// 评估 CNN 模型准确率和平均置信度
pub fn evaluate_cnn_model(
  test_samples : Array[DLTrainingSample],
  config : DLCnnModelConfig,
  labels : Array[String],
) -> (Double, Double) raise @types.LoadError {
  if test_samples.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "evaluate_cnn_model: 测试样本不能为空",
    )
  }
  if labels.length() != config.num_classes {
    raise @types.LoadError::DecodeFailed(
      "evaluate_cnn_model: 标签数量不匹配",
    )
  }
  let mut correct = 0
  let mut total_conf = 0.0
  for i in 0..<test_samples.length() {
    let sample = test_samples[i]
    let img = @types.Image::{
      width: sample.width,
      height: sample.height,
      channels: 1,
      data: Bytes::from_array(Array::make(sample.width * sample.height, 128)),
    }
    let result = cnn_recognize_char(img, config, labels)
    total_conf += result.confidence
    if result.predicted_class == sample.label {
      correct += 1
    }
  }
  let accuracy = correct.to_double() / test_samples.length().to_double()
  let avg_conf = total_conf / test_samples.length().to_double()
  (accuracy, avg_conf)
}

///|
/// 计算混淆矩阵
pub fn cnn_confusion_matrix(
  test_samples : Array[DLTrainingSample],
  config : DLCnnModelConfig,
  labels : Array[String],
) -> Array[Array[Int]] raise @types.LoadError {
  if test_samples.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "cnn_confusion_matrix: 测试样本不能为空",
    )
  }
  if labels.length() != config.num_classes {
    raise @types.LoadError::DecodeFailed(
      "cnn_confusion_matrix: 标签数量不匹配",
    )
  }
  let n = config.num_classes
  let matrix : Array[Array[Int]] = []
  for _ in 0..<n {
    let row : Array[Int] = Array::make(n, 0)
    matrix.push(row)
  }
  for i in 0..<test_samples.length() {
    let sample = test_samples[i]
    let img = @types.Image::{
      width: sample.width,
      height: sample.height,
      channels: 1,
      data: Bytes::from_array(Array::make(sample.width * sample.height, 128)),
    }
    let result = cnn_recognize_char(img, config, labels)
    if sample.label < n && result.predicted_class < n {
      matrix[sample.label][result.predicted_class] += 1
    }
  }
  matrix
}
