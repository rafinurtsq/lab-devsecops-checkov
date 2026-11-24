# Lab Files — DevSecOps Pertemuan 11
## IaC Security dengan Checkov

---

### 📁 Struktur Direktori

```
lab-checkov/
├── terraform/
│   ├── main.tf           ← ⚠️  FILE LATIHAN: mengandung ~15 kerentanan
│   └── main_fixed.tf     ← ✅  REFERENSI JAWABAN setelah diperbaiki
│
├── kubernetes/
│   ├── deployment-bad.yaml   ← ⚠️  FILE LATIHAN: manifest K8s tidak aman
│   └── deployment-good.yaml  ← ✅  REFERENSI JAWABAN
│
├── dockerfile/
│   ├── Dockerfile.bad    ← ⚠️  FILE LATIHAN: Dockerfile tidak aman
│   ├── Dockerfile.good   ← ✅  REFERENSI JAWABAN
│   └── .dockerignore     ← ✅  Best practice untuk Docker build
│
├── custom-policy/
│   ├── test.tf           ← File Terraform untuk test custom policy
│   └── checks/
│       ├── s3_tags_check.py    ← Custom policy Python (Lab 05 - Pilihan A)
│       └── enforce_tags.yaml   ← Custom policy YAML (Lab 05 - Pilihan B)
│
└── .github/
    └── workflows/
        └── checkov-scan.yml    ← GitHub Actions pipeline (Lab 06)
```

---

### 🚀 Cara Memulai

**1. Salin folder ini ke direktori kerja Anda:**
```bash
cp -r lab-checkov-files ~/lab-checkov
cd ~/lab-checkov
```

**2. Install Checkov:**
```bash
pip3 install checkov
checkov --version
```

**3. Mulai Lab 02 — Scan awal Terraform:**
```bash
checkov -d terraform/ -o table
```

---

### ⚠️ PENTING

- File `main.tf`, `deployment-bad.yaml`, dan `Dockerfile.bad` **sengaja mengandung kerentanan**
- File `*_fixed.tf` / `*-good.*` adalah **referensi jawaban** — jangan dibuka sebelum mencoba sendiri
- **JANGAN** gunakan konfigurasi ini di environment produksi!
