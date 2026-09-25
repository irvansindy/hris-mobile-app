# Face ID: arsitektur saat ini

Tanggal audit: 24 September 2026. Cakupan pemeriksaan ini adalah workspace Flutter. Implementasi dan database Laravel tidak diverifikasi dalam audit ini.

## Flutter

- Aplikasi memakai Riverpod, `GoRouter`, dan shell navigasi utama. Login memulihkan `AuthSession` yang membawa employee/company. Request API memakai `RequestContext` dari sesi aktif.
- Absensi menggunakan `AttendanceScreen` → `AttendanceController` → `ClockIn`/`ClockOut` → `AttendanceRepository` → `DioAttendanceRemoteDataSource` → `/attendance/me/check-in` atau `/attendance/me/check-out`.
- `GET /attendance/me/today` memuat record dan kebijakan absensi. GPS diambil saat perintah dibuat; server menetapkan waktu dan record final.
- Jalur lama `requiresSelfie` memakai `image_picker` satu foto. Ini bukan deteksi, enrollment, face matching, atau liveness. Payload `isLiveCapture: true` yang sebelumnya dikirim telah dihapus karena tidak memiliki bukti.
- Demo lokal memakai `DemoStore` untuk transaksi dan `DemoFaceStorage` untuk foto contoh. Foto lama tidak menjadi template Face ID dan tidak digunakan untuk verifikasi.
- `flutter_secure_storage` sudah tersedia. `FaceTemplateStore` baru memakai namespace terpisah dan membatasi template per employee, company, serta ID instalasi lokal. ID ini belum menjadi device binding terdaftar di server. Tidak ada foto mentah di template baru.

## Platform dan dependensi

- Flutter 3.49.0 pre / Dart 3.14.0 dev pada lingkungan pengembangan ini.
- Android sudah meminta izin kamera. iOS memiliki deklarasi kamera; target project disesuaikan ke iOS 15.5 karena syarat ML Kit, tetapi Podfile tidak ada dalam checkout ini sehingga build iOS belum diverifikasi.
- `camera` dan `google_mlkit_face_detection` ditambahkan untuk POC deteksi. `image_picker` tetap digunakan oleh jalur selfie lama dan fitur lain.
- Tidak ditemukan asset model pengenal wajah `.tflite` maupun hasil kalibrasi threshold dalam repo/dokumen yang diperiksa.

## Titik integrasi dan konflik

1. `FaceDetectionScreen` membaca frame kamera depan dalam tampilan layar penuh dan menilai satu wajah, jarak, posisi, serta pose. Mode enrollment demo menjalankan state machine tengah, kiri, kanan. Setiap sudut harus stabil sekitar 750 ms sebelum diambil otomatis; perpindahan atau pose salah mereset progres tahap aktif. Setelah tiga sudut selesai, metadata langsung disimpan terenkripsi tanpa foto mentah. Mode absensi demo memerlukan enrollment dengan scope employee/company/device yang sama dan satu sampel kamera valid sebelum transaksi lokal dapat dilanjutkan. Deteksi dan metadata tersebut tidak mengidentifikasi orang.
2. `FaceTemplateStore` siap menyimpan beberapa embedding yang sudah dihasilkan model, tetapi belum ada model inference atau enrollment yang dapat menghasilkan embedding tersebut.
3. `FaceVerificationConfig` menolak verifikasi tanpa model version, dimensi, dan threshold terkalibrasi. Liveness aktif/pasif juga belum ada; blink dari classifier kamera saja tidak cukup untuk klaim anti-spoof.
4. Backend Face ID, device binding, request signing, endpoint absensi wajah, geofence, dan server-time berada di Phase 8+ dokumen. Kontraknya belum dipasang dalam aplikasi ini.
5. Jalur selfie lama masih dapat mengirim foto ke endpoint absensi lama jika kebijakan server mewajibkannya. Label `FACE_RECOGNITION` pada kontrak lama tidak boleh dianggap bukti face match lokal. Migrasi/perubahan kontrak perlu disepakati dengan backend sebelum mengganti jalur produksi.

## Alur yang benar-benar berjalan sekarang

Produksi: Employee login → sesi Flutter → layar Absensi → kebijakan dan record hari ini → konfirmasi → GPS/selfie sesuai kebijakan → API absensi Laravel.

Demo lokal: sesi demo → layar Absensi → cek enrollment employee/company/device → kamera layar penuh → validasi satu wajah/posisi/jarak/pose → konfirmasi `Lanjutkan absensi` → transaksi lokal. Alur demo ini tidak menyatakan identity match atau liveness.
