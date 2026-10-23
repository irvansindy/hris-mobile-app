# Tahap 2 — Absensi dan Face Recognition Production Path

Tanggal penyelesaian mobile otomatis: 6 Oktober 2026.

## Hasil Implementasi

- `GET /attendance/me/today` menjadi sumber wajib untuk `serverTime`,
  `serverDate`, `timezone`, `canCheckIn`, `canCheckOut`, record, dan metode
  absensi. Response tanpa eligibility lengkap atau dengan dua aksi aktif
  sekaligus ditolak sebagai kontrak tidak valid.
- Presentation menentukan tombol masuk/pulang dari eligibility server, bukan
  lagi dari tebakan atas record lokal. Status diambil ulang sebelum dan setelah
  mutasi.
- Check-in hanya mengirim metode, koordinat, `deviceGps`, dan
  `faceRecognition.selfieImage` ketika diwajibkan. Check-out tidak mengirim
  payload wajah. Keduanya memakai `Idempotency-Key`.
- Mock location dan akurasi di atas 100 meter dihentikan sebelum request.
  Permission, timeout, face mismatch, rate limit, dan penolakan server tidak
  pernah ditampilkan sebagai sukses.
- Submit paralel ditolak di controller. Aplikasi tidak mempunyai antrean punch
  offline.
- Checkout `404 NOT_FOUND` tidak diulang. UI menawarkan `Ajukan koreksi` dan
  membuka composer koreksi absensi.
- Validasi wajah multi-angle lokal tetap berasal dari override demo. Production
  mengambil selfie kamera dan menyerahkan face match kepada backend.

## Bukti Pengujian

- `rtk flutter analyze`: lulus, tanpa issue.
- `rtk dart format --output=none --set-exit-if-changed lib test tool integration_test`:
  lulus, tidak ada perubahan format.
- Test modul attendance: 30 test lulus.
- Full `rtk flutter test`: 450 test lulus, termasuk golden serta parity
  demo/production.
- Contract test memverifikasi schema `/today`, payload selfie yang dibatasi,
  payload checkout tanpa wajah, dan identity yang tidak dikirim klien.
- Controller/widget test memverifikasi eligibility, duplicate submit, server
  rejection, permission lokasi, selfie wajib, dan fallback koreksi.

## Acceptance yang Masih Terbuka

- Check-in dan check-out nyata pada Android serta iOS.
- Restart aplikasi setelah check-in, lalu verifikasi state dari server.
- Pergantian Wi-Fi/data seluler ketika mengambil lokasi dan mengirim request.
- Skenario server: fake GPS, face mismatch, rate limit lima kegagalan, luar
  geofence, shift malam/open checkout 36 jam, dan idempotency replay.
- Konfirmasi record yang sama tampil konsisten pada `/attendance/me/today` dan
  `/attendance/me`.

Tahap 2 belum memenuhi exit gate live sampai pengujian di atas dijalankan
dengan akun employee yang memiliki kalender kerja, cabang, kebijakan lokasi,
dan profil wajah aktif.
