# Prosedur Perbaikan Bootloop / Restart Berulang Sunmi T1
## "Service without Chimera impl" System Server Crash-Loop

| | |
|---|---|
| **Device** | Sunmi T1 (SUNMI_T1 / T1_G, MSM8916, Android 6.0.1) |
| **Gejala** | POS restart berulang / stuck logo animasi / layar berkedip kembali ke boot |
| **Akar Masalah** | Data/modul Chimera Google Play Services (GMS) korup → `system_server` crash tiap ~13–20 detik |
| **Tingkat Keparahan** | Device TIDAK bisa dipakai sama sekali sampai diperbaiki |
| **Risiko Fix** | RENDAH — TIDAK ada factory reset, data & aplikasi aman |
| **Estimasi Waktu** | 1–5 menit (kalau prosedur dikenal), 30+ menit jika diagnosis dari nol |
| **Prasyarat** | PC dengan ADB (platform-tools), kabel USB data berkualitas, port USB 2.0 |

---

## 1. Ringkasan Cepat (Untuk Teknisi Berpengalaman)

```bash
# 1. Tunggu jendela PackageManager hidup (~10 detik tiap siklus crash), lalu jalankan sekaligus:
adb shell "pm uninstall -k --user 0 com.qualcomm.location
           pm uninstall -k --user 0 com.qualcomm.location.XT
           pm clear com.google.android.gms"

# 2. Verifikasi system_server stabil (PID tidak berubah > 25 detik):
adb shell "ps | grep system_server"   # catat PID, tunggu 25 detik, cek lagi

# 3. Verifikasi tidak ada crash baru:
adb shell "logcat -b crash -d | grep 'IN SYSTEM PROCESS' | tail -2"
```

> **Kunci perbaikan:** `pm clear com.google.android.gms` (mereset modul Chimera ke bawaan).
> Dua uninstall qualcomm.location menghilangkan trigger geofence provider yang error.

---

## 2. Gejala & Cara Mengenali Case Ini

- ✅ Device **muncul di `adb devices`** (bahkan bisa `unauthorized`) — artinya device HIDUP, bukan mati total
- ✅ Animasi boot/logo muncul berulang, atau layar "berkedip" kembali ke awal
- ✅ `adb shell uptime` **pendek** dan selalu berubah tiap cek
- ✅ PID `system_server` **berganti-ganti** tiap 13–20 detik
- ✅ Log crash: `*** FATAL EXCEPTION IN SYSTEM PROCESS` + `java.lang.IllegalStateException: Service without Chimera impl` + stack `IGeofenceProvider.setGeofenceHardware` → `GeofenceProxy`

### Pembeda dari kerusakan lain

| Kondisi | Ciri | Penanganan |
|---|---|---|
| **Case ini** (soft crash-loop) | ADB terdeteksi stabil, TIDAK pernah putus-nyambung | Prosedur §4 |
| Bootloop hardware beneran | ADB hilang-muncul-mati berulang (putus total) | Recovery / flash ulang |
| Stuck di `unauthorized` | Dialog izinkan tidak pernah muncul, `boot_completed` kosong | Lihat §5.1 |
| EMMC / partisi rusak | Fastboot & recovery tetap crash, wipe cache gagal | Flash via Sunmi Flash Tool (9008) |


---

## 3. Diagnosis Lengkap (Step-by-Step)

### 3.1 Konfirmasi device terdeteksi
```bash
adb devices -l
# Ekspektasi: serial terdeteksi (status device / unauthorized / fastboot)
```

### 3.2 Deteksi crash-loop — PID system_server berganti-ganti
```bash
adb shell "ps | grep system_server"   # catat PID (mis. 6985)
# tunggu ±25 detik
adb shell "ps | grep system_server"   # PID berubah (mis. 9485) = CRASH-LOOP AKTIF
```
- PID berubah → **crash-loop terkonfirmasi**
- PID tetap → sistem stabil, cari gejala lain

### 3.3 Ambil bukti exception (akar masalah)
```bash
adb shell "logcat -b crash -d | grep -A8 'IN SYSTEM PROCESS' | tail -20"
```
**Signature khas case ini:**
```
*** FATAL EXCEPTION IN SYSTEM PROCESS: main
java.lang.IllegalStateException: Service without Chimera impl
    at android.os.Parcel.readException
    at android.location.IGeofenceProvider$Stub$Proxy.setGeofenceHardware
    at com.android.server.location.GeofenceProxy.setGeofenceHardwareInProviderLocked
    at com.android.server.SystemServer.run
```

### 3.4 Cek kondisi pendukung (opsional)
```bash
adb shell "uptime; getprop sys.boot_completed"   # boot_completed=1, uptime kecil
adb shell "df -h /data"                          # storage cukup (bukan masalah penuh)
adb shell "dmesg | grep lowmemorykiller"         # LMK aktif = RAM ketat (faktor pendukung, bukan akar)
```

---

## 4. Prosedur Perbaikan

### ⚠️ Aturan Penting
1. **PM hanya hidup ±10 detik tiap siklus crash** → semua perintah `pm` harus di-polling sampai kena jendela
2. **Batasi polling per eksekusi ≤ 25 detik** (timeout tool) — ulangi kalau belum kena
3. **JANGAN jalankan perintah fastboot/adb paralel** — serial saja agar tidak bentrok handle USB
4. **JANGAN factory reset** — tidak diperlukan untuk case ini, data & aplikasi aman

### Langkah 1 — Polling jendela PM + eksekusi 3 perintah sekaligus

Contoh PowerShell (pola: loop sampai semua `Success`):

```powershell
$deadline=(Get-Date).AddSeconds(27); $res=''
while((Get-Date) -lt $deadline){
  $r=(adb shell 'pm uninstall -k --user 0 com.qualcomm.location 2>&1;
                 pm uninstall -k --user 0 com.qualcomm.location.XT 2>&1;
                 pm clear com.google.android.gms 2>&1' 2>$null) -join ' | '
  if(($r -split '\|').Count -ge 3 -and $r -match 'Success' -and $r -notmatch 'Unknown package|SecurityException|Is the system running'){
    $res="SUKSES: $r"; break
  }
  # GAGAL permanen → berhenti; 'Is the system running' = PM belum siap → LANJUT polling
  if($r -match 'Unknown package|SecurityException' -and $r -notmatch 'Is the system running'){
    $res="RESPON: $r"; break
  }
  Start-Sleep -Milliseconds 400
}
Write-Output $(if($res){$res}else{"belum kena jendela. Terakhir: $r"})
```

**Ekspektasi output:** `SUKSES: Success | Success | Success`

### Langkah 2 — Verifikasi system_server stabil

```powershell
$p1=(adb shell 'ps | grep system_server').Split(' ',[StringSplitOptions]'RemoveEmptyEntries')[1]
Start-Sleep -Seconds 25
$p2=(adb shell 'ps | grep system_server').Split(' ',[StringSplitOptions]'RemoveEmptyEntries')[1]
# $p1 -eq $p2 → STABIL ✅
```

### Langkah 3 — Verifikasi akhir

```bash
adb shell "uptime; getprop sys.boot_completed; ps | grep -E 'system_server|woyou.launcher'"
adb shell "logcat -b crash -d | grep 'IN SYSTEM PROCESS' | tail -2"
```

Checklist selesai:
- [ ] PID system_server **tidak berubah** selama ≥25 detik
- [ ] `sys.boot_completed` = `1`
- [ ] `com.woyou.launcher` berjalan
- [ ] Tidak ada `IN SYSTEM PROCESS` baru **setelah** waktu fix
- [ ] Layar POS menampilkan launcher normal


---

## 5. Variian & Troubleshooting

### 5.1 Status ADB `unauthorized` (dialog izinkan tidak muncul)
- Regenerate ADB key (backup dulu): hapus `%USERPROFILE%\.android\adbkey(.pub)` → `adb kill-server` → `adb start-server`
- Kalau tetap `unauthorized` tapi koneksi **tidak pernah putus** → device besar kemungkinan stuck di boot, **bukan** restart. Lanjut ke §5.2.
- Kalau koneksi **putus-muncul** → bootloop beneran → recovery / flash.

### 5.2 Masuk Recovery Mode (Sunmi T1/T2/V1)
1. Cabut USB, matikan device (tahan Power ±10–15 detik)
2. Tahan **Power + Volume Up** sampai menu recovery
3. Kalau muncul layar **robot + tanda tanya ("No command")**:
   - Tahan **Power**, tekan sekali **Volume Up**, lepas — menu recovery akan muncul
   - (varian: tahan Power+Vol Up bersamaan ±5 detik)
4. Opsi: **Wipe cache partition** (aman) → reboot. Factory reset hanya jika diminta/opsi terakhir.

### 5.3 Mode Fastboot
- Deteksi: `fastboot devices`
- **Error `Write to device failed (no link)`** = masalah koneksi fisik → ganti kabel data / port USB 2.0 langsung di PC (bukan hub, bukan port biru 3.0)
- Setelah link normal, opsi reset total (⚠️ data hilang): `fastboot erase userdata` + `fastboot erase cache` + `fastboot reboot`

### 5.4 Error PM saat eksekusi

| Error | Arti | Solusi |
|---|---|---|
| `Is the system running?` | Jendela PM belum terbuka | Polling ulang, tunggu siklus berikutnya |
| `SecurityException: change component state` (uid 2000 vs uid 1000) | Shell tidak berhak disable package system | Gunakan `pm uninstall -k --user 0` (biasanya diizinkan) |
| `DELETE_FAILED_DEVICE_POLICY_MANAGER` (umumnya utk GMS) | Package adalah **device administrator aktif** | Lepas admin via layar: Settings → Security → Device administrators → hilangkan centang (§5.5) |
| `Unknown package` | Nama package salah | Cek: `adb shell "pm list packages \| grep -i <kata>"` |

### 5.5 Nonaktifkan GMS total (jika klien tetap ingin buang GMS/Vending)
1. Di layar device: **Settings → Security → Device administrators** → hilangkan centang **"Android Device Manager / Find My Device"** (`com.google.android.gms/.mdm.receivers.MdmDeviceAdminReceiver`)
2. Dari PC, pada jendela PM hidup:
   ```bash
   adb shell "pm uninstall -k --user 0 com.google.android.gms
              pm uninstall -k --user 0 com.android.vending"
   ```
3. Catatan: Android 6 **TIDAK** punya `dpm remove-active-admin`; `pm disable-user` juga sering ditolak shell di build Sunmi.

### 5.6 Jika semua langkah tetap crash-loop
1. Ulangi §4 (kemungkinan `pm clear` belum sempurna / PM terjebak)
2. Cek exception terbaru — **mungkin penyebabnya berbeda**, baca stack trace `IN SYSTEM PROCESS`
3. Opsi terakhir: flash firmware Sunmi T1 via **Sunmi Flash Tool** (mode 9008/EDL)


---

## 6. Cara Mengembalikan Package (Restore)

Kalau butuh komponen yang dinonaktifkan kembali:

```bash
adb shell "cmd package install-existing com.qualcomm.location"
adb shell "cmd package install-existing com.qualcomm.location.XT"
adb shell "cmd package install-existing com.google.android.gms"
adb shell "cmd package install-existing com.android.vending"
```

> ⚠️ Jangan restore `com.qualcomm.location(.XT)` / GMS **sebelum** memastikan modul Chimera sehat, karena itu justru bisa memicu crash-loop lagi.

---

## 7. Pencegahan (Agar Tidak Kambuh)

1. **Jangan cabut colokan daya paksa** saat POS proses update / pengisian — penyebab utama korupsi modul GMS
2. **Nonaktifkan Play Store permanen** (pencegahan utama — terbukti ampuh):
   ```bash
   adb shell "pm uninstall -k --user 0 com.android.vending"
   ```
   Tanpa `com.android.vending`, **GMS tidak bisa auto-update** → modul Chimera tidak akan korup lagi → tidak kambuh. *(Terkonfirmasi: kasus #3 kambuh tepat setelah GMS ter-update.)*
3. Pastikan **storage `/data` lega** (≥1 GB) sebelum update aplikasi
4. Kalau kambuh: perintah cepat = `adb shell pm clear com.google.android.gms`
5. Laporkan pola ini ke tim IT / support Sunmi kalau menyerang banyak unit (temuan: crash `GeofenceProxy` / `Service without Chimera impl` di T1, dipicu update GMS)

---

## 8. Penanganan Device Freeze (Alternatif Aman dari Cabut Daya Paksa)

> **Konteks:** Device Sunmi T1 kadang **freeze** (layar macet, tidak responsif). Kebiasaan sementara adalah **cabut paksa colokan daya** — ini **TIDAK disarankan** karena memicu korupsi modul GMS/Chimera (lihat §7 poin 1) dan bisa merusak filesystem. Gunakan prosedur berikut selama device masih terdeteksi ADB.

### 8.1 Cek dulu apakah device masih hidup (ADB responsif)

```bash
adb devices -l
adb shell echo ok
adb shell uptime
```

- Jika `adb shell` **merespons** → device hanya UI freeze, lanjut ke 8.2.
- Jika `adb shell` **hang / timeout** → lanjut ke 8.3 (soft reboot via ADB).
- Jika device **tidak muncul** di `adb devices` → lanjut ke 8.4 (hard reset via tombol fisik).

### 8.2 Freeze ringan — restart service / UI saja (data aman)

```bash
adb shell am force-stop com.android.systemui
```

### 8.3 Soft reboot via ADB (tanpa cabut daya)

```bash
adb reboot
adb shell getprop sys.boot_completed   # harus "1"
```

### 8.4 Jika ADB tidak responsif — gunakan tombol fisik (BUKAN cabut daya)

1. Tekan & tahan **tombol Power** 10–15 detik sampai mati.
2. Tunggu 5 detik, lalu tekan Power untuk menyalakan.
3. Hindari mencabut colokan daya kecuali benar-benar tidak ada opsi.

### 8.5 Setelah freeze/reboot — cek kesehatan GMS

```bash
adb shell "logcat -b crash -d | grep 'IN SYSTEM PROCESS' | tail -2"
```

Jika muncul `Service without Chimera impl` → jalankan prosedur §4.

### 8.6 Catatan

- Freeze berulang sering dipicu GMS auto-update / storage penuh → terapkan §7.
- Selalu coba soft reboot ADB sebelum force shutdown fisik.
- Jangan cabut colokan daya paksa saat POS proses update/pengisian.

---

## 9. Catatan Kasus (Log Perbaikan)

| # | Serial | Tanggal | Hasil | Keterangan |
|---|---|---|---|---|
| 1 | `7a4fcc20` | sesi ini | ✅ Fix | Diagnosis dari nol; perlu regen ADB key + tembus recovery dulu; fix setelah `pm clear GMS` |
| 2 | `b0e0d2b1` | sesi ini | ✅ Fix | Pola identik; fix <1 menit langsung ke 3 perintah inti |
| 3 | `b0e0d2b1` | sesi ini | ✅ Fix (kambuh) | **Kambuh setelah GMS ter-update** → fix ulang + pasang pencegahan permanen (vending dinonaktifkan) |

*Update tabel di atas untuk setiap case baru.*
