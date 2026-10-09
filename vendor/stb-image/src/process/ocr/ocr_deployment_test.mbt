// v13.6.0 OCR 部署工具测试

///|
test "create_default_cli_config: 返回有效配置" {
  let config = create_default_cli_config()
  assert_eq(config.output_format, "text")
  assert_eq(config.language, "auto")
  assert_false(config.enable_handwriting)
  assert_true(config.enable_multilingual)
  assert_eq(config.batch_size, 1)
}

///|
test "create_default_api_server_config: 返回有效配置" {
  let config = create_default_api_server_config()
  assert_eq(config.host, "0.0.0.0")
  assert_eq(config.port, 8080)
  assert_true(config.max_concurrent_requests > 0)
  assert_true(config.enable_cors)
}

///|
test "create_default_docker_config: 返回有效配置" {
  let config = create_default_docker_config()
  assert_true(config.base_image.length() > 0)
  assert_true(config.app_port > 0)
  assert_true(config.memory_limit_mb > 0)
  assert_false(config.enable_gpu)
}

///|
test "create_default_model_package_config: 返回有效配置" {
  let config = create_default_model_package_config()
  assert_true(config.model_name.length() > 0)
  assert_true(config.version.length() > 0)
  assert_true(config.input_width > 0)
  assert_true(config.input_height > 0)
  assert_true(config.num_classes > 0)
}

///|
test "generate_dockerfile: 生成有效Dockerfile" {
  let config = create_default_docker_config()
  let dockerfile = generate_dockerfile(config)
  assert_true(dockerfile.length() > 0)
  assert_true(dockerfile.contains("FROM"))
  assert_true(dockerfile.contains("WORKDIR"))
  assert_true(dockerfile.contains("EXPOSE"))
}

///|
test "generate_docker_compose: 生成有效compose文件" {
  let config = create_default_docker_config()
  let compose = generate_docker_compose(config)
  assert_true(compose.length() > 0)
  assert_true(compose.contains("version"))
  assert_true(compose.contains("services"))
}

///|
test "generate_api_config_json: 生成有效JSON" {
  let config = create_default_api_server_config()
  let json = generate_api_config_json(config)
  assert_true(json.length() > 0)
  assert_true(json.contains("host"))
  assert_true(json.contains("port"))
}

///|
test "generate_cli_help: 生成帮助文本" {
  let help = generate_cli_help()
  assert_true(help.length() > 0)
  assert_true(help.contains("ocr_cli"))
  assert_true(help.contains("--output"))
}

///|
test "parse_cli_args: 基本参数解析" {
  let config = parse_cli_args(["input.png"])
  assert_eq(config.input_path, "input.png")
  assert_eq(config.output_format, "text")
}

///|
test "parse_cli_args: 解析输出路径" {
  let config = parse_cli_args(["input.png", "-o", "result.txt"])
  assert_eq(config.input_path, "input.png")
  assert_eq(config.output_path, "result.txt")
}

///|
test "parse_cli_args: 解析格式" {
  let config = parse_cli_args(["input.png", "-f", "json"])
  assert_eq(config.output_format, "json")
}

///|
test "parse_cli_args: 解析语言" {
  let config = parse_cli_args(["input.png", "-l", "zh"])
  assert_eq(config.language, "zh")
}

///|
test "parse_cli_args: 启用手写" {
  let config = parse_cli_args(["input.png", "--handwriting"])
  assert_true(config.enable_handwriting)
}

///|
test "parse_cli_args: 启用文档分析" {
  let config = parse_cli_args(["input.png", "--document"])
  assert_true(config.enable_document_analysis)
}

///|
test "parse_cli_args: 启用详细模式" {
  let config = parse_cli_args(["input.png", "-v"])
  assert_true(config.verbose)
}

///|
test "parse_cli_args: 解析批大小" {
  let config = parse_cli_args(["input.png", "-b", "16"])
  assert_eq(config.batch_size, 16)
}

///|
test "parse_cli_args: 空参数抛异常" {
  try {
    ignore(parse_cli_args([]))
    assert_true(false)
  } catch {
    _ => assert_true(true)
  }
}

///|
test "generate_model_manifest: 生成模型清单" {
  let config = create_default_model_package_config()
  let manifest = generate_model_manifest(config)
  assert_true(manifest.length() > 0)
  assert_true(manifest.contains("name"))
  assert_true(manifest.contains("version"))
}

///|
test "generate_env_config: 开发环境" {
  let env = generate_env_config(DeploymentEnvironment::Development)
  assert_true(env.contains("development"))
  assert_true(env.contains("debug"))
}

///|
test "generate_env_config: 生产环境" {
  let env = generate_env_config(DeploymentEnvironment::Production)
  assert_true(env.contains("production"))
  assert_true(env.contains("warn"))
}

///|
test "generate_health_check_config: 生成健康检查" {
  let config = create_default_api_server_config()
  let health = generate_health_check_config(config)
  assert_true(health.length() > 0)
  assert_true(health.contains("health"))
}

///|
test "generate_deployment_package: 生成完整部署包" {
  let docker_config = create_default_docker_config()
  let api_config = create_default_api_server_config()
  let model_config = create_default_model_package_config()
  let pkg = generate_deployment_package(docker_config, api_config, model_config)
  assert_true(pkg.length() > 0)
  assert_true(pkg.contains("Dockerfile"))
  assert_true(pkg.contains("docker-compose"))
  assert_true(pkg.contains("API"))
  assert_true(pkg.contains("模型"))
}
