// OCR 准确率测试框架端到端测试（v12.21.0）
// 测试字符准确率、词准确率、编辑距离、完整统计、报告生成、阈值检查

///|
test "字符准确率计算 - 完全匹配" {
  let accuracy = @img.calculate_char_accuracy("Hello World", "Hello World")
  assert_true(accuracy > 0.999)
}

///|
test "字符准确率计算 - 部分错误" {
  let accuracy = @img.calculate_char_accuracy("Hello World", "Hello Wrold")
  assert_true(accuracy > 0.8 && accuracy < 1.0)
}

///|
test "字符准确率计算 - 空字符串" {
  let accuracy1 = @img.calculate_char_accuracy("", "")
  assert_true(accuracy1 > 0.999)
  let accuracy2 = @img.calculate_char_accuracy("", "Hello")
  assert_true(accuracy2 < 0.001)
}

///|
test "词准确率计算 - 完全匹配" {
  let accuracy = @img.calculate_word_accuracy(
    "Hello World Test", "Hello World Test",
  )
  assert_true(accuracy > 0.999)
}

///|
test "词准确率计算 - 部分错误" {
  let accuracy = @img.calculate_word_accuracy(
    "Hello World Test", "Hello Wrold Test",
  )
  assert_true(accuracy > 0.6 && accuracy < 1.0)
}

///|
test "编辑距离计算 - 相同字符串" {
  let dist = @img.calculate_edit_distance("abc", "abc")
  assert_eq(dist, 0)
}

///|
test "编辑距离计算 - 插入错误" {
  let dist = @img.calculate_edit_distance("abc", "abcd")
  assert_eq(dist, 1)
}

///|
test "编辑距离计算 - 删除错误" {
  let dist = @img.calculate_edit_distance("abcd", "abc")
  assert_eq(dist, 1)
}

///|
test "编辑距离计算 - 替换错误" {
  let dist = @img.calculate_edit_distance("abc", "axc")
  assert_eq(dist, 1)
}

///|
test "完整准确率统计 - 完美识别" {
  let expected = ["Hello World", "Test Line 2", "Third Line"]
  let actual = ["Hello World", "Test Line 2", "Third Line"]
  let stats = @img.calculate_accuracy_stats(expected, actual)
  assert_true(stats.char_accuracy > 0.999)
  assert_true(stats.word_accuracy > 0.999)
  assert_true(stats.line_accuracy > 0.999)
  assert_eq(stats.false_positives, 0)
  assert_eq(stats.false_negatives, 0)
}

///|
test "完整准确率统计 - 含错误" {
  let expected = ["Hello World", "Test Line"]
  let actual = ["Hello Wrold", "Test"]
  let stats = @img.calculate_accuracy_stats(expected, actual)
  assert_true(stats.char_accuracy < 1.0)
  assert_true(stats.false_negatives > 0)
}

///|
test "准确率报告生成" {
  let expected = ["Hello World", "Test Line"]
  let actual = ["Hello World", "Test Line"]
  let stats = @img.calculate_accuracy_stats(expected, actual)
  let report = @img.generate_accuracy_report(stats, "测试数据集")
  assert_true(report.length() > 100)
  assert_true(report.contains("字符准确率"))
  assert_true(report.contains("测试数据集"))
}

///|
test "性能报告生成" {
  let benchmark = @img.PerformanceBenchmark::{
    total_time_ms: 1000.0,
    preprocess_time_ms: 200.0,
    layout_time_ms: 300.0,
    recognition_time_ms: 400.0,
    postprocess_time_ms: 100.0,
    pages_per_second: 1.0,
    chars_per_second: 1000.0,
    memory_usage_mb: 50.0,
    cpu_usage_percent: 80.0,
  }
  let report = @img.generate_performance_report(benchmark, "性能测试")
  assert_true(report.length() > 100)
  assert_true(report.contains("处理时间"))
  assert_true(report.contains("吞吐量"))
}

///|
test "准确率阈值检查 - 通过" {
  let expected = ["Hello World", "Test Line"]
  let actual = ["Hello World", "Test Line"]
  let stats = @img.calculate_accuracy_stats(expected, actual)
  let (passed, issues) = @img.check_accuracy_threshold(
    stats,
    min_char_accuracy=0.95,
    min_word_accuracy=0.90,
    min_f1_score=0.92,
  )
  assert_true(passed)
  assert_eq(issues.length(), 0)
}

///|
test "准确率阈值检查 - 不通过" {
  let expected = ["Hello World", "Test Line"]
  let actual = ["Hello", "Test"]
  let stats = @img.calculate_accuracy_stats(expected, actual)
  let (passed, issues) = @img.check_accuracy_threshold(
    stats,
    min_char_accuracy=0.95,
    min_word_accuracy=0.90,
    min_f1_score=0.92,
  )
  assert_true(!passed)
  assert_true(issues.length() > 0)
}

///|
test "中文文本准确率" {
  let accuracy = @img.calculate_char_accuracy("你好世界", "你好世界")
  assert_true(accuracy > 0.999)
  let accuracy2 = @img.calculate_char_accuracy("你好世界", "你好视界")
  assert_true(accuracy2 > 0.5 && accuracy2 < 1.0)
}

///|
test "数字文本准确率" {
  let accuracy = @img.calculate_char_accuracy("1234567890", "1234567890")
  assert_true(accuracy > 0.999)
  let accuracy2 = @img.calculate_char_accuracy("1234567890", "123456789O")
  assert_true(accuracy2 > 0.8 && accuracy2 < 1.0)
}

///|
test "混合文本准确率" {
  let expected = ["订单号: 12345", "金额: ¥99.99", "日期: 2024-01-01"]
  let actual = ["订单号: 12345", "金额: ¥99.99", "日期: 2024-01-01"]
  let stats = @img.calculate_accuracy_stats(expected, actual)
  assert_true(stats.char_accuracy > 0.999)
  assert_true(stats.f1_score > 0.999)
}

///|
test "OCR 准确率测试框架完整流程" {
  // 模拟一个完整的 OCR 准确率测试流程
  let expected_lines = [
    "第一章 概述", "本文档介绍了系统的基本功能和使用方法。",
    "1.1 系统简介", "系统支持多种图像格式的处理和识别。", "1.2 主要特性",
    "- 高速图像处理", "- 高精度 OCR 识别", "- 多语言支持",
  ]
  let actual_lines = [
    "第一章 概述", "本文档介绍了系统的基本功能和使用方法。",
    "1.1 系统简介", "系统支持多种图像格式的处理和识别。", "1.2 主要特性",
    "- 高速图像处理", "- 高精度 OCR 识别", "- 多语言支持",
  ]

  // 计算准确率
  let stats = @img.calculate_accuracy_stats(expected_lines, actual_lines)

  // 验证指标
  assert_true(stats.char_accuracy > 0.99)
  assert_true(stats.word_accuracy > 0.99)
  assert_true(stats.line_accuracy > 0.99)
  assert_true(stats.precision > 0.99)
  assert_true(stats.recall > 0.99)
  assert_true(stats.f1_score > 0.99)

  // 生成报告
  let report = @img.generate_accuracy_report(stats, "文档识别测试集")
  assert_true(report.length() > 200)

  // 阈值检查
  let (passed, _) = @img.check_accuracy_threshold(
    stats,
    min_char_accuracy=0.95,
    min_word_accuracy=0.90,
    min_f1_score=0.92,
  )
  assert_true(passed)
}
