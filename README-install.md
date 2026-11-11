# Cara Memasang Skill "Perbaikan Bootloop / Restart Berulang Sunmi T1" ke AI Agent Lain

Skill ini memungkinkan AI agent untuk mendiagnosis dan memperbaiki bootloop / restart berulang pada Sunmi T1 (MSM8916, Android 6.0.1) yang disebabkan oleh data/modul Chimera Google Play Services (GMS) korup.

## Struktur File Skill

```
sunmi-t1-bootloop-skill/
├── skill.json                 # Manifest skill (metadata, fungsi, trigger, troubleshooting)
├── skill-prompt.md            # System prompt / instruksi perilaku AI agent
├── PROSEDUR-BOOTLOOP-SUNMI-T1.md  # Basis pengetahuan lengkap (asli)
└── README-install.md          # Panduan instalasi (file ini)
```

## Langkah Instalasi

### Langkah 1: Salin Direktori Skill
Salin seluruh folder `sunmi-t1-bootloop-skill` ke direktori skill / knowledge base pada AI agent tujuan.

Contoh struktur tujuan:
```
<ai-agent>/skills/sunmi-t1-bootloop-skill/
```

### Langkah 2: Registrasi Manifest
Tambahkan entrik `skill.json` ke registry skill pada AI agent tujuan (jika aplikasi mendukung registry skill). Contoh:

```json
{
  "skill_id": "sunmi-t1-bootloop-fixer",
  "path": "./skills/sunmi-t1-bootloop-skill/skill.json",
  "auto_load": true
}
```

### Langkah 3: Muat System Prompt
Masukkan isi `skill-prompt.md` sebagai system prompt tambahan (atau sebagai instruksi dalam konteks skill) pada AI agent tujuan, sehingga agent mengetahui cara menggunakan prosedur ini saat pengguna mengajukan pertanyaan tentang bootloop Sunmi T1.

### Langkah 4: Sertakan Basis Pengetahuan
Pastikan file `PROSEDUR-BOOTLOOP-SUNMI-T1.md` tetap ada bersama skill agar AI agent dapat merujuk ke prosedur lengkap saat diperlukan.

## Prasyarat Penggunaan (di sisi teknisi / pengguna akhir)

- PC dengan ADB (platform-tools) terinstal
- Kabel USB data berkualitas
- Port USB 2.0 langsung di PC (bukan hub, bukan port USB 3.0 biru)
- Device Sunmi T1 masih terdeteksi di `adb devices`

## Fungsi yang Diekspos Skill ini

1. `diagnose_sunmi_t1_bootloop` — konfirmasi deteksi device & deteksi crash-loop
2. `fix_sunmi_t1_bootloop` — eksekusi 3 perintah inti perbaikan
3. `verify_sunmi_t1_stable` — verifikasi system_server stabil & boot selesai
4. `prevent_sunmi_t1_recurrence` — nonaktifkan Play Store permanen (pencegahan kambuh)
5. `restore_sunmi_t1_packages` — kembalikan package yang dinonaktifkan (hanya setelah Chimera sehat)

## Contoh Penggunaan oleh AI Agent

```
Pengguna: "Sunmi T1 saya restart berulang, tidak bisa dipakai."
AI Agent: 
  [1] Konfirmasi: adb devices -l
  [2] Deteksi crash-loop: ps | grep system_server (x2, jeda 25 detik)
  [3] Fix: adb shell "pm uninstall -k --user 0 com.qualcomm.location; pm uninstall -k --user 0 com.qualcomm.location.XT; pm clear com.google.android.gms"
  [4] Verifikasi: cek PID stabil, boot_completed=1, logcat crash kosong
  [5] Pencegahan: adb shell "pm uninstall -k --user 0 com.android.vending"
```

## Catatan

- Risiko fix: RENDAH — tidak ada factory reset, data & aplikasi aman.
- Estimasi waktu: 1–5 menit (kalau prosedur dikenal), 30+ menit jika diagnosis dari nol.
- Jangan restore `com.qualcomm.location(.XT)` / GMS sebelum memastikan modul Chimera sehat.

## Versi

Skill v1.0.0 — Terakhir diperbarui: 2026-11-11
