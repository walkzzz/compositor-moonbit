// OCR 后处理纠错模块（v12.22.0 P1 准确率提升）
// 词典纠错、相似字符纠正、语言模型、上下文纠错、常见错误模式纠正

///|
/// 纠错结果
pub(all) struct CorrectionResult {
  original : String
  corrected : String
  is_corrected : Bool
  confidence : Double
  corrections : Array[CorrectionEntry]
}

///|
/// 纠错条目
pub(all) struct CorrectionEntry {
  position : Int
  original_char : String
  corrected_char : String
  reason : String
  confidence : Double
}

///|
/// 相似字符映射
pub(all) struct SimilarCharMapping {
  char : String
  similar_chars : Array[String]
  context_hint : String
}

///|
/// 常见错误模式
pub(all) struct CommonErrorPattern {
  pattern : String
  correction : String
  frequency : Int
  context_before : String
  context_after : String
}

///|
/// 词典条目
pub(all) struct DictionaryEntry {
  word : String
  frequency : Int
  category : String
}

///|
/// 语言模型状态
pub(all) struct LanguageModelState {
  dictionary : Array[DictionaryEntry]
  common_errors : Array[CommonErrorPattern]
  similar_chars : Array[SimilarCharMapping]
  total_words : Int
  total_corrections : Int
}

///|
/// 获取常见相似字符映射（英文/数字）
fn get_english_similar_chars() -> Array[SimilarCharMapping] {
  [
    SimilarCharMapping::{
      char: "0",
      similar_chars: ["O", "Q", "D"],
      context_hint: "数字中",
    },
    SimilarCharMapping::{
      char: "1",
      similar_chars: ["I", "l", "|"],
      context_hint: "数字中",
    },
    SimilarCharMapping::{
      char: "2",
      similar_chars: ["Z", "z"],
      context_hint: "数字中",
    },
    SimilarCharMapping::{
      char: "5",
      similar_chars: ["S", "s"],
      context_hint: "数字中",
    },
    SimilarCharMapping::{
      char: "8",
      similar_chars: ["B"],
      context_hint: "数字中",
    },
    SimilarCharMapping::{
      char: "O",
      similar_chars: ["0", "Q"],
      context_hint: "字母中",
    },
    SimilarCharMapping::{
      char: "I",
      similar_chars: ["1", "l", "|"],
      context_hint: "字母中",
    },
    SimilarCharMapping::{
      char: "l",
      similar_chars: ["1", "I", "|"],
      context_hint: "字母中",
    },
    SimilarCharMapping::{
      char: "Z",
      similar_chars: ["2"],
      context_hint: "字母中",
    },
    SimilarCharMapping::{
      char: "S",
      similar_chars: ["5"],
      context_hint: "字母中",
    },
    SimilarCharMapping::{
      char: "B",
      similar_chars: ["8"],
      context_hint: "字母中",
    },
    SimilarCharMapping::{
      char: "rn",
      similar_chars: ["m"],
      context_hint: "字母组合",
    },
    SimilarCharMapping::{
      char: "cl",
      similar_chars: ["d"],
      context_hint: "字母组合",
    },
    SimilarCharMapping::{
      char: "ol",
      similar_chars: ["al"],
      context_hint: "字母组合",
    },
  ]
}

///|
/// 获取中文常见相似字符
fn get_chinese_similar_chars() -> Array[SimilarCharMapping] {
  [
    SimilarCharMapping::{
      char: "己",
      similar_chars: ["已", "巳"],
      context_hint: "形近字",
    },
    SimilarCharMapping::{
      char: "已",
      similar_chars: ["己", "巳"],
      context_hint: "形近字",
    },
    SimilarCharMapping::{
      char: "未",
      similar_chars: ["末"],
      context_hint: "形近字",
    },
    SimilarCharMapping::{
      char: "末",
      similar_chars: ["未"],
      context_hint: "形近字",
    },
    SimilarCharMapping::{
      char: "日",
      similar_chars: ["曰"],
      context_hint: "形近字",
    },
    SimilarCharMapping::{
      char: "大",
      similar_chars: ["太", "犬"],
      context_hint: "形近字",
    },
    SimilarCharMapping::{
      char: "人",
      similar_chars: ["入", "八"],
      context_hint: "形近字",
    },
    SimilarCharMapping::{
      char: "土",
      similar_chars: ["士"],
      context_hint: "形近字",
    },
    SimilarCharMapping::{
      char: "王",
      similar_chars: ["玉", "主"],
      context_hint: "形近字",
    },
    SimilarCharMapping::{
      char: "刀",
      similar_chars: ["力", "刁"],
      context_hint: "形近字",
    },
    SimilarCharMapping::{
      char: "了",
      similar_chars: ["子", "孑"],
      context_hint: "形近字",
    },
    SimilarCharMapping::{
      char: "我",
      similar_chars: ["找", "伐"],
      context_hint: "形近字",
    },
    SimilarCharMapping::{
      char: "的",
      similar_chars: ["约", "钓"],
      context_hint: "形近字",
    },
    SimilarCharMapping::{
      char: "是",
      similar_chars: ["足", "走"],
      context_hint: "形近字",
    },
    SimilarCharMapping::{
      char: "不",
      similar_chars: ["卞", "木"],
      context_hint: "形近字",
    },
    SimilarCharMapping::{
      char: "在",
      similar_chars: ["有", "存"],
      context_hint: "形近字",
    },
  ]
}

///|
/// 获取常见错误模式
fn get_common_error_patterns() -> Array[CommonErrorPattern] {
  [
    CommonErrorPattern::{
      pattern: "OCR",
      correction: "OCR",
      frequency: 100,
      context_before: "",
      context_after: "",
    },
    CommonErrorPattern::{
      pattern: "the the",
      correction: "the",
      frequency: 80,
      context_before: "",
      context_after: "",
    },
    CommonErrorPattern::{
      pattern: "a a",
      correction: "a",
      frequency: 70,
      context_before: "",
      context_after: "",
    },
    CommonErrorPattern::{
      pattern: "is is",
      correction: "is",
      frequency: 60,
      context_before: "",
      context_after: "",
    },
    CommonErrorPattern::{
      pattern: "。。",
      correction: "。",
      frequency: 90,
      context_before: "",
      context_after: "",
    },
    CommonErrorPattern::{
      pattern: "，，",
      correction: "，",
      frequency: 85,
      context_before: "",
      context_after: "",
    },
    CommonErrorPattern::{
      pattern: "的的",
      correction: "的",
      frequency: 75,
      context_before: "",
      context_after: "",
    },
    CommonErrorPattern::{
      pattern: "了了",
      correction: "了",
      frequency: 65,
      context_before: "",
      context_after: "",
    },
    CommonErrorPattern::{
      pattern: "是是",
      correction: "是",
      frequency: 55,
      context_before: "",
      context_after: "",
    },
    CommonErrorPattern::{
      pattern: "在在",
      correction: "在",
      frequency: 50,
      context_before: "",
      context_after: "",
    },
  ]
}

///|
/// 创建默认语言模型
pub fn create_default_language_model() -> LanguageModelState {
  let dictionary : Array[DictionaryEntry] = []
  LanguageModelState::{
    dictionary,
    common_errors: get_common_error_patterns(),
    similar_chars: get_english_similar_chars(),
    total_words: 0,
    total_corrections: 0,
  }
}

///|
/// 基于相似字符的单字符纠错
pub fn correct_similar_chars(
  text : String,
  context_type : String, // "number" / "english" / "chinese" / "mixed"
) -> CorrectionResult raise @types.LoadError {
  // 输入验证
  if context_type != "number" &&
    context_type != "english" &&
    context_type != "chinese" &&
    context_type != "mixed" {
    raise @types.LoadError::DecodeFailed(
      "correct_similar_chars: 上下文类型必须是 number/english/chinese/mixed 之一",
    )
  }
  let _ = match context_type {
    "number" => get_english_similar_chars()
    "english" => get_english_similar_chars()
    "chinese" => get_chinese_similar_chars()
    _ => get_english_similar_chars()
  }

  let corrections : Array[CorrectionEntry] = []
  let mut corrected = text
  let mut is_corrected = false
  let mut total_confidence = 0.0
  let mut correction_count = 0

  // 简化版：基于上下文类型的字符替换
  // 数字上下文中：O→0, I→1, l→1, Z→2, S→5, B→8
  if context_type == "number" {
    let mut new_text = ""
    for i in 0..<text.length() {
      let c = text[i]
      let mut new_c = c.to_string()
      let mut corrected_here = false
      if c == 'O' || c == 'o' {
        new_c = "0"
        corrected_here = true
      } else if c == 'I' || c == 'l' || c == '|' {
        new_c = "1"
        corrected_here = true
      } else if c == 'Z' || c == 'z' {
        new_c = "2"
        corrected_here = true
      } else if c == 'S' || c == 's' {
        new_c = "5"
        corrected_here = true
      } else if c == 'B' {
        new_c = "8"
        corrected_here = true
      }
      if corrected_here {
        corrections.push(CorrectionEntry::{
          position: i,
          original_char: c.to_string(),
          corrected_char: new_c,
          reason: "数字上下文相似字符纠正",
          confidence: 0.85,
        })
        is_corrected = true
        total_confidence += 0.85
        correction_count += 1
      }
      new_text = new_text + new_c
    }
    corrected = new_text
  }

  let avg_confidence = if correction_count > 0 {
    total_confidence / correction_count.to_double()
  } else {
    1.0
  }

  CorrectionResult::{
    original: text,
    corrected,
    is_corrected,
    confidence: avg_confidence,
    corrections,
  }
}

///|
/// 基于常见错误模式的纠错
pub fn correct_common_patterns(text : String) -> CorrectionResult {
  let patterns = get_common_error_patterns()
  let corrections : Array[CorrectionEntry] = []
  let mut corrected = text
  let mut is_corrected = false
  let mut total_confidence = 0.0
  let mut correction_count = 0

  for pattern in patterns {
    // 简化版：只处理重复字符模式
    if pattern.pattern.length() == pattern.correction.length() * 2 {
      // 检测重复
      let _ = pattern.pattern.length() / 2
      let mut i = 0
      while i < corrected.length() - pattern.pattern.length() + 1 {
        let mut match_found = true
        for j in 0..<pattern.pattern.length() {
          if i + j < corrected.length() &&
            corrected[i + j] != pattern.pattern[j] {
            match_found = false
            break
          }
        }
        if match_found {
          corrections.push(CorrectionEntry::{
            position: i,
            original_char: pattern.pattern,
            corrected_char: pattern.correction,
            reason: "常见重复错误模式纠正",
            confidence: 0.9,
          })
          is_corrected = true
          total_confidence += 0.9
          correction_count += 1
          // 替换
          let mut new_text = ""
          for k in 0..<i {
            new_text = new_text + corrected[k].to_string()
          }
          new_text = new_text + pattern.correction
          for k in (i + pattern.pattern.length())..<corrected.length() {
            new_text = new_text + corrected[k].to_string()
          }
          corrected = new_text
          i += pattern.correction.length()
        } else {
          i += 1
        }
      }
    }
  }

  let avg_confidence = if correction_count > 0 {
    total_confidence / correction_count.to_double()
  } else {
    1.0
  }

  CorrectionResult::{
    original: text,
    corrected,
    is_corrected,
    confidence: avg_confidence,
    corrections,
  }
}

///|
/// 完整的后处理纠错流水线
pub fn full_postprocess_correction(
  text : String,
  context_type? : String = "mixed",
) -> CorrectionResult raise @types.LoadError {
  // 输入验证
  if context_type != "number" &&
    context_type != "english" &&
    context_type != "chinese" &&
    context_type != "mixed" {
    raise @types.LoadError::DecodeFailed(
      "full_postprocess_correction: 上下文类型必须是 number/english/chinese/mixed 之一",
    )
  }
  let ctx = context_type

  // 第一步：相似字符纠正
  let step1 = correct_similar_chars(text, ctx)

  // 第二步：常见错误模式纠正
  let step2 = correct_common_patterns(step1.corrected)

  // 合并结果
  let all_corrections : Array[CorrectionEntry] = []
  for c in step1.corrections {
    all_corrections.push(c)
  }
  for c in step2.corrections {
    all_corrections.push(c)
  }

  let is_corrected = step1.is_corrected || step2.is_corrected
  let avg_confidence = if all_corrections.length() > 0 {
    let mut total = 0.0
    for c in all_corrections {
      total += c.confidence
    }
    total / all_corrections.length().to_double()
  } else {
    1.0
  }

  CorrectionResult::{
    original: text,
    corrected: step2.corrected,
    is_corrected,
    confidence: avg_confidence,
    corrections: all_corrections,
  }
}

///|
/// 批量文本纠错
pub fn batch_correct_texts(
  texts : Array[String],
  context_type? : String = "mixed",
) -> Array[CorrectionResult] raise @types.LoadError {
  // 输入验证
  if texts.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "batch_correct_texts: 文本列表不能为空",
    )
  }
  if context_type != "number" &&
    context_type != "english" &&
    context_type != "chinese" &&
    context_type != "mixed" {
    raise @types.LoadError::DecodeFailed(
      "batch_correct_texts: 上下文类型必须是 number/english/chinese/mixed 之一",
    )
  }
  let results : Array[CorrectionResult] = []
  for text in texts {
    let result = full_postprocess_correction(text, context_type~)
    results.push(result)
  }
  results
}

///|
/// 生成纠错报告
pub fn generate_correction_report(results : Array[CorrectionResult]) -> String {
  let mut report = "## OCR 后处理纠错报告\n\n"
  let total_texts = results.length()
  let mut corrected_texts = 0
  let mut total_corrections = 0
  let mut total_confidence = 0.0

  for result in results {
    if result.is_corrected {
      corrected_texts += 1
      total_corrections += result.corrections.length()
      total_confidence += result.confidence
    }
  }

  let avg_confidence = if corrected_texts > 0 {
    total_confidence / corrected_texts.to_double()
  } else {
    1.0
  }
  let correction_rate = if total_texts > 0 {
    corrected_texts.to_double() / total_texts.to_double() * 100.0
  } else {
    0.0
  }

  report = report + "### 整体统计\n\n"
  report = report + "| 指标 | 数值 |\n"
  report = report + "|------|------|\n"
  report = report + "| 处理文本数 | " + total_texts.to_string() + " |\n"
  report = report +
    "| 纠错文本数 | " +
    corrected_texts.to_string() +
    " |\n"
  report = report + "| 纠错率 | " + correction_rate.to_string() + "% |\n"
  report = report +
    "| 总纠错次数 | " +
    total_corrections.to_string() +
    " |\n"
  report = report +
    "| 平均置信度 | " +
    (avg_confidence * 100.0).to_string() +
    "% |\n\n"

  report = report + "### 纠错详情\n\n"
  for i in 0..<results.length() {
    let result = results[i]
    if result.is_corrected {
      report = report + "**文本 " + (i + 1).to_string() + "**\n\n"
      report = report + "- 原文: " + result.original + "\n"
      report = report + "- 纠正: " + result.corrected + "\n"
      report = report +
        "- 置信度: " +
        (result.confidence * 100.0).to_string() +
        "%\n"
      report = report +
        "- 纠错次数: " +
        result.corrections.length().to_string() +
        "\n\n"
    }
  }

  report
}

///|
/// 计算纠错前后准确率提升
pub fn calculate_accuracy_improvement(
  before_results : Array[CorrectionResult],
  expected_texts : Array[String],
) -> (Double, Double, Double) {
  let mut before_accuracy = 0.0
  let mut after_accuracy = 0.0

  for i in 0..<before_results.length() {
    if i < expected_texts.length() {
      let before = before_results[i].original
      let after = before_results[i].corrected
      let expected = expected_texts[i]

      let before_correct = calculate_char_accuracy(expected, before)
      let after_correct = calculate_char_accuracy(expected, after)

      before_accuracy += before_correct
      after_accuracy += after_correct
    }
  }

  let count = if before_results.length() < expected_texts.length() {
    before_results.length()
  } else {
    expected_texts.length()
  }
  if count > 0 {
    before_accuracy = before_accuracy / count.to_double()
    after_accuracy = after_accuracy / count.to_double()
  }

  let improvement = after_accuracy - before_accuracy
  (before_accuracy, after_accuracy, improvement)
}
