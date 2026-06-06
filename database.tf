# Random string for globally unique S3 bucket naming
resource "random_string" "bucket_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Amazon S3 Bucket for App Storage
resource "aws_s3_bucket" "app_storage" {
  bucket        = "ha-app-storage-bucket-${random_string.bucket_suffix.result}"
  force_destroy = true

  tags = {
    Name = "ha-app-storage"
  }
}

# DynamoDB Table
resource "aws_dynamodb_table" "app_db" {
  name           = "ha-application-table"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "ha-app-db"
  }
}

# AWS Secrets Manager Secret
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "ha-database-credentials"
  recovery_window_in_days = 0 # allows immediate deletion on terraform destroy
}

# Mock DB Credentials value in Secrets Manager
resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "db_admin"
    password = "SuperSecretPassword123!"
  })
}

# SSM Parameter Store configuration parameter
resource "aws_ssm_parameter" "app_config" {
  name        = "/app/config/welcome_message"
  type        = "String"
  value       = "Welcome to the High Availability AWS Web Application Architecture!"
  description = "A configuration parameter read by the application server at startup"
}
