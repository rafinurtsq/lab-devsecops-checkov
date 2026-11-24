# =============================================================================
# LAB DEVSECOPS - PERTEMUAN 11
# File: terraform/main_fixed.tf
#
# ✅ Ini adalah REFERENSI JAWABAN setelah semua kerentanan diperbaiki.
#    Gunakan file ini untuk memverifikasi perbaikan Anda sendiri di main.tf
#
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
# ✅ PERBAIKAN 1: S3 Bucket aman dengan enkripsi + block public access
# =============================================================================
resource "aws_s3_bucket" "data" {
  bucket = "my-company-data-bucket-dev"

  tags = {
    owner       = "devops-team"
    environment = "development"
    project     = "devsecops-lab"
  }
}

# ✅ Blokir semua akses publik
resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ✅ Enkripsi server-side dengan AES256
resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# ✅ Versioning aktif
resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ✅ Logging aktif (kirim ke bucket terpisah)
resource "aws_s3_bucket_logging" "data" {
  bucket        = aws_s3_bucket.data.id
  target_bucket = aws_s3_bucket.data.id  # Untuk lab: log ke bucket yang sama
  target_prefix = "access-logs/"
}

# =============================================================================
# ✅ PERBAIKAN 2: Security Group dengan batasan akses yang ketat
# =============================================================================
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Security group untuk web server - hanya akses yang diperlukan"

  # ✅ SSH hanya dari IP internal/VPN
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "SSH dari internal network saja"
  }

  # ✅ MySQL hanya dari subnet aplikasi
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16"]
    description = "MySQL dari subnet aplikasi"
  }

  # ✅ HTTPS dari internet (untuk web traffic)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS public access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }
}

# =============================================================================
# ✅ PERBAIKAN 3: IAM Policy dengan least privilege
# =============================================================================
resource "aws_iam_policy" "s3_read_only" {
  name        = "s3-read-only-policy"
  description = "Read-only access ke S3 bucket tertentu saja"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::my-company-data-bucket-dev",
          "arn:aws:s3:::my-company-data-bucket-dev/*"
        ]
      }
    ]
  })
}

# ✅ Gunakan IAM Role, bukan IAM User + Access Key
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
}

resource "aws_iam_role_policy_attachment" "app_role_s3" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.s3_read_only.arn
}

# =============================================================================
# ✅ PERBAIKAN 4: RDS aman - enkripsi, private, variable password
# =============================================================================
variable "db_password" {
  description = "Password untuk database RDS"
  type        = string
  sensitive   = true  # ✅ Tidak akan muncul di logs/state
}

resource "aws_db_instance" "main" {
  identifier          = "mydb-dev"
  engine              = "mysql"
  engine_version      = "8.0"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20

  username            = "admin"
  password            = var.db_password  # ✅ Dari variable, bukan hardcoded

  publicly_accessible     = false         # ✅ Tidak bisa diakses dari internet
  storage_encrypted       = true          # ✅ Enkripsi data at-rest
  deletion_protection     = true          # ✅ Tidak bisa dihapus sembarangan
  backup_retention_period = 7             # ✅ Backup 7 hari
  skip_final_snapshot     = false         # ✅ Simpan snapshot saat dihapus
  final_snapshot_identifier = "mydb-dev-final-snapshot"
  multi_az                = false         # Untuk lab: single AZ sudah cukup

  tags = {
    owner       = "devops-team"
    environment = "development"
  }
}

# =============================================================================
# ✅ PERBAIKAN 5: EC2 dengan enkripsi EBS + IMDSv2
# =============================================================================
resource "aws_instance" "web" {
  ami                  = "ami-0c02fb55956c7d316"
  instance_class       = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.app_profile.name

  # ✅ IMDSv2 wajib (proteksi terhadap SSRF)
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true    # ✅ Root volume dienkripsi
    volume_type = "gp3"
  }

  # ✅ Monitoring aktif
  monitoring = true

  tags = {
    owner       = "devops-team"
    environment = "development"
  }
}

resource "aws_iam_instance_profile" "app_profile" {
  name = "app-instance-profile"
  role = aws_iam_role.app_role.name
}

# =============================================================================
# ✅ PERBAIKAN 6: CloudTrail dengan enkripsi + multi-region + log validation
# =============================================================================
resource "aws_kms_key" "cloudtrail" {
  description             = "KMS key untuk CloudTrail logs"
  deletion_window_in_days = 10
  enable_key_rotation     = true  # ✅ Rotasi key otomatis

  tags = {
    owner       = "devops-team"
    environment = "development"
  }
}

resource "aws_cloudtrail" "main" {
  name           = "main-trail"
  s3_bucket_name = aws_s3_bucket.data.id

  kms_key_id              = aws_kms_key.cloudtrail.arn  # ✅ Enkripsi dengan KMS
  is_multi_region_trail   = true                         # ✅ Semua region
  enable_log_file_validation = true                      # ✅ Validasi log file

  tags = {
    owner       = "devops-team"
    environment = "development"
  }
}

# =============================================================================
# ✅ PERBAIKAN 7: ElastiCache dengan enkripsi at-rest dan in-transit
# =============================================================================
resource "aws_elasticache_replication_group" "cache" {
  replication_group_id = "my-cache"
  description          = "Redis cache dengan enkripsi"

  node_type            = "cache.t3.micro"
  port                 = 6379
  parameter_group_name = "default.redis7"

  at_rest_encryption_enabled  = true   # ✅ Enkripsi data saat disimpan
  transit_encryption_enabled  = true   # ✅ Enkripsi data saat dikirim
  auth_token                  = var.redis_auth_token

  tags = {
    owner       = "devops-team"
    environment = "development"
  }
}

variable "redis_auth_token" {
  description = "Auth token untuk ElastiCache Redis"
  type        = string
  sensitive   = true
}
