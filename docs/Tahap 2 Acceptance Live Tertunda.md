# Tahap 2 — Acceptance Live yang Ditunda

**Status per 7 Oktober 2026:** Ditunda atas keputusan proyek. Implementasi dan
pengujian otomatis sisi Flutter sudah selesai, tetapi exit gate live belum
PASS. Dokumen ini menjadi daftar kerja yang wajib diselesaikan sebelum release
candidate, bukan alasan untuk menahan pekerjaan Tahap 3.

## Prasyarat

- Akun employee aktif dengan `employeeId`, `companyId`, permission absensi,
  kalender kerja, shift, cabang, lokasi/geofence, dan kebijakan selfie aktif.
- Akun sudah memiliki enrollment wajah production yang dikenali backend.
- Build staging Android dan iOS menunjuk server yang dapat dijangkau perangkat.
- Dua jaringan tersedia untuk pengujian perpindahan koneksi.
- Backend dapat menyediakan fixture shift biasa dan shift malam yang masih
  terbuka kurang dari 36 jam.

## Matriks Acceptance

- [ ] Android: check-in satu kali, respons server sukses, dan record yang sama
  tampil pada `/attendance/me/today` serta `/attendance/me`.
- [ ] Android: check-out satu kali untuk record terbuka; tidak ada selfie pada
  payload check-out dan history menampilkan waktu pulang yang sama.
- [ ] iOS: ulangi check-in/check-out serta verifikasi today/history.
- [ ] Tutup paksa dan buka kembali aplikasi setelah check-in; tombol tetap
  mengikuti `canCheckIn`/`canCheckOut` dari server tanpa membuat record baru.
- [ ] Pindah Wi-Fi ke seluler saat flow berjalan; retry aman tidak menggandakan
  mutation dan memakai idempotency key percobaan yang sama.
- [ ] Selfie wajah berbeda ditolak dan tidak menghasilkan record absensi.
- [ ] Kegagalan face match berulang menghasilkan state rate-limit yang benar.
- [ ] Lokasi di dalam geofence diterima; lokasi di luar geofence dan fake GPS
  ditolak tanpa menampilkan sukses palsu.
- [ ] Shift malam dapat di-check-out terhadap open attendance maksimal 36 jam,
  termasuk setelah tanggal perangkat berganti.
- [ ] Double tap atau replay request tidak membuat dua record.
- [ ] Kamera/lokasi ditolak, timeout, dan server 5xx menampilkan recovery yang
  jujur serta menawarkan koreksi absensi bila kegagalan tidak dapat dipulihkan.

## Bukti yang Harus Disimpan

Untuk setiap skenario catat platform, model/OS, build number, akun/role tanpa
credential, waktu server/timezone, correlation ID, status HTTP, hasil UI, ID
record, dan tautan screenshot/video. Jangan menyimpan token, password, selfie,
atau koordinat presisi dalam report.

## Kriteria Penutupan

Tahap 2 baru boleh dinyatakan PASS apabila seluruh kotak di atas selesai pada
Android dan iOS, record tidak terduplikasi, serta nilai today/history konsisten.
Jika ada skenario gagal, catat defect dan owner pada report Tahap 2 sebelum
melanjutkan release candidate.
