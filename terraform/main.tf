# =============================================================================
# LAB DEVSECOPS - PERTEMUAN 11
# File: terraform/main.tf
#
# ⚠️  PERINGATAN: File ini SENGAJA mengandung kerentanan keamanan
#     untuk keperluan latihan praktikum Checkov.
#     JANGAN gunakan konfigurasi ini di lingkungan produksi!
#
# Jumlah kerentanan: ~15 temuan (CRITICAL + HIGH + MEDIUM)
# =============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
}

# =============================================================================
#  KERENTANAN 1: S3 Bucket tanpa enkripsi + ACL publik
# Check IDs: CKV_AWS_19, CKV_AWS_20, CKV_AWS_57, CKV_AWS_18
# =============================================================================
resource "aws_s3_bucket" "data" {
  bucket = "my-company-data-bucket-dev"

  tags = {
    owner       = "devops-team"
    environment = "development"
    project     = "devsecops-lab"
  }
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "data" {
  bucket        = aws_s3_bucket.data.id
  target_bucket = aws_s3_bucket.data.id
  target_prefix = "access-logs/"
}

# =============================================================================
#  KERENTANAN 2: Security Group terbuka ke seluruh internet
# Check IDs: CKV_AWS_24, CKV_AWS_25, CKV2_AWS_12
# =============================================================================
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Security group untuk web server"

  ingress {
    description = "SSH dari jaringan internal"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    description = "MySQL dari subnet aplikasi"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16"]
  }

  ingress {
    description = "HTTPS publik"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound HTTPS saja"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    owner       = "devops-team"
    environment = "development"
  }
}
# =============================================================================
#  KERENTANAN 3: IAM Policy dengan wildcard berbahaya
# Check IDs: CKV_AWS_40, CKV2_AWS_40
# =============================================================================
resource "aws_iam_policy" "s3_read_only" {
  name        = "s3-read-only-policy"
  description = "Read-only ke bucket data saja"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        "arn:aws:s3:::my-company-data-bucket-dev",
        "arn:aws:s3:::my-company-data-bucket-dev/*"
      ]
    }]
  })
}

resource "aws_iam_role" "app_role" {
  name = "app-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    owner       = "devops-team"
    environment = "development"
  }
}

resource "aws_iam_role_policy_attachment" "app_role_s3" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.s3_read_only.arn
}

resource "aws_iam_instance_profile" "app_profile" {
  name = "app-instance-profile"
  role = aws_iam_role.app_role.name
}
# =============================================================================
# KERENTANAN 4: RDS dengan password hardcoded + publicly accessible
# Check IDs: CKV_AWS_17, CKV_AWS_27, CKV_AWS_129, CKV_AWS_157
# =============================================================================
variable "db_password" {
  description = "Password database RDS"
  type        = string
  sensitive   = true
}

resource "aws_db_instance" "main" {
  identifier        = "mydb-dev"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  username = "admin"
  password = var.db_password

  publicly_accessible       = false
  storage_encrypted         = true
  deletion_protection       = true
  backup_retention_period   = 7
  skip_final_snapshot       = false
  final_snapshot_identifier = "mydb-dev-final-snapshot"

  multi_az                            = true
  auto_minor_version_upgrade          = true
  iam_database_authentication_enabled = true
  monitoring_interval                 = 60
  enabled_cloudwatch_logs_exports     = ["general", "error"]
  copy_tags_to_snapshot               = true

  tags = {
    owner       = "devops-team"
    environment = "development"
  }
}

# =============================================================================
#  KERENTANAN 5: EC2 tanpa enkripsi EBS + IMDSv1
# Check IDs: CKV_AWS_8, CKV2_AWS_41, CKV_AWS_135
# =============================================================================
resource "aws_instance" "web" {
  ami                  = "ami-0c02fb55956c7d316"
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.app_profile.name
  monitoring           = true
  ebs_optimized        = true

  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = {
    owner       = "devops-team"
    environment = "development"
  }
}

# =============================================================================
# ❌ KERENTANAN 6: CloudTrail tidak dienkripsi + tidak di semua region
# Check IDs: CKV_AWS_35, CKV_AWS_36, CKV2_AWS_10
# =============================================================================
resource "aws_kms_key" "cloudtrail" {
  description         = "KMS key untuk CloudTrail"
  enable_key_rotation = true

  tags = {
    owner       = "devops-team"
    environment = "development"
  }
}

resource "aws_cloudtrail" "main" {
  name           = "main-trail"
  s3_bucket_name = aws_s3_bucket.data.id

  kms_key_id                 = aws_kms_key.cloudtrail.arn
  is_multi_region_trail      = true
  enable_log_file_validation = true

  tags = {
    owner       = "devops-team"
    environment = "development"
  }
}

# =============================================================================
# ❌ KERENTANAN 7: ElastiCache tanpa enkripsi at-rest dan in-transit
# Check IDs: CKV_AWS_28, CKV_AWS_29
# =============================================================================
variable "redis_auth_token" {
  description = "Auth token Redis"
  type        = string
  sensitive   = true
}

resource "aws_elasticache_replication_group" "cache" {
  replication_group_id = "my-cache"
  description          = "Redis cache terenkripsi"

  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_clusters   = 2
  port                 = 6379
  parameter_group_name = "default.redis7"

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token
  automatic_failover_enabled = true

  tags = {
    owner       = "devops-team"
    environment = "development"
  }
}