# =============================================================================
# LAB DEVSECOPS - PERTEMUAN 11
# File: dockerfile/Dockerfile.bad
#
# ⚠️  PERINGATAN: Dockerfile ini SENGAJA mengandung kerentanan
#     untuk keperluan latihan praktikum Checkov.
#
# Checkov checks yang akan FAILED:
#   CKV_DOCKER_2  - HEALTHCHECK tidak ada
#   CKV_DOCKER_3  - Tidak ada instruksi USER (berjalan sebagai root)
#   CKV_DOCKER_7  - Image menggunakan tag :latest
#   CKV_DOCKER_9  - apt-get update tanpa versi pin
# =============================================================================

# ❌ Image menggunakan tag :latest (tidak terprediksi)
FROM ubuntu:latest

# ❌ Semua perintah dijalankan sebagai ROOT (default)
# Tidak ada instruksi USER

# ❌ apt-get tanpa version pinning dan --no-install-recommends
RUN apt-get update && \
    apt-get install -y \
    curl \
    wget \
    python3 \
    python3-pip \
    vim \
    net-tools

WORKDIR /app

# ❌ Copy seluruh direktori (termasuk file sensitif seperti .env, .git)
COPY . .

# ❌ Install dependency tanpa --no-cache-dir
RUN pip3 install -r requirements.txt

# ❌ Password/secret hardcoded sebagai environment variable
ENV DB_PASSWORD="admin123"
ENV SECRET_KEY="mysecretkey-production-2024"
ENV API_TOKEN="tok-prod-abcdef123456789"

# ❌ Tidak ada HEALTHCHECK
# Tidak ada cara bagi Docker/K8s untuk tahu jika aplikasi bermasalah

# Ekspos port (ini oke)
EXPOSE 5000

# ❌ CMD tidak menggunakan exec form (tidak bisa menerima signal)
CMD python3 app.py
