// OCR 后处理
// 词典匹配、N-gram语言模型、拼写纠错、置信度校准

///|
/// 后处理配置
pub(all) struct PostProcessConfig {
  use_dictionary : Bool
  use_ngram : Bool
  ngram_size : Int
  min_confidence : Double
  max_candidates : Int
}

///|
/// 创建默认后处理配置
pub fn postprocess_default_config() -> PostProcessConfig {
  PostProcessConfig::{
    use_dictionary: true,
    use_ngram: true,
    ngram_size: 2,
    min_confidence: 0.3,
    max_candidates: 5,
  }
}

///|
/// 词典结构体
pub(all) struct Dictionary {
  words : Array[String]
  word_set : Array[String] // 用于快速查找（简化版）
}

///|
/// 创建词典
pub fn dictionary_create(
  words : Array[String],
) -> Dictionary raise @types.LoadError {
  // 输入验证
  if words.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "dictionary_create: 单词列表不能为空",
    )
  }

  Dictionary::{ words, word_set: words }
}

///|
/// 创建常用英文单词词典
pub fn dictionary_create_common_english() -> Dictionary {
  let words : Array[String] = [
    "the", "be", "to", "of", "and", "a", "in", "that", "have", "I", "it", "for",
    "not", "on", "with", "he", "as", "you", "do", "at", "this", "but", "his", "by",
    "from", "they", "we", "say", "her", "she", "or", "an", "will", "my", "one", "all",
    "would", "there", "their", "what", "so", "up", "out", "if", "about", "who", "get",
    "which", "go", "me", "when", "make", "can", "like", "time", "no", "just", "him",
    "know", "take", "people", "into", "year", "your", "good", "some", "could", "them",
    "see", "other", "than", "then", "now", "look", "only", "come", "its", "over",
    "think", "also", "back", "after", "use", "two", "how", "our", "work", "first",
    "well", "way", "even", "new", "want", "because", "any", "these", "give", "day",
    "most", "us", "hello", "world", "image", "text", "ocr", "digit", "number", "letter",
    "word", "line", "page", "document", "scan", "read", "write", "print", "font",
    "size", "color", "black", "white", "gray", "bright", "dark", "contrast", "sharp",
    "blur", "noise", "filter", "zero", "one", "two", "three", "four", "five", "six",
    "seven", "eight", "nine", "ten", "hundred", "thousand", "million", "billion",
    "yes", "no", "true", "false", "ok", "okay", "error", "warning", "info", "debug",
    "start", "stop", "begin", "end", "open", "close", "save", "load", "delete", "copy",
    "paste", "cut", "undo", "redo", "find", "replace", "search", "result", "output",
    "input", "data", "file", "folder", "directory", "path", "name", "value", "key",
    "code", "program", "software", "hardware", "system", "network", "server", "client",
    "user", "admin", "password", "login", "logout", "register", "account", "profile",
    "setting", "option", "config", "parameter", "argument", "variable", "function",
    "class", "object", "method_type", "property", "attribute", "field", "element",
    "node", "tree", "list", "array", "map", "set", "queue", "stack", "heap", "graph",
    "string", "integer", "float", "double", "boolean", "char", "byte", "bit", "pixel",
    "image", "width", "height", "channel", "format", "encode", "decode", "compress",
    "decompress", "encrypt", "decrypt", "hash", "checksum", "signature", "test",
    "test1", "test2", "abc", "abcd", "xyz", "foo", "bar", "baz",
  ]
  Dictionary::{ words, word_set: words }
}

///|
/// 计算编辑距离（Levenshtein距离）
pub fn edit_distance(s1 : String, s2 : String) -> Int raise @types.LoadError {
  // 输入验证
  if s1.length() == 0 && s2.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "edit_distance: 两个字符串不能同时为空",
    )
  }

  let len1 = s1.length()
  let len2 = s2.length()
  if len1 == 0 {
    return len2
  }
  if len2 == 0 {
    return len1
  }
  // 创建动态规划表
  let dp : Array[Int] = Array::make((len1 + 1) * (len2 + 1), 0)
  // 初始化
  for i in 0..<(len1 + 1) {
    dp[i * (len2 + 1)] = i
  }
  for j in 0..<(len2 + 1) {
    dp[j] = j
  }
  // 填充DP表
  for i in 1..<(len1 + 1) {
    for j in 1..<(len2 + 1) {
      let cost = if s1[i - 1] == s2[j - 1] { 0 } else { 1 }
      let insert = dp[i * (len2 + 1) + (j - 1)] + 1
      let delete = dp[(i - 1) * (len2 + 1) + j] + 1
      let substitute = dp[(i - 1) * (len2 + 1) + (j - 1)] + cost
      let min1 = if insert < delete { insert } else { delete }
      dp[i * (len2 + 1) + j] = if min1 < substitute { min1 } else { substitute }
    }
  }
  dp[len1 * (len2 + 1) + len2]
}

///|
/// 词典匹配：查找最相似的单词
pub fn dictionary_match(
  word : String,
  dictionary : Dictionary,
  max_distance? : Int = 2,
) -> Array[(String, Int)] raise @types.LoadError {
  // 输入验证
  if word.length() == 0 {
    raise @types.LoadError::DecodeFailed("dictionary_match: 单词不能为空")
  }
  if dictionary.words.length() == 0 {
    raise @types.LoadError::DecodeFailed("dictionary_match: 词典不能为空")
  }
  if max_distance < 0 {
    raise @types.LoadError::DecodeFailed(
      "dictionary_match: max_distance不能为负数",
    )
  }

  let results : Array[(String, Int)] = []
  for dict_word in dictionary.words {
    let dist = edit_distance(word, dict_word)
    if dist <= max_distance {
      results.push((dict_word, dist))
    }
  }
  // 按距离排序
  for _ in 0..<results.length() {
    for j in 0..<(results.length() - 1) {
      if results[j].1 > results[j + 1].1 {
        let temp = results[j]
        results[j] = results[j + 1]
        results[j + 1] = temp
      }
    }
  }
  results
}

///|
/// N-gram 语言模型
pub(all) struct NgramModel {
  n : Int
  bigram_counts : Array[(String, Int)] // 简化版：存储bigram和计数
  unigram_counts : Array[(String, Int)]
}

///|
/// 创建 N-gram 模型（从文本训练）
pub fn ngram_create(
  texts : Array[String],
  n? : Int = 2,
) -> NgramModel raise @types.LoadError {
  // 输入验证
  if texts.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "ngram_create: 文本列表不能为空",
    )
  }
  if n < 1 {
    raise @types.LoadError::DecodeFailed("ngram_create: n必须大于等于1")
  }

  let bigram_counts : Array[(String, Int)] = []
  let unigram_counts : Array[(String, Int)] = []
  for text in texts {
    // 简化：按字符处理
    for i in 0..<(text.length() - 1) {
      let bigram = text[i].to_string() + text[i + 1].to_string()
      // 查找是否已存在
      let mut found = false
      for j in 0..<bigram_counts.length() {
        if bigram_counts[j].0 == bigram {
          bigram_counts[j] = (bigram, bigram_counts[j].1 + 1)
          found = true
        }
      }
      if !found {
        bigram_counts.push((bigram, 1))
      }
    }
    // unigram
    for i in 0..<text.length() {
      let unigram = text[i].to_string()
      let mut found = false
      for j in 0..<unigram_counts.length() {
        if unigram_counts[j].0 == unigram {
          unigram_counts[j] = (unigram, unigram_counts[j].1 + 1)
          found = true
        }
      }
      if !found {
        unigram_counts.push((unigram, 1))
      }
    }
  }
  NgramModel::{ n, bigram_counts, unigram_counts }
}

///|
/// 计算文本的 N-gram 概率（简化版）
pub fn ngram_score(
  text : String,
  model : NgramModel,
) -> Double raise @types.LoadError {
  // 输入验证
  if text.length() == 0 {
    raise @types.LoadError::DecodeFailed("ngram_score: 文本不能为空")
  }
  if model.bigram_counts.length() == 0 && model.unigram_counts.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "ngram_score: N-gram模型不能为空",
    )
  }

  if text.length() < 2 {
    return 0.0
  }
  let mut total_score = 0.0
  let mut count = 0
  for i in 0..<(text.length() - 1) {
    let bigram = text[i].to_string() + text[i + 1].to_string()
    // 查找bigram概率
    let mut bigram_count = 0
    let mut unigram_count = 0
    for j in 0..<model.bigram_counts.length() {
      if model.bigram_counts[j].0 == bigram {
        bigram_count = model.bigram_counts[j].1
      }
    }
    let first_char = text[i].to_string()
    for j in 0..<model.unigram_counts.length() {
      if model.unigram_counts[j].0 == first_char {
        unigram_count = model.unigram_counts[j].1
      }
    }
    if unigram_count > 0 {
      total_score += bigram_count.to_double() / unigram_count.to_double()
      count += 1
    }
  }
  if count > 0 {
    total_score / count.to_double()
  } else {
    0.0
  }
}

///|
/// 完整后处理流水线
pub fn ocr_postprocess(
  result : OcrResult,
  config? : PostProcessConfig,
  dictionary? : Dictionary,
  ngram_model? : NgramModel,
) -> OcrResult raise @types.LoadError {
  ignore(ngram_model)
  // 输入验证
  if result.characters.length() == 0 && result.text.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "ocr_postprocess: OCR结果不能为空",
    )
  }

  let cfg = match config {
    Some(c) => c
    None => postprocess_default_config()
  }
  let dict = match dictionary {
    Some(d) => d
    None => dictionary_create_common_english()
  }
  // 1. 低置信度字符标记
  let mut corrected_text = ""
  let mut total_confidence = 0.0
  let corrected_chars : Array[OcrCharResult] = []
  for char_result in result.characters {
    let mut corrected_char = char_result.char
    let mut confidence = char_result.confidence
    // 2. 词典匹配（对低置信度字符）
    if cfg.use_dictionary && confidence < cfg.min_confidence {
      // 简化：只对单个字符进行常见纠错
      let corrections = common_char_corrections(char_result.char)
      if corrections.length() > 0 {
        corrected_char = corrections[0]
        confidence = confidence + 0.1
      }
    }
    corrected_text += corrected_char
    total_confidence += confidence
    corrected_chars.push(OcrCharResult::{
      char: corrected_char,
      confidence,
      x: char_result.x,
      y: char_result.y,
      width: char_result.width,
      height: char_result.height,
    })
  }
  // 3. 词典匹配（对整个文本中的单词）
  if cfg.use_dictionary {
    let words = split_into_words(corrected_text)
    let mut corrected_words = ""
    for word in words {
      if word.length() >= 2 {
        let matches = dictionary_match(word, dict, max_distance=1)
        if matches.length() > 0 && matches[0].1 > 0 {
          corrected_words += matches[0].0
        } else {
          corrected_words += word
        }
      } else {
        corrected_words += word
      }
    }
    corrected_text = corrected_words
  }
  let avg_confidence = if corrected_chars.length() > 0 {
    total_confidence / corrected_chars.length().to_double()
  } else {
    0.0
  }
  OcrResult::{
    text: corrected_text,
    confidence: avg_confidence,
    characters: corrected_chars,
  }
}

///|
/// 常见字符纠错映射
fn common_char_corrections(char : String) -> Array[String] {
  let corrections : Array[String] = []
  // OCR常见混淆字符对
  match char {
    "0" => corrections.push("O")
    "O" => corrections.push("0")
    "1" => corrections.push("I")
    "I" => corrections.push("1")
    "l" => corrections.push("1")
    "2" => corrections.push("Z")
    "Z" => corrections.push("2")
    "5" => corrections.push("S")
    "S" => corrections.push("5")
    "8" => corrections.push("B")
    "B" => corrections.push("8")
    "6" => corrections.push("G")
    "G" => corrections.push("6")
    "9" => corrections.push("g")
    "g" => corrections.push("9")
    _ => ignore(())
  }
  corrections
}

///|
/// 将文本分割成单词（简化版）
fn split_into_words(text : String) -> Array[String] {
  let words : Array[String] = []
  let mut current_word = ""
  for i in 0..<text.length() {
    let c = text[i]
    if c == ' ' || c == '\n' || c == '\t' {
      if current_word.length() > 0 {
        words.push(current_word)
        current_word = ""
      }
      words.push(c.to_string())
    } else {
      current_word += c.to_string()
    }
  }
  if current_word.length() > 0 {
    words.push(current_word)
  }
  words
}

///|
/// 置信度校准
pub fn calibrate_confidence(
  result : OcrResult,
  factor? : Double = 1.0,
) -> OcrResult raise @types.LoadError {
  // 输入验证
  if result.characters.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "calibrate_confidence: OCR结果字符列表不能为空",
    )
  }
  if factor <= 0.0 {
    raise @types.LoadError::DecodeFailed(
      "calibrate_confidence: factor必须大于0",
    )
  }

  let calibrated_chars : Array[OcrCharResult] = []
  let mut total = 0.0
  for char_result in result.characters {
    let new_confidence = if char_result.confidence * factor > 1.0 {
      1.0
    } else {
      char_result.confidence * factor
    }
    total += new_confidence
    calibrated_chars.push(OcrCharResult::{
      char: char_result.char,
      confidence: new_confidence,
      x: char_result.x,
      y: char_result.y,
      width: char_result.width,
      height: char_result.height,
    })
  }
  let avg = if calibrated_chars.length() > 0 {
    total / calibrated_chars.length().to_double()
  } else {
    0.0
  }
  OcrResult::{
    text: result.text,
    confidence: avg,
    characters: calibrated_chars,
  }
}
