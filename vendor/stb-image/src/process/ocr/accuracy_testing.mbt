// OCR 准确率测试框架（v12.21.0 P0 基础加固）
// 提供准确率计算、混淆矩阵、错误分析、基准测试等工具

///|
/// 字符识别结果
pub(all) struct CharRecognitionResult {
  expected : String
  actual : String
  is_correct : Bool
  confidence : Double
  x : Int
  y : Int
}

///|
/// 准确率统计
pub(all) struct AccuracyStats {
  total_chars : Int
  correct_chars : Int
  char_accuracy : Double
  total_words : Int
  correct_words : Int
  word_accuracy : Double
  total_lines : Int
  correct_lines : Int
  line_accuracy : Double
  false_positives : Int
  false_negatives : Int
  precision : Double
  recall : Double
  f1_score : Double
}

///|
/// 混淆矩阵条目
pub(all) struct ConfusionEntry {
  expected : String
  actual : String
  count : Int
}

///|
/// 混淆矩阵
pub(all) struct ConfusionMatrix {
  entries : Array[ConfusionEntry]
  total_errors : Int
}

///|
/// 错误类型
pub(all) enum OcrErrorType {
  Substitution // 替换错误（A→B）
  Insertion // 插入错误（多识别了字符）
  Deletion // 删除错误（漏识别了字符）
  Reorder // 顺序错误
  Unknown
} derive(Eq)

///|
/// 错误分析条目
pub(all) struct ErrorAnalysisEntry {
  error_type : OcrErrorType
  expected : String
  actual : String
  context_before : String
  context_after : String
  confidence : Double
  count : Int
}

///|
/// 错误分析报告
pub(all) struct ErrorAnalysisReport {
  total_errors : Int
  substitution_count : Int
  insertion_count : Int
  deletion_count : Int
  reorder_count : Int
  top_errors : Array[ErrorAnalysisEntry]
  suggestions : Array[String]
}

///|
/// 性能基准结果
pub(all) struct PerformanceBenchmark {
  total_time_ms : Double
  preprocess_time_ms : Double
  layout_time_ms : Double
  recognition_time_ms : Double
  postprocess_time_ms : Double
  pages_per_second : Double
  chars_per_second : Double
  memory_usage_mb : Double
  cpu_usage_percent : Double
}

///|
/// 计算字符级准确率
pub fn calculate_char_accuracy(expected : String, actual : String) -> Double {
  if expected.length() == 0 {
    return if actual.length() == 0 { 1.0 } else { 0.0 }
  }
  let mut correct = 0
  let min_len = if expected.length() < actual.length() {
    expected.length()
  } else {
    actual.length()
  }
  for i in 0..<min_len {
    if expected[i] == actual[i] {
      correct += 1
    }
  }
  correct.to_double() / expected.length().to_double()
}

///|
/// 计算词级准确率
pub fn calculate_word_accuracy(expected : String, actual : String) -> Double {
  let expected_words = split_words(expected)
  let actual_words = split_words(actual)
  if expected_words.length() == 0 {
    return if actual_words.length() == 0 { 1.0 } else { 0.0 }
  }
  let mut correct = 0
  let min_len = if expected_words.length() < actual_words.length() {
    expected_words.length()
  } else {
    actual_words.length()
  }
  for i in 0..<min_len {
    if expected_words[i] == actual_words[i] {
      correct += 1
    }
  }
  correct.to_double() / expected_words.length().to_double()
}

///|
/// 简单分词（按空格和标点分割）
fn split_words(text : String) -> Array[String] {
  let words : Array[String] = []
  let mut current = ""
  for i in 0..<text.length() {
    let c = text[i]
    if c == ' ' ||
      c == '\n' ||
      c == '\t' ||
      c == ',' ||
      c == '.' ||
      c == '，' ||
      c == '。' ||
      c == '；' ||
      c == '：' {
      if current.length() > 0 {
        words.push(current)
        current = ""
      }
    } else {
      current = current + c.to_string()
    }
  }
  if current.length() > 0 {
    words.push(current)
  }
  words
}

///|
/// 计算编辑距离（Levenshtein）
pub fn calculate_edit_distance(s1 : String, s2 : String) -> Int {
  let m = s1.length()
  let n = s2.length()
  if m == 0 {
    return n
  }
  if n == 0 {
    return m
  }
  // 使用滚动数组优化空间
  let mut prev : Array[Int] = []
  let mut curr : Array[Int] = []
  for j in 0..<(n + 1) {
    prev.push(j)
    curr.push(0)
  }
  for i in 1..<(m + 1) {
    curr[0] = i
    for j in 1..<(n + 1) {
      let cost = if s1[i - 1] == s2[j - 1] { 0 } else { 1 }
      let del = prev[j] + 1
      let ins = curr[j - 1] + 1
      let sub = prev[j - 1] + cost
      curr[j] = if del < ins {
        if del < sub {
          del
        } else {
          sub
        }
      } else if ins < sub {
        ins
      } else {
        sub
      }
    }
    let temp = prev
    prev = curr
    curr = temp
  }
  prev[n]
}

///|
/// 计算完整准确率统计
pub fn calculate_accuracy_stats(
  expected_lines : Array[String],
  actual_lines : Array[String],
) -> AccuracyStats raise @types.LoadError {
  // 输入验证
  if expected_lines.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "calculate_accuracy_stats: 期望文本行列表不能为空",
    )
  }
  if actual_lines.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "calculate_accuracy_stats: 实际文本行列表不能为空",
    )
  }
  let mut total_chars = 0
  let mut correct_chars = 0
  let mut total_words = 0
  let mut correct_words = 0
  let total_lines = expected_lines.length()
  let mut correct_lines = 0
  let mut false_positives = 0
  let mut false_negatives = 0

  let min_lines = if expected_lines.length() < actual_lines.length() {
    expected_lines.length()
  } else {
    actual_lines.length()
  }

  for i in 0..<min_lines {
    let expected = expected_lines[i]
    let actual = actual_lines[i]
    total_chars += expected.length()
    let mut line_correct = 0
    let min_chars = if expected.length() < actual.length() {
      expected.length()
    } else {
      actual.length()
    }
    for j in 0..<min_chars {
      if expected[j] == actual[j] {
        correct_chars += 1
        line_correct += 1
      }
    }
    if actual.length() > expected.length() {
      false_positives += actual.length() - expected.length()
    } else {
      false_negatives += expected.length() - actual.length()
    }
    if line_correct == expected.length() && expected.length() == actual.length() {
      correct_lines += 1
    }
    // 词级准确率
    let exp_words = split_words(expected)
    let act_words = split_words(actual)
    total_words += exp_words.length()
    let min_words = if exp_words.length() < act_words.length() {
      exp_words.length()
    } else {
      act_words.length()
    }
    for j in 0..<min_words {
      if exp_words[j] == act_words[j] {
        correct_words += 1
      }
    }
  }

  // 多出的行
  if actual_lines.length() > expected_lines.length() {
    for i in expected_lines.length()..<actual_lines.length() {
      false_positives += actual_lines[i].length()
    }
  } else {
    for i in actual_lines.length()..<expected_lines.length() {
      false_negatives += expected_lines[i].length()
    }
  }

  let char_accuracy = if total_chars > 0 {
    correct_chars.to_double() / total_chars.to_double()
  } else {
    1.0
  }
  let word_accuracy = if total_words > 0 {
    correct_words.to_double() / total_words.to_double()
  } else {
    1.0
  }
  let line_accuracy = if total_lines > 0 {
    correct_lines.to_double() / total_lines.to_double()
  } else {
    1.0
  }

  let precision = if correct_chars + false_positives > 0 {
    correct_chars.to_double() / (correct_chars + false_positives).to_double()
  } else {
    1.0
  }
  let recall = if correct_chars + false_negatives > 0 {
    correct_chars.to_double() / (correct_chars + false_negatives).to_double()
  } else {
    1.0
  }
  let f1_score = if precision + recall > 0 {
    2.0 * precision * recall / (precision + recall)
  } else {
    0.0
  }

  AccuracyStats::{
    total_chars,
    correct_chars,
    char_accuracy,
    total_words,
    correct_words,
    word_accuracy,
    total_lines,
    correct_lines,
    line_accuracy,
    false_positives,
    false_negatives,
    precision,
    recall,
    f1_score,
  }
}

///|
/// 生成准确率报告
pub fn generate_accuracy_report(
  stats : AccuracyStats,
  dataset_name : String,
) -> String {
  let mut report = "## OCR 准确率测试报告\n\n"
  report = report + "**测试集**: " + dataset_name + "\n\n"
  report = report + "### 整体指标\n\n"
  report = report + "| 指标 | 数值 |\n"
  report = report + "|------|------|\n"
  report = report +
    "| 字符准确率 | " +
    (stats.char_accuracy * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 词准确率 | " +
    (stats.word_accuracy * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 行准确率 | " +
    (stats.line_accuracy * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 精确率 (Precision) | " +
    (stats.precision * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 召回率 (Recall) | " +
    (stats.recall * 100.0).to_string() +
    "% |\n"
  report = report +
    "| F1 分数 | " +
    (stats.f1_score * 100.0).to_string() +
    "% |\n\n"
  report = report + "### 详细统计\n\n"
  report = report + "| 指标 | 数值 |\n"
  report = report + "|------|------|\n"
  report = report + "| 总字符数 | " + stats.total_chars.to_string() + " |\n"
  report = report +
    "| 正确字符数 | " +
    stats.correct_chars.to_string() +
    " |\n"
  report = report + "| 总词数 | " + stats.total_words.to_string() + " |\n"
  report = report +
    "| 正确词数 | " +
    stats.correct_words.to_string() +
    " |\n"
  report = report + "| 总行数 | " + stats.total_lines.to_string() + " |\n"
  report = report +
    "| 正确行数 | " +
    stats.correct_lines.to_string() +
    " |\n"
  report = report +
    "| 误报 (False Positives) | " +
    stats.false_positives.to_string() +
    " |\n"
  report = report +
    "| 漏报 (False Negatives) | " +
    stats.false_negatives.to_string() +
    " |\n"
  report
}

///|
/// 生成性能基准报告
pub fn generate_performance_report(
  benchmark : PerformanceBenchmark,
  dataset_name : String,
) -> String {
  let mut report = "## OCR 性能基准测试报告\n\n"
  report = report + "**测试集**: " + dataset_name + "\n\n"
  report = report + "### 处理时间\n\n"
  report = report + "| 阶段 | 耗时 (ms) | 占比 |\n"
  report = report + "|------|-----------|------|\n"
  let total = if benchmark.total_time_ms > 0 {
    benchmark.total_time_ms
  } else {
    1.0
  }
  report = report +
    "| 预处理 | " +
    benchmark.preprocess_time_ms.to_string() +
    " | " +
    (benchmark.preprocess_time_ms / total * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 版面分析 | " +
    benchmark.layout_time_ms.to_string() +
    " | " +
    (benchmark.layout_time_ms / total * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 字符识别 | " +
    benchmark.recognition_time_ms.to_string() +
    " | " +
    (benchmark.recognition_time_ms / total * 100.0).to_string() +
    "% |\n"
  report = report +
    "| 后处理 | " +
    benchmark.postprocess_time_ms.to_string() +
    " | " +
    (benchmark.postprocess_time_ms / total * 100.0).to_string() +
    "% |\n"
  report = report +
    "| **总计** | **" +
    benchmark.total_time_ms.to_string() +
    "** | **100%** |\n\n"
  report = report + "### 吞吐量\n\n"
  report = report + "| 指标 | 数值 |\n"
  report = report + "|------|------|\n"
  report = report +
    "| 处理速度 (页/秒) | " +
    benchmark.pages_per_second.to_string() +
    " |\n"
  report = report +
    "| 识别速度 (字符/秒) | " +
    benchmark.chars_per_second.to_string() +
    " |\n"
  report = report +
    "| 内存占用 (MB) | " +
    benchmark.memory_usage_mb.to_string() +
    " |\n"
  report = report +
    "| CPU 使用率 (%) | " +
    benchmark.cpu_usage_percent.to_string() +
    " |\n"
  report
}

///|
/// 验证准确率是否达标
pub fn check_accuracy_threshold(
  stats : AccuracyStats,
  min_char_accuracy? : Double = 0.95,
  min_word_accuracy? : Double = 0.90,
  min_f1_score? : Double = 0.92,
) -> (Bool, Array[String]) raise @types.LoadError {
  // 输入验证
  if min_char_accuracy < 0.0 || min_char_accuracy > 1.0 {
    raise @types.LoadError::DecodeFailed(
      "check_accuracy_threshold: 字符准确率阈值必须在0-1之间",
    )
  }
  if min_word_accuracy < 0.0 || min_word_accuracy > 1.0 {
    raise @types.LoadError::DecodeFailed(
      "check_accuracy_threshold: 词准确率阈值必须在0-1之间",
    )
  }
  if min_f1_score < 0.0 || min_f1_score > 1.0 {
    raise @types.LoadError::DecodeFailed(
      "check_accuracy_threshold: F1分数阈值必须在0-1之间",
    )
  }
  let min_char = min_char_accuracy
  let min_word = min_word_accuracy
  let min_f1 = min_f1_score
  let mut passed = true
  let issues : Array[String] = []
  if stats.char_accuracy < min_char {
    passed = false
    issues.push(
      "字符准确率 " +
      (stats.char_accuracy * 100.0).to_string() +
      "% 低于阈值 " +
      (min_char * 100.0).to_string() +
      "%",
    )
  }
  if stats.word_accuracy < min_word {
    passed = false
    issues.push(
      "词准确率 " +
      (stats.word_accuracy * 100.0).to_string() +
      "% 低于阈值 " +
      (min_word * 100.0).to_string() +
      "%",
    )
  }
  if stats.f1_score < min_f1 {
    passed = false
    issues.push(
      "F1 分数 " +
      (stats.f1_score * 100.0).to_string() +
      "% 低于阈值 " +
      (min_f1 * 100.0).to_string() +
      "%",
    )
  }
  (passed, issues)
}
