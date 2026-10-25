# QA-06: Pengujian Simulator iOS di CI

Status: disetujui pengguna untuk implementasi.

## Tujuan dan kondisi saat ini

Menambah bukti runtime iOS tanpa menunggu Mac/iPhone lokal. Build unsigned sudah
lulus pada CI PR #1, tetapi workflow belum menjalankan simulator atau XCTest.
Scheme `Runner` sudah menyertakan `RunnerTests`; isinya masih tes contoh kosong.
Proyek memakai integrasi Swift Package Manager Flutter, bukan Podfile.

Host lokal Linux tidak menyediakan Xcode. Bukti XCTest/simulator harus berasal
dari macOS CI, bukan disimpulkan dari tes Dart yang memock method channel.

## Pendekatan

1. **Pilihan pengguna: simulator pada CI macOS.** Gunakan fixture Flutter yang
   sudah ada dan XCTest bawaan untuk proteksi layar. Tidak memerlukan backend,
   Firebase resmi, certificate atau provisioning untuk perangkat fisik.
2. Menunggu Mac/iPhone: lebih sesuai untuk sensor dan acceptance perangkat,
   tetapi menunda pengujian runtime yang dapat dikerjakan sekarang. Tetap dipakai
   kemudian untuk bagian yang tidak dapat dibuktikan simulator.

## Scope implementasi yang diusulkan

- Pertahankan build unsigned yang ada. Tambahkan eksekusi simulator pada jalur
  macOS CI; pilihan awal implementer adalah memperluas job iOS yang sama untuk
  menghindari setup ganda. Jika batas waktu runner tidak cukup, evaluasi pemisahan
  job tanpa menonaktifkan pemeriksaan wajib.
- Pilih dan catat UUID, jenis perangkat, runtime iOS serta arsitektur simulator
  yang tersedia dan memenuhi deployment target proyek. Gagal secara jelas bila
  runtime yang kompatibel tidak ada; jangan melewati tes lalu mengklaim lulus.
- Jalankan `integration_test/redesign_flow_test.dart` yang sama: login fixture,
  navigasi, pengajuan, absensi berhasil/ditolak dan logout A ke B. Repository,
  lokasi dan preferensi fixture tetap sintetis; ini bukan absensi live.
- Ganti tes Swift contoh dengan pengujian perilaku `SensitiveScreenProtection`:
  cover muncul saat proteksi aktif dan scene inactive, hilang saat kembali
  aktif/dinonaktifkan, serta siklus berulang tidak menumpuk cover. Reset singleton
  dan window antar-tes; jangan menambahkan metode production khusus untuk tes.
- Simpan log, ringkasan hasil dan `.xcresult` yang relevan sebagai artifact CI,
  termasuk bukti kegagalan. Exit code gagal tetap menggagalkan job.
- Pertahankan backend dummy HTTPS, logging/push nonaktif dan data sintetis pada
  konfigurasi pengujian. Jangan memakai `.env` atau kredensial smoke live.

## Batas dan pengamanan

Tidak mengubah UI, endpoint, SDK pin, dependency, identitas aplikasi, signing,
Firebase partner atau kebijakan izin production sebagai bagian task ini.
Perubahan source native hanya jika diperlukan oleh defect yang dibuktikan tes,
dan dilaporkan terpisah dari penambahan coverage.

`pubspec.lock` dan Gradle wrapper memiliki perubahan lokal di luar task ini;
jangan ditimpa, direvert atau dipublikasikan otomatis. Implementasi diisolasi
dari baseline source CI yang telah lulus, dengan perubahan dokumentasi lokal
QA-05 juga tetap dipertahankan.

## Exit gate

Tes struktur workflow/tes Dart yang terdampak lulus lokal; XCTest dan dua fixture
flow benar-benar lulus pada simulator CI dengan run URL, SHA dan konfigurasi
runner tercatat. Tidak cukup hanya menambah YAML atau membuat build berhasil.

QA-06 keseluruhan tetap terbuka untuk kamera/selfie, izin lokasi aktual dan
perubahannya di Settings, push/APNs nyata, restart/restore storage perangkat,
app switcher/screenshot/recording pada perangkat, serta konfigurasi signed final.
Tes cover terkontrol tidak membuktikan pemblokiran screenshot statis atau bahwa
semua notifikasi lifecycle OS sudah teruji. Jika izin membuat PR lewat integrasi
masih 403, pembukaan PR manual tetap diperlukan sebelum menilai remote CI.
