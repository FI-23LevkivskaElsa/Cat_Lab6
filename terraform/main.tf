terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" { 
  access_key                  = "mock_access_key" 
  secret_key                  = "mock_secret_key" 
  region                      = "eu-central-1" 
  skip_requesting_account_id  = true 
  s3_use_path_style           = true 
  skip_credentials_validation = true 
  skip_metadata_api_check     = true 
 
  endpoints { 
    s3     = "http://localhost:4566" 
    lambda = "http://localhost:4566" 
    sts    = "http://localhost:4566" 
    iam    = "http://localhost:4566" 
  } 
} 
 
locals { 
  lifecycle_policy = { 
    id     = "lifecycle-rule" 
    status = "Enabled" 
 
    transition = { 
      days         = 30 
      storage_class = "GLACIER" 
    } 
 
    expiration = { 
      days = 365 
    } 
  } 
} 

resource "aws_s3_bucket" "start_bucket" { 
  bucket = "s3-start" 
} 
 
resource "aws_s3_bucket" "finish_bucket" { 
  bucket = "s3-finish" 
} 
 
resource "aws_s3_bucket_lifecycle_configuration" "start_lifecycle" { 
  bucket = aws_s3_bucket.start_bucket.id 
 
  rule { 
    id     = local.lifecycle_policy.id 
    status = local.lifecycle_policy.status 
 
    transition { 
      days         = local.lifecycle_policy.transition.days 
      storage_class = local.lifecycle_policy.transition.storage_class 
    } 
 
    expiration { 
      days = local.lifecycle_policy.expiration.days 
    } 
  } 
} 
 
resource "aws_s3_bucket_lifecycle_configuration" "finish_lifecycle" { 
  bucket = aws_s3_bucket.finish_bucket.id 
 
  rule { 
    id     = local.lifecycle_policy.id 
    status = local.lifecycle_policy.status 
 
    transition { 
      days         = local.lifecycle_policy.transition.days 
      storage_class = local.lifecycle_policy.transition.storage_class 
    } 
 
    expiration { 
      days = local.lifecycle_policy.expiration.days 
    } 
  } 
} 
 
data "aws_iam_policy_document" "lambda_policy" { 
  statement { 
    effect = "Allow" 
 
    principals { 
      type        = "Service" 
      identifiers = ["lambda.amazonaws.com"] 
    } 
 
    actions = ["sts:AssumeRole"] 
  } 
} 
 
resource "aws_iam_role" "lambda_role" { 
  name               = "lambda_role" 
  assume_role_policy = data.aws_iam_policy_document.lambda_policy.json 
} 
 
data "aws_iam_policy_document" "lambda_s3_policy" { 
  statement { 
    effect = "Allow" 
    actions = [ 
      "s3:ListBucket", 
      "s3:GetObject", 
      "s3:PutObject" 
    ] 
    resources = [ 
      "arn:aws:s3:::s3-start", 
      "arn:aws:s3:::s3-start/*", 
      "arn:aws:s3:::s3-finish", 
      "arn:aws:s3:::s3-finish/*" 
    ] 
  } 
} 
 
resource "aws_iam_role_policy" "lambda_s3_policy" { 
  name   = "lambda_s3_policy" 
  role   = aws_iam_role.lambda_role.id 
  policy = data.aws_iam_policy_document.lambda_s3_policy.json 
} 
 
data "archive_file" "lambda" { 
  type        = "zip" 
  source_file = "lambda.py" 
  output_path = "lambda_function_payload.zip" 
} 
 
resource "aws_lambda_function" "lambda_function" { 
  filename         = data.archive_file.lambda.output_path 
  function_name    = "lambda-function" 
  role             = aws_iam_role.lambda_role.arn 
  handler          = "lambda.lambda_handler" 
  runtime          = "python3.10" 
  source_code_hash = filebase64sha256(data.archive_file.lambda.output_path) 
} 
 
resource "aws_s3_bucket_notification" "bucket_notification" { 
  bucket = aws_s3_bucket.start_bucket.id 
 
  lambda_function { 
    lambda_function_arn = aws_lambda_function.lambda_function.arn 
    events              = ["s3:ObjectCreated:*"] 
  } 
 
  depends_on = [aws_lambda_function.lambda_function] 
}