# Tahap 6 Task 2: Adapter Dummy dan Konfigurasi Debug

Tanggal: 9 Oktober 2026
Status pengujian lokal: PASS
Status Firebase/delivery OS: belum diaktifkan

## Hasil Implementasi

- `PUSH_MODE=disabled` menjadi default. `dummy` hanya tersedia pada debug; konfigurasi profile/release menolaknya walaupun BASE_URL sudah HTTPS. Mode yang tidak dikenal juga ditolak.
- Provider mengikuti `demoModeProvider` yang sudah dipasang oleh demo overrides. Demo memilih dummy; debug dengan repository production bisa memilih dummy secara eksplisit. Tidak perlu mengubah file demo yang berisi pekerjaan lama.
- Adapter disabled tidak meminta permission OS, tidak menghasilkan token/event, dan tidak memanggil Firebase. Registry disabled menolak mutation agar caller tidak menerima konfirmasi registration palsu.
- Adapter dummy menyediakan permission simulasi, token sementara, rotation, penghapusan token, serta event foreground/opened/initial. Event hanya membawa ID dan kind, tanpa title/body/URL.
- Permission denied tetap denied sampai simulator mengubahnya. Dispose menutup streams, membersihkan token, dan mengabaikan callback simulasi setelah disposal.
- Registry dummy menyimpan binding hanya di memori, dengan switch failure register/unregister untuk pengujian berikutnya. Provider dummy tidak memilih repository Dio atau mengakses network. Tidak ada key Firebase palsu, dependency baru, persistensi token, atau logging payload.

## Bukti Pengujian

Test awal gagal karena interface adapter belum tersedia. Setelah field konfigurasi tersedia, tiga test perilaku masih gagal: pemilihan dummy, penolakan dummy pada profile/release, dan penolakan mode tidak valid. Ketiganya lulus setelah parser dan guard diterapkan.

- `rtk flutter test test/features/notifications/push_adapter_test.dart test/core/app_config_test.dart test/features/safety test/core/transport_configuration_test.dart`: 33 test lulus.
- Provider diuji dengan Dio yang melempar error jika diakses; operasi dummy tetap berhasil. Handler channel Firebase yang dipantau tidak menerima panggilan. Source adapter/provider tidak mengimpor SDK Firebase.
- Demo overrides yang sebenarnya diuji memilih adapter dan registry dummy meskipun konfigurasi push default disabled.
- `rtk flutter test`: 584 test lulus, termasuk golden, pada checkout aktif.
- `rtk flutter analyze`: 0 issue.
- `rtk dart format --output=none --set-exit-if-changed lib test tool integration_test`: 267 file, 0 perubahan.
- `rtk git diff --check`: tidak ada whitespace error.

## Cara Menjalankan dan Batasan

```bash
rtk flutter run --dart-define=DEMO_MODE=true
rtk flutter run --dart-define-from-file=.env --dart-define=PUSH_MODE=dummy
```

Task ini menyiapkan dependency adapter/registry. Belum ada coordinator app-scoped, hook login/logout, status panel, atau tombol simulator di layar. Integrasi lifecycle merupakan Task 3; routing terverifikasi dan simulator UI merupakan Task 4. Menjalankan perintah di atas belum membuktikan push atau navigasi baru bekerja.

Permission Android/iOS nyata, Firebase/APNs, background/terminated OS, dan delivery server tetap belum diuji. Event initial pada dummy hanya simulasi dalam memori. Build APK baru dan final review lintas-task masuk Task 5.

Perubahan tahap sebelumnya tetap dipertahankan di working tree. Hasil ini belum membuktikan remote CI atau clean checkout seluruh roadmap.
