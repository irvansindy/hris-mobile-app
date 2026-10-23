# Tahap 7: Acceptance dan Release Gate Tertunda

Tanggal: 11 Oktober 2026. Dokumen ini melengkapi report Tahap 7; bukan izin go-live.

## Gate yang harus diselesaikan

- [ ] Jalankan GitHub Actions pada commit final dan simpan run URL untuk quality, Android release-validation/integration, dan iOS unsigned build. Konfigurasi workflow dan test YAML tidak membuktikan remote CI PASS.
- [ ] Validasi iOS native pada macOS: dependency resolution, build unsigned, permission prompt, lifecycle, sensitive screen, screenshot/recording, dan restart. Host pengujian saat ini Linux.
- [ ] Putuskan accessibility Keychain device-only dan migrasi token/template iOS, termasuk kebutuhan reinstall, logout, serta recovery. `synchronizable:false` tidak cukup membuktikan kebijakan no-migration.
- [ ] Uji backup cloud dan transfer Android pada perangkat/OEM target. Cross-platform transfer Android 36.1+ memerlukan bundle/team ID nyata; jangan membuat identifier fiktif atau menyamakan hasil source test dengan acceptance transfer.
- [ ] Audit dependency native Gradle/Swift/CocoaPods dan ulangi OSV saat lockfile berubah. Hasil 188 package Pub bukan audit supply-chain menyeluruh.
- [ ] Selesaikan warning KGP `firebase_core` melalui versi upstream yang kompatibel dan test ulang SDK/AGP yang dipilih. Jangan menyembunyikan warning atau memodifikasi pub cache.
- [ ] Tetapkan SDK release yang didukung dan review dependency/action CI sebelum signing secrets dipasang. Pin master saat ini mencocokkan verifikasi lokal, bukan persetujuan tooling go-live.
- [ ] Sebelum Firebase nyata diaktifkan, hapus konflik kepemilikan cleanup token legacy dengan push coordinator, lalu test logout/pergantian akun saat cleanup lambat. Firebase nyata tetap ditunda.
- [ ] Ukur Flutter first-frame, frame-time/jank, stabilitas memori, APK per ABI/AAB/IPA, serta battery kamera/GPS pada perangkat low/mid-range yang disepakati. Tentukan threshold bersama QA/Product dan catat build/configuration.
- [ ] Finalisasi privacy policy, consent biometrik/lokasi/selfie, retensi server, mekanisme penghapusan, Google Play Data Safety, dan Apple App Privacy bersama owner backend/legal. Disclosure kamera yang diperbaiki belum menggantikan dokumen tersebut.
- [ ] Jalankan acceptance attendance live yang ditunda pada Tahap 2: akun attendance aktif, HTTPS valid, restart, pindah jaringan, face mismatch, geofence, dan shift malam 36 jam.

## Cara menutup gate

Setiap checklist membutuhkan tanggal, commit/build, perangkat/OS, mode demo atau server, langkah reproduksi, hasil aktual, artifact yang sudah disanitasi, serta owner persetujuan. Jangan memasukkan password, access token, PIN, template wajah, atau selfie karyawan ke report/Git.

Android artifact validasi saat ini memakai app ID lama dan debug signing. Endpoint `https://ci.invalid/api/v1` hanya untuk kompilasi guard production, bukan staging. Konfigurasi final mengikuti Tahap 8 setelah HTTPS, app ID, signing, dan Firebase tersedia.
