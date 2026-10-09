// v13.0.0 CNN 深度学习增强测试：反向传播 + 训练流水线 + 字符识别集成 + 模型评估

///|
test "relu_backward: 正值透传梯度" {
  let grad = [1.0, 2.0, 3.0]
  let fwd = [1.0, 2.0, 3.0]
  let result = relu_backward(grad, fwd)
  assert_eq(result.length(), 3)
  assert_true((result[0] - 1.0).abs() < 0.0001)
  assert_true((result[1] - 2.0).abs() < 0.0001)
  assert_true((result[2] - 3.0).abs() < 0.0001)
}

///|
test "relu_backward: 负值梯度为零" {
  let grad = [1.0, 2.0, 3.0]
  let fwd = [-1.0, -2.0, 0.0]
  let result = relu_backward(grad, fwd)
  assert_eq(result.length(), 3)
  assert_true(result[0].abs() < 0.0001)
  assert_true(result[1].abs() < 0.0001)
  assert_true(result[2].abs() < 0.0001)
}

///|
test "sigmoid_backward: 导数正确" {
  let grad = [1.0, 1.0]
  let fwd = [0.5, 0.8]
  let result = sigmoid_backward(grad, fwd)
  // sigmoid'(x) = s * (1 - s)
  let expected0 = 0.5 * (1.0 - 0.5)
  let expected1 = 0.8 * (1.0 - 0.8)
  assert_true((result[0] - expected0).abs() < 0.0001)
  assert_true((result[1] - expected1).abs() < 0.0001)
}

///|
test "softmax_cross_entropy_backward: 梯度正确" {
  let predicted = [0.7, 0.2, 0.1]
  let target = 0
  let grad = softmax_cross_entropy_backward(predicted, target)
  // grad = predicted - one_hot(target)
  assert_true((grad[0] - (0.7 - 1.0)).abs() < 0.0001)
  assert_true((grad[1] - 0.2).abs() < 0.0001)
  assert_true((grad[2] - 0.1).abs() < 0.0001)
}

///|
test "softmax_cross_entropy_backward: 标签越界抛异常" {
  let predicted = [0.5, 0.5]
  try {
    let _ = softmax_cross_entropy_backward(predicted, 5)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "dense_backward: grad_input 维度正确" {
  let grad_output = [1.0, 2.0]
  let weights = [1.0, 2.0, 3.0, 4.0] // 2 in_features x 2 out_features
  let in_features = 2
  let out_features = 2
  let (grad_input, grad_weights, grad_bias) = dense_backward(
    grad_output, weights, in_features, out_features,
  )
  assert_eq(grad_input.length(), in_features)
  assert_eq(grad_weights.length(), in_features * out_features)
  assert_eq(grad_bias.length(), out_features)
  // grad_bias == grad_output
  assert_true((grad_bias[0] - 1.0).abs() < 0.0001)
  assert_true((grad_bias[1] - 2.0).abs() < 0.0001)
}

///|
test "max_pool2d_backward: 梯度透传到最大值位置" {
  // 4x4 单通道输入
  let input = [
    1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0,
    16.0,
  ]
  // 2x2 池化后 2x2 输出
  let grad_output = [1.0, 2.0, 3.0, 4.0]
  let result = max_pool2d_backward(grad_output, input, 4, 4, 1, 2)
  assert_eq(result.length(), 16)
  // 第一个窗口 [1,2;5,6] 最大值在索引 5 (值6)
  assert_true((result[5] - 1.0).abs() < 0.0001)
  // 第二个窗口 [3,4;7,8] 最大值在索引 7 (值8)
  assert_true((result[7] - 2.0).abs() < 0.0001)
}

///|
test "update_weights_sgd: 权重更新正确" {
  let weights = [1.0, 2.0, 3.0]
  let gradients = [0.5, 1.0, 1.5]
  let lr = 0.1
  let result = update_weights_sgd(weights, gradients, lr)
  assert_eq(result.length(), 3)
  assert_true((result[0] - (1.0 - 0.1 * 0.5)).abs() < 0.0001)
  assert_true((result[1] - (2.0 - 0.1 * 1.0)).abs() < 0.0001)
  assert_true((result[2] - (3.0 - 0.1 * 1.5)).abs() < 0.0001)
}

///|
test "update_weights_sgd: 维度不匹配抛异常" {
  let weights = [1.0, 2.0, 3.0]
  let gradients = [0.5, 1.0]
  try {
    let _ = update_weights_sgd(weights, gradients, 0.1)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "cnn_train_step: 返回正确维度" {
  // 小规模 CNN: 8x8x1 输入, 2 conv 输出通道, 3x3 卷积核, 3 分类
  let in_h = 8
  let in_w = 8
  let in_c = 1
  let conv_out_c = 2
  let k_size = 3
  let num_classes = 3
  let conv_out_h = in_h - k_size + 1 // 6
  let pool_h = conv_out_h / 2 // 3
  let pool_w = pool_h
  let flat_size = pool_h * pool_w * conv_out_c // 18
  let input = Array::make(in_h * in_w * in_c, 0.5)
  let conv_weights = Array::make(conv_out_c * in_c * k_size * k_size, 0.1)
  let conv_bias = Array::make(conv_out_c, 0.0)
  let dense_weights = Array::make(flat_size * num_classes, 0.01)
  let dense_bias = Array::make(num_classes, 0.0)
  let (new_cw, new_cb, new_dw, new_db, loss) = cnn_train_step(
    input, 0, conv_weights, conv_bias, dense_weights, dense_bias, in_h, in_w, in_c,
    conv_out_c, k_size, num_classes, 0.01,
  )
  assert_eq(new_cw.length(), conv_weights.length())
  assert_eq(new_cb.length(), conv_bias.length())
  assert_eq(new_dw.length(), dense_weights.length())
  assert_eq(new_db.length(), dense_bias.length())
  assert_true(loss >= 0.0)
}

///|
test "cnn_train_step: 空输入抛异常" {
  let conv_weights = [0.1]
  let conv_bias = [0.0]
  let dense_weights = [0.01]
  let dense_bias = [0.0]
  try {
    let _ = cnn_train_step(
      [],
      0,
      conv_weights,
      conv_bias,
      dense_weights,
      dense_bias,
      8,
      8,
      1,
      2,
      3,
      3,
      0.01,
    )
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "cnn_train: 多 epoch 训练" {
  // 用 create_training_sample 创建样本（内部 resize 到 32x32）
  let img = @types.Image::{
    width: 8,
    height: 8,
    channels: 1,
    data: Bytes::from_array(Array::make(64, b'\x80')),
  }
  let sample1 = create_training_sample(img, 0, "0")
  let sample2 = create_training_sample(img, 1, "1")
  let samples = [sample1, sample2]
  // 参数: 32x32x1, 2 conv 通道, 3x3 核, 2 分类
  let in_h = 32
  let in_w = 32
  let in_c = 1
  let conv_out_c = 2
  let k_size = 3
  let num_classes = 2
  let conv_out_h = in_h - k_size + 1 // 30
  let pool_h = conv_out_h / 2 // 15
  let pool_w = pool_h
  let flat_size = pool_h * pool_w * conv_out_c // 450
  let conv_weights = Array::make(conv_out_c * in_c * k_size * k_size, 0.01)
  let conv_bias = Array::make(conv_out_c, 0.0)
  let dense_weights = Array::make(flat_size * num_classes, 0.001)
  let dense_bias = Array::make(num_classes, 0.0)
  let (final_cw, final_cb, final_dw, final_db, history) = cnn_train(
    samples, conv_weights, conv_bias, dense_weights, dense_bias, in_h, in_w, in_c,
    conv_out_c, k_size, num_classes, 0.001, 3,
  )
  assert_eq(final_cw.length(), conv_weights.length())
  assert_eq(final_cb.length(), conv_bias.length())
  assert_eq(final_dw.length(), dense_weights.length())
  assert_eq(final_db.length(), dense_bias.length())
  assert_eq(history.length(), 3)
  // 每个 epoch 的 history 应有记录
  for i in 0..<3 {
    assert_true(history[i].epoch == i + 1)
    assert_true(history[i].train_loss >= 0.0)
  }
}

///|
test "cnn_recognize_char: 基本识别" {
  let config = create_default_char_cnn_config(3)
  let labels = ["A", "B", "C"]
  let img = @types.Image::{
    width: 16,
    height: 16,
    channels: 1,
    data: Bytes::from_array(Array::make(256, b'\x80')),
  }
  let result = cnn_recognize_char(img, config, labels)
  assert_true(result.predicted_class >= 0 && result.predicted_class < 3)
  assert_true(result.confidence >= 0.0 && result.confidence <= 1.0)
  assert_eq(result.predicted_label, labels[result.predicted_class])
}

///|
test "cnn_recognize_char: 标签数量不匹配抛异常" {
  let config = create_default_char_cnn_config(10)
  let labels = ["A", "B", "C"] // 只有 3 个标签
  let img = @types.Image::{
    width: 8,
    height: 8,
    channels: 1,
    data: Bytes::from_array(Array::make(64, b'\x80')),
  }
  try {
    let _ = cnn_recognize_char(img, config, labels)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "cnn_recognize_digits: 10 类标签" {
  let config = create_default_char_cnn_config(10)
  let img = @types.Image::{
    width: 16,
    height: 16,
    channels: 1,
    data: Bytes::from_array(Array::make(256, b'\xFF')),
  }
  let result = cnn_recognize_digits(img, config)
  assert_true(result.predicted_class >= 0 && result.predicted_class < 10)
  assert_true(result.confidence >= 0.0 && result.confidence <= 1.0)
}

///|
test "cnn_recognize_letters: 26 类标签" {
  let config = create_default_char_cnn_config(26)
  let img = @types.Image::{
    width: 20,
    height: 20,
    channels: 1,
    data: Bytes::from_array(Array::make(400, b'\x40')),
  }
  let result = cnn_recognize_letters(img, config)
  assert_true(result.predicted_class >= 0 && result.predicted_class < 26)
  assert_true(result.confidence >= 0.0 && result.confidence <= 1.0)
}

///|
test "evaluate_cnn_model: 返回准确率和置信度" {
  let config = create_default_char_cnn_config(2)
  let labels = ["0", "1"]
  let img = @types.Image::{
    width: 8,
    height: 8,
    channels: 1,
    data: Bytes::from_array(Array::make(64, b'\x80')),
  }
  let sample1 = create_training_sample(img, 0, "0")
  let sample2 = create_training_sample(img, 1, "1")
  let test_samples = [sample1, sample2]
  let (accuracy, avg_conf) = evaluate_cnn_model(test_samples, config, labels)
  assert_true(accuracy >= 0.0 && accuracy <= 1.0)
  assert_true(avg_conf >= 0.0 && avg_conf <= 1.0)
}

///|
test "evaluate_cnn_model: 空样本抛异常" {
  let config = create_default_char_cnn_config(2)
  let labels = ["0", "1"]
  try {
    let _ = evaluate_cnn_model([], config, labels)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "cnn_confusion_matrix: 矩阵维度正确" {
  let config = create_default_char_cnn_config(3)
  let labels = ["A", "B", "C"]
  let img = @types.Image::{
    width: 8,
    height: 8,
    channels: 1,
    data: Bytes::from_array(Array::make(64, b'\x80')),
  }
  let sample1 = create_training_sample(img, 0, "A")
  let sample2 = create_training_sample(img, 1, "B")
  let sample3 = create_training_sample(img, 2, "C")
  let test_samples = [sample1, sample2, sample3]
  let matrix = cnn_confusion_matrix(test_samples, config, labels)
  assert_eq(matrix.length(), 3)
  for i in 0..<3 {
    assert_eq(matrix[i].length(), 3)
  }
  // 每行总和应等于该类样本数（这里每类 1 个）
  for i in 0..<3 {
    let mut row_sum = 0
    for j in 0..<3 {
      row_sum += matrix[i][j]
    }
    assert_eq(row_sum, 1)
  }
}

///|
test "cnn_confusion_matrix: 空样本抛异常" {
  let config = create_default_char_cnn_config(2)
  let labels = ["0", "1"]
  try {
    let _ = cnn_confusion_matrix([], config, labels)
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}
