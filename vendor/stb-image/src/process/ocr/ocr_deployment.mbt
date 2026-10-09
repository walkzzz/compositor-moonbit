// v13.6.0 OCR 部署工具（纯 MoonBit 配置生成/CLI/打包）
// Dockerfile 模板 / API Server 配置 / CLI 参数解析 / 模型打包

///|
/// 简易字符串转整数
fn parse_int_str(s : String) -> Int {
  let mut result = 0
  let mut sign = 1
  let start = if s.length() > 0 && s[0] == '-' {
    sign = -1
    1
  } else {
    0
  }
  for i in start..<s.length() {
    let c = s[i]
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    }
  }
  sign * result
}

///|
/// 部署环境类型
pub(all) enum DeploymentEnvironment {
  Development
  Staging
  Production
} derive(Eq)

///|
/// CLI 配置
pub(all) struct CliConfig {
  input_path : String
  output_path : String
  output_format : String
  language : String
  enable_handwriting : Bool
  enable_multilingual : Bool
  enable_document_analysis : Bool
  verbose : Bool
  batch_size : Int
}

///|
/// API Server 配置
pub(all) struct ApiServerConfig {
  host : String
  port : Int
  max_concurrent_requests : Int
  request_timeout_ms : Int
  max_image_size_mb : Int
  enable_cors : Bool
  auth_token : String
  rate_limit_per_minute : Int
}

///|
/// Docker 配置
pub(all) struct DockerConfig {
  base_image : String
  app_port : Int
  memory_limit_mb : Int
  cpu_limit : Double
  enable_gpu : Bool
  environment : DeploymentEnvironment
  volumes : Array[(String, String)]
}

///|
/// 模型打包配置
pub(all) struct ModelPackageConfig {
  model_name : String
  version : String
  model_path : String
  labels_path : String
  input_width : Int
  input_height : Int
  num_classes : Int
  compression : String
}

///|
/// 创建默认 CLI 配置
pub fn create_default_cli_config() -> CliConfig {
  CliConfig::{
    input_path: "",
    output_path: "output.txt",
    output_format: "text",
    language: "auto",
    enable_handwriting: false,
    enable_multilingual: true,
    enable_document_analysis: false,
    verbose: false,
    batch_size: 1,
  }
}

///|
/// 创建默认 API Server 配置
pub fn create_default_api_server_config() -> ApiServerConfig {
  ApiServerConfig::{
    host: "0.0.0.0",
    port: 8080,
    max_concurrent_requests: 10,
    request_timeout_ms: 30000,
    max_image_size_mb: 16,
    enable_cors: true,
    auth_token: "",
    rate_limit_per_minute: 60,
  }
}

///|
/// 创建默认 Docker 配置
pub fn create_default_docker_config() -> DockerConfig {
  DockerConfig::{
    base_image: "moonbit:latest",
    app_port: 8080,
    memory_limit_mb: 512,
    cpu_limit: 1.0,
    enable_gpu: false,
    environment: DeploymentEnvironment::Production,
    volumes: [],
  }
}

///|
/// 创建默认模型打包配置
pub fn create_default_model_package_config() -> ModelPackageConfig {
  ModelPackageConfig::{
    model_name: "ocr_model",
    version: "1.0.0",
    model_path: "./models/ocr_model.bin",
    labels_path: "./models/labels.txt",
    input_width: 32,
    input_height: 32,
    num_classes: 10,
    compression: "none",
  }
}

///|
/// 生成 Dockerfile 内容
pub fn generate_dockerfile(config : DockerConfig) -> String {
  let mut dockerfile = "FROM " + config.base_image + "\n\n"
  dockerfile = dockerfile + "WORKDIR /app\n\n"
  dockerfile = dockerfile + "COPY . .\n\n"
  dockerfile = dockerfile + "EXPOSE " + config.app_port.to_string() + "\n\n"
  dockerfile = dockerfile +
    "CMD [\"moon\", \"run\", \"--target\", \"native\"]\n"
  if config.memory_limit_mb > 0 {
    dockerfile = dockerfile +
      "\n# Memory limit: " +
      config.memory_limit_mb.to_string() +
      "MB\n"
  }
  if config.cpu_limit > 0.0 {
    dockerfile = dockerfile +
      "# CPU limit: " +
      config.cpu_limit.to_string() +
      "\n"
  }
  if config.enable_gpu {
    dockerfile = dockerfile + "# GPU enabled\n"
  }
  dockerfile
}

///|
/// 生成 docker-compose.yml 内容
pub fn generate_docker_compose(config : DockerConfig) -> String {
  let mut compose = "version: '3.8'\n\n"
  compose = compose + "services:\n"
  compose = compose + "  ocr-server:\n"
  compose = compose + "    build: .\n"
  compose = compose + "    ports:\n"
  compose = compose +
    "      - \"" +
    config.app_port.to_string() +
    ":" +
    config.app_port.to_string() +
    "\"\n"
  compose = compose + "    deploy:\n"
  compose = compose + "      resources:\n"
  compose = compose + "        limits:\n"
  compose = compose +
    "          memory: " +
    config.memory_limit_mb.to_string() +
    "M\n"
  compose = compose + "          cpus: '" + config.cpu_limit.to_string() + "'\n"
  if config.volumes.length() > 0 {
    compose = compose + "    volumes:\n"
    for i in 0..<config.volumes.length() {
      let (host, container) = config.volumes[i]
      compose = compose + "      - \"" + host + ":" + container + "\"\n"
    }
  }
  compose
}

///|
/// 生成 API Server 启动配置 JSON
pub fn generate_api_config_json(config : ApiServerConfig) -> String {
  let mut json = "{\n"
  json = json + "  \"host\": \"" + config.host + "\",\n"
  json = json + "  \"port\": " + config.port.to_string() + ",\n"
  json = json +
    "  \"max_concurrent_requests\": " +
    config.max_concurrent_requests.to_string() +
    ",\n"
  json = json +
    "  \"request_timeout_ms\": " +
    config.request_timeout_ms.to_string() +
    ",\n"
  json = json +
    "  \"max_image_size_mb\": " +
    config.max_image_size_mb.to_string() +
    ",\n"
  json = json +
    "  \"enable_cors\": " +
    (if config.enable_cors { "true" } else { "false" }) +
    ",\n"
  json = json +
    "  \"rate_limit_per_minute\": " +
    config.rate_limit_per_minute.to_string() +
    "\n"
  json = json + "}\n"
  json
}

///|
/// 生成 CLI 帮助文本
pub fn generate_cli_help() -> String {
  "stb-image OCR CLI 工具\n\n" +
  "用法: ocr_cli [选项] <输入路径>\n\n" +
  "选项:\n" +
  "  -o, --output <路径>      输出文件路径 (默认: output.txt)\n" +
  "  -f, --format <格式>      输出格式: text/json/markdown (默认: text)\n" +
  "  -l, --language <语言>    语言: auto/zh/en/ja/ko (默认: auto)\n" +
  "  --handwriting            启用手写体识别\n" +
  "  --multilingual           启用多语言混合识别 (默认启用)\n" +
  "  --document               启用文档版面分析\n" +
  "  -v, --verbose            详细输出\n" +
  "  -b, --batch <大小>       批处理大小 (默认: 1)\n" +
  "  -h, --help               显示帮助\n"
}

///|
/// 解析 CLI 参数（简化版）
pub fn parse_cli_args(args : Array[String]) -> CliConfig raise @types.LoadError {
  if args.length() == 0 {
    raise @types.LoadError::DecodeFailed(
      "parse_cli_args: 至少需要输入路径参数",
    )
  }
  let default = create_default_cli_config()
  let mut config = CliConfig::{ ..default, input_path: args[0] }
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "-o" || arg == "--output" {
      if i + 1 < args.length() {
        config = CliConfig::{ ..config, output_path: args[i + 1] }
        i += 2
      } else {
        raise @types.LoadError::DecodeFailed("parse_cli_args: -o 需要参数")
      }
    } else if arg == "-f" || arg == "--format" {
      if i + 1 < args.length() {
        config = CliConfig::{ ..config, output_format: args[i + 1] }
        i += 2
      } else {
        raise @types.LoadError::DecodeFailed("parse_cli_args: -f 需要参数")
      }
    } else if arg == "-l" || arg == "--language" {
      if i + 1 < args.length() {
        config = CliConfig::{ ..config, language: args[i + 1] }
        i += 2
      } else {
        raise @types.LoadError::DecodeFailed("parse_cli_args: -l 需要参数")
      }
    } else if arg == "--handwriting" {
      config = CliConfig::{ ..config, enable_handwriting: true }
      i += 1
    } else if arg == "--multilingual" {
      config = CliConfig::{ ..config, enable_multilingual: true }
      i += 1
    } else if arg == "--document" {
      config = CliConfig::{ ..config, enable_document_analysis: true }
      i += 1
    } else if arg == "-v" || arg == "--verbose" {
      config = CliConfig::{ ..config, verbose: true }
      i += 1
    } else if arg == "-b" || arg == "--batch" {
      if i + 1 < args.length() {
        config = CliConfig::{ ..config, batch_size: parse_int_str(args[i + 1]) }
        i += 2
      } else {
        raise @types.LoadError::DecodeFailed("parse_cli_args: -b 需要参数")
      }
    } else {
      i += 1
    }
  }
  config
}

///|
/// 生成模型打包清单
pub fn generate_model_manifest(config : ModelPackageConfig) -> String {
  let mut manifest = "{\n"
  manifest = manifest + "  \"name\": \"" + config.model_name + "\",\n"
  manifest = manifest + "  \"version\": \"" + config.version + "\",\n"
  manifest = manifest + "  \"model_path\": \"" + config.model_path + "\",\n"
  manifest = manifest + "  \"labels_path\": \"" + config.labels_path + "\",\n"
  manifest = manifest +
    "  \"input_width\": " +
    config.input_width.to_string() +
    ",\n"
  manifest = manifest +
    "  \"input_height\": " +
    config.input_height.to_string() +
    ",\n"
  manifest = manifest +
    "  \"num_classes\": " +
    config.num_classes.to_string() +
    ",\n"
  manifest = manifest + "  \"compression\": \"" + config.compression + "\"\n"
  manifest = manifest + "}\n"
  manifest
}

///|
/// 生成环境配置
pub fn generate_env_config(env : DeploymentEnvironment) -> String {
  match env {
    DeploymentEnvironment::Development =>
      "NODE_ENV=development\nLOG_LEVEL=debug\n"
    DeploymentEnvironment::Staging => "NODE_ENV=staging\nLOG_LEVEL=info\n"
    DeploymentEnvironment::Production => "NODE_ENV=production\nLOG_LEVEL=warn\n"
  }
}

///|
/// 生成健康检查端点配置
pub fn generate_health_check_config(config : ApiServerConfig) -> String {
  "health_check:\n" +
  "  endpoint: /health\n" +
  "  interval: 30s\n" +
  "  timeout: 5s\n" +
  "  retries: 3\n" +
  "  port: " +
  config.port.to_string() +
  "\n"
}

///|
/// 生成完整部署包
pub fn generate_deployment_package(
  docker_config : DockerConfig,
  api_config : ApiServerConfig,
  model_config : ModelPackageConfig,
) -> String {
  "=== 部署包 ===\n\n" +
  "--- Dockerfile ---\n" +
  generate_dockerfile(docker_config) +
  "\n--- docker-compose.yml ---\n" +
  generate_docker_compose(docker_config) +
  "\n--- API 配置 ---\n" +
  generate_api_config_json(api_config) +
  "\n--- 模型清单 ---\n" +
  generate_model_manifest(model_config) +
  "\n--- 环境配置 ---\n" +
  generate_env_config(docker_config.environment) +
  "\n--- 健康检查 ---\n" +
  generate_health_check_config(api_config)
}
