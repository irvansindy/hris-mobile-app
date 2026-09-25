# Status implementasi Face ID Flutter sampai Phase 7

Tanggal: 24 September 2026.

| Fase | Status | Bukti / sisa pekerjaan |
| --- | --- | --- |
| 0 Arsitektur | Selesai untuk Flutter | `current-architecture.md`; backend tidak diverifikasi. |
| 1 Deteksi wajah | POC terpasang | Kamera depan, preview, frame stream, single-face, pose, permission/lifecycle/error. Uji perangkat fisik belum selesai. |
| 2 Kualitas | Parsial | Ukuran, pusat, yaw/pitch/roll configurable. Blur dan pencahayaan belum dinilai oleh model/sensor yang tervalidasi. |
| 3 Embedding | Tertahan | Model TFLite, preprocessing, tensor shape, lisensi, dan model version belum tersedia. Tidak ada embedding palsu. |
| 4 Similarity | Fondasi teruji | Cosine similarity dan result tersedia; threshold wajib terkalibrasi, sehingga verifikasi nyata fail-closed. |
| 5 Enrollment | Demo metadata lokal | Kamera layar penuh mengambil otomatis tiga sudut setelah pose stabil: tengah, kiri, kanan. Data langsung disimpan tanpa tombol capture/save. Data ini bukan face template dan tidak bisa digunakan untuk identity matching. |
| 6 Liveness | Tertahan | Belum ada model passive liveness atau threat model; gesture/face detection tidak diklaim anti-spoof. |
| 7 Secure local storage | Demo aktif, template nyata tertahan | Enrollment demo tersimpan terenkripsi dengan scope employee/company/device dan tiga sampel metadata tanpa foto mentah. Template embedding nyata tetap menunggu Phase 3–6. |

## Integrasi absensi demo

- Catat masuk dan pulang memeriksa enrollment lokal berdasarkan employee, company, dan perangkat aktif.
- Enrollment yang tidak ada, rusak, atau berbeda scope memblokir submit.
- Setelah enrollment ditemukan, kamera layar penuh mewajibkan satu wajah dengan posisi, jarak, dan pose valid.
- Hanya tombol `Lanjutkan absensi` setelah sampel valid yang meneruskan transaksi lokal. Kembali atau menutup kamera membatalkan.
- Hasil ini bukan identity match dan tidak dikirim sebagai `face_verified=true`. Phase 3 embedding, Phase 4 threshold terkalibrasi, dan Phase 6 liveness masih dibutuhkan untuk verifikasi wajah nyata.

## Yang dibutuhkan untuk mengaktifkan Face ID nyata

1. Model pengenal wajah mobile beserta lisensi, format input/output, preprocessing/alignment, dimensi embedding, dan nomor versi.
2. Dataset uji serta threshold similarity dan konsistensi enrollment yang dikalibrasi; angka tidak boleh ditebak.
3. Keputusan threat model dan metode liveness yang diuji terhadap foto, video, dan replay layar. Active challenge saja bukan jaminan keamanan produksi.
4. Persetujuan alur migrasi foto demo lama dan kontrak absensi backend baru. Setup demo hanya menyimpan metadata deteksi dan tidak membuat klaim identitas cocok.

## Uji manual Android

Masuk mode demo → Profil → Pengujian demo lokal → Setup Face ID demo. Pastikan kamera mengisi seluruh layar dan bottom navigation tidak muncul. Cek izin kamera ditolak, tanpa wajah, dua wajah, wajah terlalu jauh/dekat, wajah di tepi, dan pose miring. Ikuti urutan tengah, kiri, kanan; setiap tahap harus maju otomatis setelah stabil sekitar 750 ms. Setelah tahap kanan, data harus tersimpan otomatis. Tutup aplikasi lalu pastikan status setup masih tersimpan.

Setelah itu buka Absensi. Uji masuk dan pulang: kamera harus terbuka, tombol kembali tidak boleh menyimpan record, wajah invalid tidak boleh melanjutkan, dan record hanya tersimpan setelah sampel valid serta tombol `Lanjutkan absensi` ditekan.
