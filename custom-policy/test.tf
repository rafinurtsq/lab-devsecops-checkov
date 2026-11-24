# =============================================================================
# File pengujian untuk custom policy (Lab 05)
# Jalankan: checkov -f test.tf --external-checks-dir ./checks -o table
# =============================================================================

# ❌ Harus FAILED: S3 tanpa tag sama sekali
resource "aws_s3_bucket" "no_tags" {
  bucket = "bucket-tanpa-tag"
}

# ❌ Harus FAILED: S3 dengan tag tidak lengkap (tidak ada 'environment')
resource "aws_s3_bucket" "partial_tags" {
  bucket = "bucket-tag-tidak-lengkap"
  tags = {
    owner   = "devops-team"
    project = "devsecops-lab"
    # ❌ Tidak ada tag 'environment'
  }
}

# ✅ Harus PASSED: S3 dengan semua tag wajib
resource "aws_s3_bucket" "complete_tags" {
  bucket = "bucket-tag-lengkap"
  tags = {
    owner       = "devops-team"
    environment = "development"
    project     = "devsecops-lab"
    cost_center = "engineering"
  }
}

# ✅ Harus PASSED: S3 dengan tag wajib (meski tag lain ada)
resource "aws_s3_bucket" "minimal_required_tags" {
  bucket = "bucket-tag-minimal"
  tags = {
    owner       = "backend-team"
    environment = "staging"
  }
}
