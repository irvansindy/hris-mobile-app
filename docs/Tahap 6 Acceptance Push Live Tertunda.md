# Tahap 6: Acceptance Push Live Tertunda

Tanggal: 10 Oktober 2026. Dummy lokal telah diuji; Firebase nyata belum tersedia. Checklist ini adalah syarat kelanjutan live, bukan kegagalan simulator.

## Prasyarat partner dan backend

- [ ] HTTPS staging yang dapat diakses Android/iOS.
- [ ] Akun employee/manager valid dan data notification/resource untuk acceptance. Percobaan login emulator non-demo mendapat 401; akses host tanpa autentikasi ke `/auth/me` juga mendapat 401, sehingga host merespons tetapi inbox terautentikasi belum diuji.
- [ ] App ID/bundle ID environment yang disepakati.
- [ ] Firebase Android/iOS resmi, APNs credentials, dan konfigurasi platform sesuai app ID.
- [ ] Payload server memiliki notification ID stabil dan resource type/ID yang sesuai kontrak; tanpa URL route arbitrer.

## Implementasi live berikutnya

- [ ] Tambahkan adapter Firebase dan bootstrap menggunakan konfigurasi resmi; pertahankan coordinator/resolver yang sudah diuji.
- [ ] Register token nyata melalui `/notifications/device-tokens` setelah sesi siap; verifikasi scope account/company dan idempotency.
- [ ] Delete registration dengan credential/scope asal saat logout; tetapkan perilaku offline/retry tanpa mengikat token lama ke akun baru.
- [ ] Hubungkan permission OS, token refresh, opened/initial message, dan error nyata. Dummy tidak boleh menjadi fallback diam-diam.
- [ ] Review warning KGP `firebase_core` dan platform compatibility sebelum upgrade/build release.

## Acceptance Android/iOS

- [ ] Foreground, background, terminated, restart, dan reinstall dengan delivery nyata.
- [ ] Permission denied, granted, revoked di Settings, serta activation retry.
- [ ] Rotation token dan logout offline/online; registration lama tidak menyisakan akses akun.
- [ ] Pergantian account/company saat lookup/tap sedang berjalan; stale event tidak membuka data sesi baru.
- [ ] Duplicate event dengan/tanpa ID, resource hilang, unsupported type, dan resource lintas tenant.
- [ ] Inbox pagination setelah delete, unread/read-all, jaringan berubah, timeout, dan retry.
- [ ] Deep link memerlukan auth dan pemeriksaan akses backend; pending intent tidak bertahan setelah logout.
- [ ] Lock screen/privacy payload, log, secure storage, dan screenshot sesuai kebijakan.
- [ ] Build iOS, Android release, signing, clean-checkout CI, serta staging UAT.

## Status release

Belum PASS untuk push live. Simulator initial/background hanya event lokal; tidak membuktikan delivery Firebase/APNs atau perilaku OS. Jangan menyertakan token, password, PIN, atau private key dalam report acceptance. Update setiap checklist dengan tanggal, platform/build, skenario, dan bukti hasil setelah dijalankan.
