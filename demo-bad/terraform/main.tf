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
# ❌ KERENTANAN 1: S3 Bucket tanpa enkripsi + ACL publik
# Check IDs: CKV_AWS_19, CKV_AWS_20, CKV_AWS_57, CKV_AWS_18
# =============================================================================
resource "aws_s3_bucket" "data" {
  bucket = "my-company-data-bucket-dev"
  # Tidak ada enkripsi server-side
  # Tidak ada versioning
  # Tidak ada logging
}

resource "aws_s3_bucket_acl" "data_acl" {
  bucket = aws_s3_bucket.data.id
  acl    = "public-read"  # ❌ BAHAYA: Bucket bisa dibaca siapa saja!
}

# =============================================================================
# ❌ KERENTANAN 2: Security Group terbuka ke seluruh internet
# Check IDs: CKV_AWS_24, CKV_AWS_25, CKV2_AWS_12
# =============================================================================
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Security group untuk web server"

  # ❌ SSH terbuka ke seluruh internet
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ❌ MySQL terbuka ke seluruh internet
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ❌ Port 3389 (RDP) terbuka ke seluruh internet
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# =============================================================================
# ❌ KERENTANAN 3: IAM Policy dengan wildcard berbahaya
# Check IDs: CKV_AWS_40, CKV2_AWS_40
# =============================================================================
resource "aws_iam_policy" "admin" {
  name        = "full-access-policy"
  description = "Full access policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["*"]          # ❌ Semua action diizinkan
      Resource = ["*"]          # ❌ Semua resource diizinkan
    }]
  })
}

# ❌ IAM user dengan access key (seharusnya gunakan role)
resource "aws_iam_user" "app_user" {
  name = "app-service-user"
}

resource "aws_iam_access_key" "app_user" {
  user = aws_iam_user.app_user.name
  # ❌ Access key hardcoded user - seharusnya gunakan IAM Role
}

resource "aws_iam_user_policy_attachment" "app_user_admin" {
  user       = aws_iam_user.app_user.name
  policy_arn = aws_iam_policy.admin.arn
}

# =============================================================================
# ❌ KERENTANAN 4: RDS dengan password hardcoded + publicly accessible
# Check IDs: CKV_AWS_17, CKV_AWS_27, CKV_AWS_129, CKV_AWS_157
# =============================================================================
resource "aws_db_instance" "main" {
  identifier          = "mydb-dev"
  engine              = "mysql"
  engine_version      = "8.0"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20

  username            = "admin"
  password            = "Password123!"  # ❌ Password hardcoded di kode!

  publicly_accessible = true            # ❌ Database bisa diakses dari internet!
  storage_encrypted   = false           # ❌ Data tidak dienkripsi
  skip_final_snapshot = true            # ❌ Tidak ada backup saat dihapus

  # Tidak ada deletion_protection
  # Tidak ada backup_retention_period
  # Tidak ada multi_az
}

# =============================================================================
# ❌ KERENTANAN 5: EC2 tanpa enkripsi EBS + IMDSv1
# Check IDs: CKV_AWS_8, CKV2_AWS_41, CKV_AWS_135
# =============================================================================
resource "aws_instance" "web" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t3.micro"

  # ❌ IMDSv1 aktif (rentan terhadap SSRF attack)
  metadata_options {
    http_tokens = "optional"  # ❌ Seharusnya "required" (IMDSv2)
  }

  root_block_device {
    encrypted   = false       # ❌ EBS root volume tidak dienkripsi
    volume_type = "gp2"
  }

  # Tidak ada monitoring
  # Tidak ada VPC subnet yang spesifik
}

# =============================================================================
# ❌ KERENTANAN 6: CloudTrail tidak dienkripsi + tidak di semua region
# Check IDs: CKV_AWS_35, CKV_AWS_36, CKV2_AWS_10
# =============================================================================
resource "aws_cloudtrail" "main" {
  name           = "main-trail"
  s3_bucket_name = aws_s3_bucket.data.id

  # ❌ Tidak ada enkripsi KMS
  # kms_key_id = ...

  # ❌ Tidak mencatat semua region
  is_multi_region_trail = false

  # ❌ Log file validation tidak aktif
  enable_log_file_validation = false
}

# =============================================================================
# ❌ KERENTANAN 7: ElastiCache tanpa enkripsi at-rest dan in-transit
# Check IDs: CKV_AWS_28, CKV_AWS_29
# =============================================================================
resource "aws_elasticache_cluster" "cache" {
  cluster_id           = "my-cache"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  # ❌ Tidak ada enkripsi at-rest
  # at_rest_encryption_enabled = true
  # ❌ Tidak ada enkripsi in-transit
  # transit_encryption_enabled = true
}
