output "alb_dns_name" {
  description = "The public DNS URL of the Application Load Balancer to access the website"
  value       = "http://${aws_lb.main.dns_name}"
}

output "vpc_id" {
  description = "The ID of the created VPC"
  value       = aws_vpc.main.id
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table"
  value       = aws_dynamodb_table.app_db.name
}

output "s3_bucket_name" {
  description = "The name of the S3 storage bucket"
  value       = aws_s3_bucket.app_storage.id
}
