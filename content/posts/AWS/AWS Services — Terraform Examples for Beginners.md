---
title: "AWS Services — Terraform Examples for Beginners"
description: "Hands-on Terraform code examples for every major AWS service to help you learn infrastructure as code."
date: 2026-05-05
tags: ["aws", "terraform", "cloud", "devops", "iac"]
author: "Karim"
showToc: true
draft: false
---

# 🌩️ AWS Services — Terraform Examples for Beginners

> **What is Terraform?**
> Terraform is a tool that lets you create AWS resources by writing simple configuration files (`.tf`).
> Instead of clicking in the AWS Console, you describe what you want in code and Terraform builds it for you.

### How to use these examples
```bash
# 1. Install Terraform: https://developer.hashicorp.com/terraform/install
# 2. Configure AWS credentials
aws configure

# 3. For each example, create a folder, paste the code in main.tf, then run:
terraform init      # Download AWS provider
terraform plan      # Preview what will be created
terraform apply     # Create the resources
terraform destroy   # Delete everything when done
```

---

## 🔧 Provider Setup (Required in every project)

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
```

---

## 🖥️ Compute Services

### EC2 — Virtual Machine in the Cloud

```hcl
resource "aws_instance" "my_server" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"

  tags = {
    Name = "my-first-server"
  }
}

output "server_ip" {
  value = aws_instance.my_server.public_ip
}
```

---

### Lambda — Run Code Without a Server

```hcl
resource "aws_lambda_function" "hello_world" {
  function_name = "hello-world"
  runtime       = "python3.11"
  handler       = "index.handler"
  role          = aws_iam_role.lambda_role.arn
  filename      = "lambda.zip"
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}
```

---

## 🗄️ Storage Services

### S3 — File Storage in the Cloud

```hcl
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-unique-bucket-name-12345"

  tags = {
    Name = "my-first-bucket"
  }
}

resource "aws_s3_bucket_public_access_block" "my_bucket_block" {
  bucket                  = aws_s3_bucket.my_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

---

### EBS — Hard Drive for EC2

```hcl
resource "aws_ebs_volume" "my_disk" {
  availability_zone = "us-east-1a"
  size              = 20

  tags = { Name = "my-extra-disk" }
}

resource "aws_volume_attachment" "attach_disk" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.my_disk.id
  instance_id = aws_instance.my_server.id
}
```

---

### Glacier — Cheap Long-Term Archive Storage

```hcl
resource "aws_glacier_vault" "my_archive" {
  name = "my-archive-vault"

  tags = { Name = "cold-storage" }
}
```

---

## 🌐 Network Services

### VPC — Your Private Network in AWS

```hcl
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "my-vpc" }
}

resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "my-public-subnet" }
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = { Name = "my-internet-gateway" }
}
```

---

### Route 53 — DNS

```hcl
resource "aws_route53_zone" "my_domain" {
  name = "mywebsite.com"
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.my_domain.zone_id
  name    = "www.mywebsite.com"
  type    = "A"
  ttl     = 300
  records = ["1.2.3.4"]
}
```

---

### CloudFront — CDN

```hcl
resource "aws_cloudfront_distribution" "my_cdn" {
  origin {
    domain_name = aws_s3_bucket.my_bucket.bucket_regional_domain_name
    origin_id   = "S3Origin"
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3Origin"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
```

---

### ELB — Load Balancer

```hcl
resource "aws_lb" "my_alb" {
  name               = "my-load-balancer"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.my_subnet.id]
  tags = { Name = "my-alb" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Hello from Load Balancer!"
      status_code  = "200"
    }
  }
}
```

---

## 🗃️ Database Services

### RDS — Managed SQL Database

```hcl
resource "aws_db_instance" "my_database" {
  identifier          = "my-mysql-db"
  engine              = "mysql"
  engine_version      = "8.0"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  db_name             = "myapp"
  username            = "admin"
  password            = "SuperSecret123!"
  skip_final_snapshot = true
  tags = { Name = "my-rds" }
}
```

---

### DynamoDB — Fast NoSQL Database

```hcl
resource "aws_dynamodb_table" "my_table" {
  name         = "Users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"

  attribute {
    name = "userId"
    type = "S"
  }

  tags = { Name = "users-table" }
}
```

---

### ElastiCache — Redis Cache

```hcl
resource "aws_elasticache_cluster" "my_cache" {
  cluster_id           = "my-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  tags = { Name = "my-cache" }
}
```

---

## 🔒 Security Services

### IAM — Identity & Access Management

```hcl
resource "aws_iam_user" "developer" {
  name = "john-developer"
  tags = { Role = "Developer" }
}

resource "aws_iam_policy" "s3_read_policy" {
  name = "S3ReadOnlyAccess"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_user_policy_attachment" "attach" {
  user       = aws_iam_user.developer.name
  policy_arn = aws_iam_policy.s3_read_policy.arn
}
```

---

### WAF — Web Application Firewall

```hcl
resource "aws_wafv2_web_acl" "my_waf" {
  name  = "my-web-acl"
  scope = "REGIONAL"

  default_action { allow {} }

  rule {
    name     = "block-bad-bots"
    priority = 1
    action { block {} }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "waf-common-rules"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "my-waf"
    sampled_requests_enabled   = true
  }
}
```

---

### KMS — Encryption Keys

```hcl
resource "aws_kms_key" "my_key" {
  description             = "Key for encrypting my S3 bucket"
  deletion_window_in_days = 10
  tags = { Name = "my-encryption-key" }
}

resource "aws_kms_alias" "my_key_alias" {
  name          = "alias/my-key"
  target_key_id = aws_kms_key.my_key.key_id
}
```

---

## ⚙️ Automation & Application Support

### SQS — Message Queue

```hcl
resource "aws_sqs_queue" "my_queue" {
  name                      = "my-task-queue"
  delay_seconds             = 0
  message_retention_seconds = 86400
  tags = { Name = "task-queue" }
}
```

---

### SNS — Notification Service

```hcl
resource "aws_sns_topic" "alerts" {
  name = "system-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "you@example.com"
}
```

---

## 🛠️ Management Tools

### Systems Manager — Parameter Store

```hcl
resource "aws_ssm_parameter" "db_password" {
  name  = "/myapp/db/password"
  type  = "SecureString"
  value = "SuperSecret123!"
  tags  = { Environment = "production" }
}
```

---

## 📊 Monitoring Services

### CloudWatch — Monitor & Alert

```hcl
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "high-cpu-alert"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  dimensions          = { InstanceId = aws_instance.my_server.id }
  alarm_actions       = [aws_sns_topic.alerts.arn]
  tags = { Name = "cpu-alarm" }
}
```

---

### CloudTrail — Audit Log

```hcl
resource "aws_cloudtrail" "my_trail" {
  name                          = "my-audit-trail"
  s3_bucket_name                = aws_s3_bucket.my_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = true
  tags = { Name = "audit-trail" }
}
```

---

## 🎯 Mini Project — EC2 + S3 + CloudWatch

```hcl
provider "aws" { region = "us-east-1" }

resource "aws_s3_bucket" "app_bucket" {
  bucket = "my-app-storage-99999"
}

resource "aws_instance" "app_server" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"
  tags = { Name = "app-server" }
}

resource "aws_sns_topic" "alerts" { name = "alerts" }

resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  dimensions          = { InstanceId = aws_instance.app_server.id }
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

output "server_ip"   { value = aws_instance.app_server.public_ip }
output "bucket_name" { value = aws_s3_bucket.app_bucket.bucket }
```

---

## 📌 Terraform Cheat Sheet

```bash
terraform init       # Initialize project
terraform fmt        # Auto-format files
terraform validate   # Check for errors
terraform plan       # Preview changes
terraform apply      # Apply changes
terraform destroy    # Delete all resources
terraform output     # Show outputs
terraform state list # List managed resources
```

---

## ⚠️ Tips for Beginners

1. Always run `terraform plan` before `terraform apply`
2. Always run `terraform destroy` when done — AWS charges for running resources!
3. Never hardcode passwords — use `aws_ssm_parameter` instead
4. Free Tier services: EC2 t2.micro, RDS db.t3.micro, S3 (5GB), Lambda (1M requests/month)
5. Use `us-east-1` region — most services are available there

---

*Happy Terraforming! 🚀 Remember: `plan` before you `apply`!*
