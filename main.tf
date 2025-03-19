terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "5.17.0" }
  }
}

provider "aws" {
  region  = "eu-north-1"
}

locals {
  repo_url = aws_ecr_repository.string_app.repository_url
}

resource "aws_ecr_repository" "string_app" {
  name                 = "lambda_string_app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "null_resource" "image" {
  triggers = {
    hash = md5(join("-", [for x in fileset("", "./py,*.txt,Dockerfile}") : filemd5(x)]))
  }

  provisioner "local-exec" {
    command = <<EOF
      aws ecr get-login-password | docker login --username AWS --password-stdin ${local.repo_url}
      docker build --platform linux/amd64 -t ${local.repo_url}:latest .
      docker push ${local.repo_url}:latest
    EOF
  }
}

data "aws_ecr_image" "latest" {
  repository_name = aws_ecr_repository.string_app.name
  image_tag       = "latest"
  depends_on      = [null_resource.image]
}

resource "aws_iam_role" "lambda" {
  name = "lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamoroles" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_cloudwatch_log_group" "string_app" {
  name              = "/aws/lambda/string_app"
  retention_in_days = 14
}

resource "aws_lambda_function" "string_app" {
  function_name    = "string_app"
  role             = aws_iam_role.lambda.arn
  image_uri        = "${aws_ecr_repository.string_app.repository_url}:latest"
  package_type     = "Image"
  source_code_hash = trimprefix(data.aws_ecr_image.latest.id, "sha256:")
  timeout          = 10

  environment {
    variables = {}
  }

  depends_on = [
    null_resource.image,
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.string_app,
  ]
}

resource "aws_lambda_function_url" "string_app" {
  function_name      = aws_lambda_function.string_app.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
}

resource "aws_dynamodb_table" "dynamodb_table" {
  name           = "string-table"
  billing_mode   = "PROVISIONED"
  read_capacity  = 2
  write_capacity = 2
  hash_key = "string-key"
  attribute {
    name = "string-key"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "initial_item" {
  table_name = aws_dynamodb_table.dynamodb_table.name
  hash_key   = aws_dynamodb_table.dynamodb_table.hash_key
  item = <<ITEM
{
  "string-key": {"S": "main"},
  "string-value": {"S": "default_string"}
}
ITEM
}

output "api_url" {
  value = aws_lambda_function_url.string_app.function_url
}
