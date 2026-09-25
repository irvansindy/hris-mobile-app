# Pengujian demo lokal HRIS

Tanggal: 24 September 2026.

Mode demo menggunakan `HrmsApp`, router, shell, serta seluruh layar asli aplikasi: Beranda, Absensi, Kalender, Profil, pengajuan, dan menu lainnya. Tidak ada shell demo terpisah. Transaksi absensi, cuti, izin, dan saldo cuti memakai data lokal. Kalender dan profil memakai data presentasi lokal agar struktur layar sesuai referensi HTML. Banner DEMO menandai sumber data. Menu di luar cakupan tetap tersedia sesuai hak akses employee, tetapi requestnya menghasilkan pesan lokal belum disimulasikan, tanpa menghubungi backend. Ini bukan fallback otomatis ketika API gagal.

## Menjalankan

```sh
flutter run --dart-define=DEMO_MODE=true
```

Membuat APK untuk perangkat:

```sh
flutter build apk --debug --dart-define=DEMO_MODE=true
```

APK berada di `build/app/outputs/flutter-apk/app-debug.apk`. Mode demo hanya boleh berjalan pada build debug. `flutter run` tanpa flag tetap menjalankan aplikasi dengan backend. Instalasi memakai application ID yang sama; data demo memiliki namespace terpisah. Tidak ada migrasi atau sinkronisasi data demo ke backend.

## Perilaku data

- Satu akun sintetis: Karyawan Demo, DEMO001. Pertama kali langsung masuk. Setelah logout, gunakan layar Login asli dengan `demo@example.test` / `Demo123!`. Logout demo tidak menyentuh kredensial backend.
- Data transaksi disimpan sebagai JSON pada key preferences `hris.demo.v1` dan bertahan setelah tutup paksa/restart.
- Tidak ada request jaringan dalam alur demo. GPS tidak diambil. Waktu mengikuti perangkat.
- Contoh awal: satu record hadir, satu record telat, satu cuti disetujui dua hari, serta satu izin disetujui. Tanggal relatif terhadap inisialisasi/reset.
- Kuota cuti 12 hari; contoh cuti mengurangi dua hari sehingga saldo awal 10 hari.
- Pengajuan baru berstatus Menunggu; cuti menunggu mencadangkan saldo. Persetujuan simulasi memotong saldo sekali. Pembatalan pengajuan menunggu membebaskan cadangan. Izin tidak memotong saldo cuti.
- Durasi pengajuan dihitung Senin–Jumat, tanpa kalender hari libur. Rentang terbalik, akhir pekan saja, alasan kosong, tanggal tumpang tindih, dan saldo tidak cukup ditolak.
- Absensi satu record per tanggal; checkout memperbarui record yang sama. Setelah selesai tidak dapat check-in lagi pada tanggal yang sama. Reset demo untuk mengulang skenario.
- Shift demo mulai 08:00. Masuk pada/setelah 08:00 ditandai Telat. Contoh telat juga tersedia pada riwayat awal.
- Beranda mengikuti susunan HTML: tim, shift, heatmap, dan saldo cuti berbentuk donut. Tim, shift, heatmap, serta pengumuman diberi label contoh; angkanya tidak dihitung dari absensi pribadi dan tidak dikirim ke server. Saldo cuti tahunan berasal dari transaksi lokal. Cuti sakit dan izin pada legenda hanya contoh presentasi, bukan kuota yang bisa diajukan.
- Grafik tiga bulan pada Absensi adalah contoh presentasi. Statistik telat dan rata-rata masuk dihitung dari riwayat lokal bulan berjalan; lembur ditampilkan `--` karena belum ada simulasi lembur.
- Pengajuan demo mengikuti layout referensi: dua kartu aksi, filter kategori satu baris, dan riwayat ringkas. Jumlah aktif/selesai dihitung hanya dari transaksi lokal cuti/izin. Contoh lembur dan reimbursement bersifat baca-saja, ditandai “Contoh” dan dijelaskan dalam detail; tidak masuk hitungan transaksi maupun tersimpan di JSON.
- Agenda Kalender dan rincian tambahan Profil adalah contoh presentasi. Kalender contoh tidak menjadi acuan validasi tanggal cuti atau hari libur.

## Face ID dan foto wajah lama

Profil asli menyediakan tombol `Pengujian demo · Face ID`, hanya dalam mode demo. Dari sana, `Setup Face ID demo` membuka kamera depan layar penuh untuk memeriksa satu wajah, posisi, jarak, dan pose. Aplikasi memandu wajah lurus, putar kiri, lalu putar kanan. Setiap sudut diambil otomatis setelah pose stabil sekitar 750 ms dan tiga sampel langsung disimpan ke secure storage per employee/company/device. Tidak ada tombol ambil atau simpan manual. Foto mentah tidak disimpan dan data ini tidak dapat mencocokkan identitas. Foto wajah demo dari versi lama tetap berada pada key secure storage `hris.demo.face.v1` hingga pengguna menghapusnya atau me-reset demo. Persetujuan simulasi cuti dan reset tetap tersedia.

Catat masuk dan catat pulang demo sekarang memerlukan enrollment untuk employee/company/perangkat aktif, lalu membuka kamera depan layar penuh. Catatan absensi baru disimpan setelah satu wajah lolos validasi jumlah wajah, posisi, jarak, dan pose serta pengguna memilih `Lanjutkan absensi`. Menutup kamera, menekan kembali, data enrollment tidak ada/rusak, atau validasi kamera gagal tidak menyimpan absensi.

Deteksi wajah belum menghasilkan embedding, memeriksa liveness, atau mencocokkan identitas. Karena itu alur ini disebut validasi kamera demo, bukan face match. Lihat `docs/face-id/implementation-status.md` untuk batas tiap fase.

## Checklist perangkat

- [ ] Jalankan dengan flag demo, aktifkan mode pesawat; layar tetap dapat dipakai.
- [ ] Beranda: buka “Lihat semua” pada Tim Hari Ini; sheet menutupi tombol aksi cepat, dan tombol kembali setelah sheet ditutup.
- [ ] Pengajuan: dua kartu aksi, satu baris capsule Semua/Cuti/Lembur/Reimburse, dan riwayat ringkas sesuai desain. Filter status ada di kanan judul Riwayat; contoh lembur/reimburse bersifat hanya-baca dan detailnya menyatakan belum tersimpan sebagai transaksi lokal.
- [ ] Tanpa setup Face ID, tekan Catat masuk; absensi harus ditolak dan pesan setup muncul.
- [ ] Setelah setup, tekan Catat masuk; kamera memenuhi layar dan bottom navigation tersembunyi.
- [ ] Tutup kamera atau tekan kembali sebelum `Lanjutkan absensi`; record masuk tidak boleh dibuat.
- [ ] Validasi satu wajah lalu pilih `Lanjutkan absensi`; periksa waktu serta status Hadir/Telat.
- [ ] Catat pulang dengan alur kamera yang sama; ID record tetap sama dan waktu pulang terisi.
- [ ] Buka filter Semua/Hadir/Telat dan periksa record sesuai filter.
- [ ] Tutup paksa dan buka kembali; transaksi masih tersimpan.
- [ ] Ajukan cuti pada hari kerja yang belum dipakai; status Menunggu dan saldo cadangan bertambah.
- [ ] Buka Profil → Pengujian demo → Setujui; kembali ke Beranda, saldo berkurang sesuai hari kerja dan tidak terpotong dua kali.
- [ ] Buat pengajuan lain lalu batalkan; saldo cadangan kembali.
- [ ] Ajukan dan setujui izin; saldo cuti tidak berubah.
- [ ] Uji alasan kosong, tanggal bertumpuk, rentang akhir pekan, dan saldo tidak cukup.
- [ ] Profil → Pengujian demo → Setup Face ID: kamera memenuhi layar, bottom navigation tersembunyi, dan overlay tetap terbaca.
- [ ] Ikuti instruksi tengah, kiri, dan kanan tanpa menekan tombol apa pun; pastikan setiap tahap maju hanya setelah pose stabil.
- [ ] Setelah sudut kanan selesai, pastikan data tersimpan otomatis; tutup paksa aplikasi lalu periksa status setup masih tersimpan.
- [ ] Cek kamera depan, satu/dua wajah, posisi, jarak, pose, izin ditolak, background/resume, dan tutup kamera.
- [ ] Jika ada foto lama dari demo sebelumnya, hapus foto; foto tidak lagi terdeteksi setelah restart.
- [ ] Reset data demo dengan konfirmasi; transaksi kembali ke contoh awal dan foto dihapus.
- [ ] Jalankan kembali tanpa flag demo; alur login backend tetap terpisah.

## Pengujian otomatis

`flutter test test/demo test/architecture/dependency_rules_test.dart test/widget_test.dart test/features/attendance/attendance_screen_test.dart test/features/profile/profile_api_contract_test.dart`

Mencakup persistensi transaksi, masuk/keluar pada layar asli, duplicate submission, pergantian tanggal, saldo/cadangan, approval/cancel, validasi tanggal, isolasi namespace, dan pemblokiran jaringan untuk fitur di luar cakupan demo. Hasil test lokal bukan bukti face recognition atau GPS backend berhasil.

Hasil verifikasi 24 September 2026:

- `flutter test`: **403 test PASS**, termasuk urutan otomatis tengah-kiri-kanan, reset saat pose tidak stabil, gating absensi demo saat enrollment tidak ada, pembatalan kamera, submit setelah validasi kamera, tes kualitas wajah, verifikasi fail-closed, isolasi template, dan persistensi enrollment demo.
- Analyzer pada modul yang diubah: tidak ada issue. Analyzer seluruh proyek masih melaporkan tujuh info deprecation `GlobalMaterialLocalizations` dari versi Flutter yang dipakai; tidak ada error atau warning analyzer.
- `flutter build apk --debug --dart-define=DEMO_MODE=true`: PASS, APK berhasil dibuat.
- Build masih menampilkan warning migrasi KGP `firebase_core`; tidak menggagalkan APK.
- Test perangkat fisik, kamera native, dan persistensi secure storage native: belum dijalankan; gunakan checklist di atas.
