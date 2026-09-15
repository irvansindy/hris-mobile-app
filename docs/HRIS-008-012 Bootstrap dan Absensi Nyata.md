# HRIS-008 sampai HRIS-012: Bootstrap dan Absensi Nyata

> **Kontrak endpoint diperbarui 12 September 2026.** Mobile sekarang memakai
> `/attendance/me/today`, `/attendance/me/check-in`, dan
> `/attendance/me/check-out`; identity serta waktu tidak lagi dikirim client.
> Rincian aktif ada di [API Integration Revision](<API_INTEGRATION_REVISION.md>).

Tanggal verifikasi lokal: 12 September 2026.

## Ringkasan hasil

Bootstrap sesi sekarang membedakan empat keadaan: belum login, wajib ganti kata
sandi, akun tanpa relasi employee/company, dan sesi ESS yang dapat membuka
shell. Data employee/company tetap berasal dari login dan `/auth/me`; aplikasi
tidak membuat ID fallback.

Absensi mobile sekarang memakai context, record, dan transaksi backend. Jalur
demo lokasi dan datasource absensi telah dihapus. Tombol hanya menampilkan
sukses setelah repository menerima dan memetakan record dari respons server.

## HRIS-008: bootstrap sesi

- Login mendukung challenge `MFA_REQUIRED`; field autentikator baru muncul
  setelah server meminta MFA dan `totp` dikirim pada percobaan berikutnya.
- `mustChangePassword` membuka gate khusus dengan validasi aturan password
  backend dan `POST /auth/change-password`.
- Setelah perubahan password berhasil, sesi lokal dibersihkan dan pengguna
  diminta login kembali karena backend merevoke refresh token.
- Akun tanpa `employeeId` atau company scope mendapat state terpisah dan tidak
  dapat membuka fitur ESS.
- Error autentikasi, rate limit, validasi, forbidden, dan jaringan tetap
  dibedakan oleh mapper. Source backend belum mendaftarkan route forgot/reset
  password, sehingga UI recovery palsu tidak ditambahkan.

## HRIS-009: kontrak absensi

Kontrak diverifikasi pada backend commit
`fa1d33cab5b39b2956c400cca046d73915933706`:

- `GET /attendance/context` untuk branch, jadwal, policy, metode, radius, dan
  warning hasil resolusi server;
- `GET /attendance` untuk menemukan record hari ini;
- `POST /attendance` untuk check-in;
- `PATCH /attendance/:id/checkout` untuk check-out.

Fixture test memeriksa query employee/company/date dan payload request, termasuk
metode, source, koordinat, accuracy, mock location, metadata GPS, selfie data
URI, serta request key.

## HRIS-010: GPS

`GeolocatorLocationService` menggantikan lokasi hardcode. Service memeriksa
status layanan dan permission, meminta posisi high accuracy dengan timeout 20
detik, serta membawa latitude, longitude, accuracy, timestamp, altitude,
heading, dan `isMocked`.

Use case menolak posisi mocked dan akurasi di atas 100 meter sebelum request
absensi. UI menampilkan pesan yang dapat ditindaklanjuti. Permanent denial
menawarkan tombol pengaturan aplikasi; service lokasi mati menawarkan
pengaturan lokasi.

Permission Android yang ditambahkan: fine/coarse location, camera, notification,
dan internet yang sudah ada. iOS mendapatkan usage description spesifik untuk
lokasi, kamera, serta galeri pada konfigurasi Debug dan Release/Profile.

## HRIS-011: selfie

Selfie diambil langsung dari kamera depan dengan `image_picker`, kualitas 72,
batas dimensi 1280 piksel, dan batas 5 MB. Byte foto dipertahankan di memori
untuk preview dan upload; file capture sementara dihapus setelah dibaca.
Pembatalan kamera tidak dianggap verified atau berhasil. Foto hanya dikirim
saat check-in dengan metode `FACE_RECOGNITION` yang diizinkan context.

Backend saat ini sengaja menolak seluruh face recognition dengan 503 sampai
reference profile retrieval, decoding, dan embedding server tersedia. Karena
itu implementasi mobile selesai untuk capture dan kontrak transport, tetapi
acceptance sukses selfie end-to-end masih diblokir backend. UI tidak menampilkan
label verified dan tidak mengubah penolakan menjadi sukses.

## HRIS-012: transaksi absensi

- Home tetap membuka tab Absensi; pencatatan hanya dilakukan oleh use case yang
  sama dengan layar Absensi.
- Context dan record hari ini diikat ke revision user/company sehingga hasil
  sesi lama tidak dapat muncul setelah logout atau pergantian akun.
- Check-in mengirim GPS nyata dan selfie bila policy mewajibkan. Check-out
  mencari record aktif dari server lalu mengirim waktu dan koordinat checkout.
- Loading mempertahankan record sebelumnya, tombol dinonaktifkan selama
  request, dan controller menolak double-submit.
- Empty, active, completed, server error, permission error, dan selfie preview
  memiliki state berbeda. Pull-to-refresh memuat ulang context dan record.
- Pesan sukses secara eksplisit menyebut record server dan hanya ditampilkan
  setelah hasil `Success<AttendanceEntity>`.

## Pengujian lokal

Test mencakup:

- gate wajib ganti password dan akun non-employee;
- challenge MFA, payload TOTP, kontrak change-password, logout setelah password
  berubah, dan confirmation pada login;
- parsing attendance context serta payload check-in/check-out;
- propagasi GPS dan selfie, mock location, serta accuracy lebih dari 100 meter;
- UI sukses setelah record server, penolakan server tanpa sukses palsu, selfie
  wajib, dan CTA permanent location denial;
- isolasi sesi lama serta guard data demo yang sudah ada.

Hasil final: analyzer bersih, seluruh 141 test lulus, dan App Bundle release
production berhasil dibangun.

## Batas dan task backend yang wajib dilanjutkan

HRIS-013 belum selesai dan tetap menjadi blocker operasional:

1. Server masih memakai timestamp `checkIn`/`checkOut` dari client, belum waktu
   penerimaan server yang otoritatif.
2. Backend belum menyimpan atau menegakkan `Idempotency-Key`; unique constraint
   per employee/tanggal tidak cukup untuk seluruh retry dan checkout.
3. Face recognition selalu fail-closed 503 karena pipeline biometrik tepercaya
   belum terhubung.
4. Penolakan fake GPS server belum konsisten untuk metode `MOBILE_GPS`; client
   tidak dapat menjadi trust boundary.
5. Belum ada akun uji dan device smoke test, sehingga permission OS, geofence,
   server live, kamera fisik, serta perilaku di luar radius belum terbukti.

HRIS-014 juga belum selesai: policy dan record hari ini sudah nyata, tetapi
riwayat paginated serta pengujian timezone kantor belum diintegrasikan.
