# Tahap 6: Push Notification dan Deep Link

Tanggal pengujian: 10 Oktober 2026. Status: implementasi dan verifikasi lokal selesai; exit gate push live belum selesai. Firebase nyata tetap ditunda sesuai keputusan pengguna.

## Cakupan yang diselesaikan

- Kontrak pagination inbox dan registration device token, termasuk installation identity persisten.
- Adapter dummy khusus debug, registration lokal, permission simulasi, token rotation, failure/retry, dan isolasi sesi.
- Shared inbox: list, unread count, read, read-all, delete, refresh, serta load-more.
- Resolver tap dengan allowlist resource, pemeriksaan sesi, deduplikasi, dan fallback inbox. Payload bukan otorisasi untuk membuka data.
- Simulator foreground, opened, dan initial event. Tombol ini tidak menguji delivery OS atau Firebase.

## Review akhir dan perbaikan

Review independen menemukan 0 critical dan 2 important. Keduanya diperbaiki melalui regression test yang gagal sebelum perbaikan, lalu lulus:

1. Delete menggeser offset pagination sehingga item terakhir dapat terlewat. Load berikutnya dimulai kembali dari halaman pertama. Test mencakup 51/101 item, reload gagal, dan retry tanpa menghidupkan kembali item terhapus.
2. Initial dan opened event tanpa ID dapat membuka route dua kali. Latch satu event turn menahan duplikat dalam batch yang sama; tap berikutnya tetap dapat diproses.

Click-through emulator juga menemukan tombol Kembali tidak bekerja saat inbox menjadi root route. Routing kini kembali ke Home jika tidak ada halaman sebelumnya; regression test memakai aplikasi/router sebenarnya.

## Bukti pengujian lokal

| Pemeriksaan | Hasil |
| --- | --- |
| Format `lib test tool integration_test` | PASS, 274 file, 0 perubahan |
| `rtk flutter analyze` | PASS, 0 issue |
| Notification dan safety tests | PASS, 88 test |
| `rtk flutter test` | PASS, 619 test termasuk golden |
| `rtk flutter build apk --debug` | PASS, APK debug berhasil dibangun |
| Emulator demo | PASS untuk simulator lokal dan tampilan inbox |
| Emulator non-demo dengan `PUSH_MODE=dummy` | Build/install PASS; acceptance inbox terautentikasi TERTUNDA, login mendapat HTTP 401 |

Perangkat virtual: Pixel_10a, Android 17/API 37, software GPU. Pengujian emulator bukan acceptance perangkat fisik atau bukti performa production. Tidak ada golden yang diperbarui dalam Task 5. Hasil ini berasal dari checkout aktif dengan perubahan tahap sebelumnya; remote CI dan clean-checkout integration belum dinyatakan PASS.

Click-through demo mencakup foreground, tap/initial tanpa ID, rotation, permission deny/allow, registration failure/retry, input notification ID, fallback inbox, read-all, filter kosong, dan inbox light/dark. Route resource serta delete/retry pagination diverifikasi otomatis; delivery background/terminated OS tidak diuji.

Bukti visual: [registration gagal, light](evidence/stage6-push/demo-failure-light.png), [inbox dark](evidence/stage6-push/demo-inbox-dark.png).

Warning build `firebase_core` tentang Kotlin Gradle Plugin masih muncul. Build tetap berhasil; kompatibilitas plugin dengan Flutter berikutnya perlu ditinjau terpisah. Tidak ada key Firebase palsu, initialization Firebase baru, dependency baru, atau POST token dummy ke server.

## Menjalankan pengujian ulang

```bash
rtk flutter run --dart-define=DEMO_MODE=true
rtk flutter run --dart-define-from-file=.env --dart-define=PUSH_MODE=dummy
rtk flutter test test/features/notifications test/features/safety
rtk flutter test
rtk flutter build apk --debug
```

Perintah kedua memakai repository server untuk data dan simulator lokal untuk push; membutuhkan akun valid. `PUSH_MODE` default `disabled`. Dummy ditolak pada profile/release. Konfigurasi HTTP hanya untuk pengembangan, bukan izin release.

## Keputusan implementasi dan konsekuensi

Panduan ponytail dipakai untuk membatasi perbaikan pada mekanisme yang sudah ada, tanpa SDK baru. Antislop menjaga label simulasi dan klaim pengujian tetap jujur; desain shared light/dark dipertahankan.

| Keputusan | Konsekuensi |
| --- | --- |
| Gunakan checkout aktif yang disetujui | Stage hanya hunk milik task; integrasi clean checkout masih diperlukan |
| Installation identity asynchronous | Coordinator harus menunggu persistence berhasil |
| Tidak menyertakan perubahan demo/parity tahap sebelumnya | Prasyarat tersebut harus diintegrasikan sebelum CI clean checkout |
| Registry disabled menolak mutation | Coordinator harus melewati registration pada mode disabled |
| Lifecycle mengamati auth readiness dan sesi | Adapter Firebase mendatang harus memakai coordinator yang sama |
| Tutup listener router dan periksa status alive | Tambahan guard diperlukan saat router lama dibuang |
| Delete registration gagal menahan registration baru | Push berstatus gagal sampai retry; login/inbox tetap bisa digunakan |
| Komposisi auth/push di lapisan app | Satu file komposisi tambahan; feature tidak saling mengimpor |
| Dengarkan hint sebelum auth, terpisah dari registration | Adapter live harus mengirim initial hint setelah subscription tersedia |
| Navigasi push tidak otomatis menandai read | Resource yang dibuka via push tetap unread sampai dibaca di inbox |
| Invalidate hanya provider yang sudah dibuat | Inbox tidak aktif baru fetch saat dibuka |
| Rebase pagination setelah delete | Load berikutnya reload halaman pertama, bukan mempertahankan seluruh halaman lama |
| Latch event anonim hanya satu event turn | Duplikasi antar-turn tanpa ID tidak dapat dipastikan sebagai event yang sama |
| Kembali ditentukan di router | Widget tetap bebas dependency GoRouter |
| Firebase/APNs/OS acceptance ditunda | Belum layak menyatakan push production siap release |
| Snapshot credential untuk cleanup adapter remote ditunda | Validasi privacy/offline logout wajib saat adapter live dibuat |
| Dirty-checkout integration tidak masuk review commit ini | Hasil lokal tidak membuktikan remote CI hijau |
| Pertahankan checkout master dan scratch saat handoff | Tidak ada push, merge, atau penghapusan otomatis; integrasi/cleanup menunggu pilihan pengguna |

Tidak ada minor finding reviewer yang ditunda. Tiga batas cakupan reviewer (delivery live, remote cleanup credential, integrasi perubahan checkout sebelumnya) dicatat di atas, bukan dianggap PASS.

Daftar acceptance tersisa: [Acceptance Push Live Tertunda](Tahap%206%20Acceptance%20Push%20Live%20Tertunda.md).
