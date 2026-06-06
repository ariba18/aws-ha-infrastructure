# IAM Role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "ha-ec2-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ha-ec2-role"
  }
}

# Attach standard SSM Core policy so we can connect to private instances using Systems Manager (SSM) Session Manager without SSH keys
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Custom Policy for S3, DynamoDB, Secrets Manager, and SSM Parameter Store
resource "aws_iam_policy" "app_resources_policy" {
  name        = "ha-app-resources-policy"
  description = "Allows access to DynamoDB, S3, Secrets Manager, and Parameter Store"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.app_db.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.app_storage.arn,
          "${aws_s3_bucket.app_storage.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.db_credentials.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = aws_ssm_parameter.app_config.arn
      }
    ]
  })
}

# Attach the Custom Policy to the EC2 Role
resource "aws_iam_role_policy_attachment" "app_resources" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.app_resources_policy.arn
}

# IAM Instance Profile (to be attached to the EC2 Launch Template)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ha-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}
