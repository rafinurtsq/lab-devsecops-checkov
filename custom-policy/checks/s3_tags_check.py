# =============================================================================
# LAB DEVSECOPS - PERTEMUAN 11 (Lab 05)
# File: custom-policy/checks/s3_tags_check.py
#
# Custom Checkov policy: Memastikan S3 bucket memiliki tag wajib
# Check ID : CKV_CUSTOM_S3_1
# Severity : HIGH
# =============================================================================

from checkov.common.models.enums import CheckResult, CheckCategories
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck


class S3RequiredTagsCheck(BaseResourceCheck):
    """
    Memastikan setiap S3 bucket memiliki tag 'owner' dan 'environment'.

    Mengapa ini penting?
    - Tag 'owner'       : Identifikasi siapa yang bertanggung jawab atas bucket
    - Tag 'environment' : Membedakan bucket prod/staging/dev untuk cost allocation
    - Tanpa tag ini, sulit melakukan incident response dan audit biaya

    Policy ini mengikuti standar tagging organisasi untuk:
    1. Cost Allocation  - Tracking biaya per tim/project
    2. Security Audit   - Identifikasi resource yang tidak terotorisasi
    3. Incident Response - Hubungi owner dengan cepat saat ada insiden
    """

    def __init__(self):
        name = "Pastikan S3 bucket memiliki tag 'owner' dan 'environment'"
        id   = "CKV_CUSTOM_S3_1"
        supported_resources = ["aws_s3_bucket"]
        categories = [CheckCategories.GENERAL_SECURITY]
        super().__init__(
            name=name,
            id=id,
            categories=categories,
            supported_resources=supported_resources,
        )

    def scan_resource_conf(self, conf):
        """
        Periksa apakah resource memiliki tag yang diperlukan.

        Args:
            conf: Konfigurasi resource Terraform (dict)

        Returns:
            CheckResult.PASSED jika semua tag wajib ada
            CheckResult.FAILED jika ada tag wajib yang hilang
        """
        # Ambil attribute 'tags' dari resource
        tags = conf.get("tags", [{}])

        # pptxgenjs/Checkov kadang membungkus nilai dalam list
        if isinstance(tags, list):
            tags = tags[0] if tags else {}

        # Daftar tag yang wajib ada di setiap S3 bucket
        required_tags = {"owner", "environment"}

        # Periksa apakah semua required_tags ada di konfigurasi
        if isinstance(tags, dict) and required_tags.issubset(set(tags.keys())):
            return CheckResult.PASSED

        # Jika ada tag yang hilang, tampilkan pesan informatif
        if isinstance(tags, dict):
            missing = required_tags - set(tags.keys())
            print(f"  → Tag yang hilang: {', '.join(missing)}")
        else:
            print(f"  → Tidak ada tag sama sekali")

        return CheckResult.FAILED


# Registrasi check agar Checkov menemukannya
check = S3RequiredTagsCheck()
