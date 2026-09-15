# Laporan Tahap 4: RD-013 sampai RD-016

Tanggal: 15 September 2026.

Implementasi lokal fitur yang memiliki kontrak tersedia sudah dikerjakan berurutan. Tahap 5 belum dimulai dan menunggu persetujuan pengguna. Laporan ini bukan acceptance staging atau bukti push end-to-end.

## Ringkasan status

| Task | Hasil lokal | Acceptance yang masih terbuka |
|---|---|---|
| RD-013 Kalender | REVIEW: resolved self calendar, grid, tanggal, bulan/tahun, agenda, legend, refresh/retry | Timezone kantor/tanggal server, data cuti tim, fixture deployment |
| RD-014 Notifikasi | REVIEW: badge, inbox, filter, read/read-all, progressive limit, routing resource terbatas | Push BLOCKED; page/cursor belum dikontrak; smoke staging |
| RD-015 Pesan | DONE untuk keputusan scope: ikon chat membuka keterangan unavailable sesuai revisi pengguna | Implementasi chat hanya jika kontrak baru tersedia |
| RD-016 Profil | REVIEW: identitas/detail, permission, error/retry, metadata, tema, logout | Dokumen, atasan, push, pilihan bahasa penuh, smoke staging |

## Dasar implementasi

- Layout mengikuti struktur HTML `HRIS Mobile Redesign.html`, bukan sekadar warna/gaya. `support.js` tetap runtime prototipe, tidak dimasukkan ke Flutter.
- Kontrak endpoint mengikuti `mobile-api.md` final per 12 September 2026. Source backend lokal lama hanya digunakan untuk memeriksa bentuk respons sementara, bukan mengganti kontrak endpoint final.
- Skill antislop UI, mobile layout, human, dan copywriting menjaga state jujur, safe-area, tap target, serta copy Indonesia. Design Read: ESS Indonesia, `ENERGY 2 / RHYTHM 2 / MOTION 2`.
- Tidak ada akun uji live; pengujian tetap lokal sesuai arahan pengguna.

## RD-013 Kalender

`GET /work-calendars/me/resolved` hanya menerima query `year` dan `month`. Identity diturunkan server, bukan dikirim sebagai parameter employee/company.

- DTO memvalidasi employee aktif, periode, date-only yang benar, tanggal unik, dan kelengkapan satu bulan. Respons rusak tidak dianggap empty-success.
- Agenda menampilkan jadwal kerja/shift, pertukaran shift bila ditandai server, cuti/izin pribadi, serta hari tidak bekerja/libur.
- Grid Monday-first memakai bulan/tahun aktual; pemilihan tanggal memperbarui agenda. Perpindahan bulan/tahun dan Today bekerja.
- Legend dan dot muncul hanya dari data yang dimuat. Cuti pribadi tidak dipresentasikan sebagai cuti tim.
- Loading, unavailable/empty, error, permission, offline, retry, dan pull-to-refresh tersedia.
- Provider month diikat ke sesi; respons bulan lama tidak mengganti bulan yang sedang dipilih.
- Today berlabel `Hari ini (perangkat)`. Kontrak/source respons belum membawa timezone kantor atau tanggal server. Jadwal date-only tetap tidak bergeser karena timezone perangkat.

## RD-014 Notifikasi

- Badge Beranda memakai `GET /notifications/unread-count`. Count gagal/loading tidak ditampilkan sebagai angka nol palsu.
- Inbox memakai `GET /notifications?limit=50`. Muat lebih banyak menambah limit sebesar 50 dan mengambil ulang daftar terbaru. Tidak dibuat query page/cursor atau metadata pagination fiktif.
- Filter Semua, Belum dibaca, dan Approval bekerja pada daftar yang sudah dimuat. Approval dipetakan dari action karena enum type server adalah INFO/SUCCESS/WARNING/ERROR.
- Item dibaca melalui `PUT /notifications/read` dan read-all melalui `PUT /notifications/read-all`. Status lokal berubah hanya setelah server mengakui sukses; error tidak menghilangkan unread status.
- Badge diambil ulang setelah read/read-all, refresh inbox, atau pull-to-refresh Beranda.
- Mutasi diblokir saat busy, hanya ID dari inbox yang dapat dibaca, dan callback/respons terlambat tidak mengubah akun berikutnya.
- Payload user/company yang tidak sesuai ditolak jika field tersebut diberikan server. Otorisasi server tetap wajib; guard client bukan penggantinya.
- Resource allowlist: attendance ke Absensi, leave ke detail/list Pengajuan, permission-request ke Pengajuan, work-calendar ke Kalender. ID route harus aman. Resource lain membuka isi notifikasi dan memberi informasi bahwa detail terkait belum didukung.
- Tidak ada endpoint delete yang ditambahkan ke UI karena handoff tidak memiliki kontrol penghapusan.

Push belum dihubungkan: tidak ditemukan konfigurasi Firebase untuk aplikasi ini atau kontrak register/unregister token perangkat. Tidak dibuat endpoint registrasi rekaan, tombol push aktif palsu, atau klaim foreground/background/terminated lulus. Backend perlu mengirim kontrak token perangkat, payload identity/resource, dan konfigurasi Firebase; setelah itu diperlukan smoke test perangkat.

## RD-015 Scope Pesan

API final tidak menyediakan conversation list, message history, unread chat, send, attachment, atau realtime strategy. Pencarian source lokal juga tidak menemukan modul/registrasi device/chat terkait. Revisi pengguna setelah laporan Tahap 4 meminta ikon chat tetap terlihat. Ikon kini membuka dialog `Chat belum tersedia`, yang dapat ditutup melalui Tutup, Escape, atau dismiss standar Material. Tidak ada layar percakapan, conversation contoh, badge chat rekaan, atau cache pesan yang dibuat.

## RD-016 Profil dan Pengaturan

- Identitas sesi tampil segera. Detail `/employees/:id` hanya dipanggil bila permission `employee:read` tersedia; server tetap menentukan izin akhir.
- Employee ID respons harus cocok; company ID yang diberikan harus cocok dengan company aktif. Error jaringan/schema/permission tampil tanpa mengganti identitas sesi dengan data contoh.
- Kontak, department, position, branch/lokasi, dan join date ditampilkan hanya jika tersedia. Join date diperlakukan sebagai tanggal, bukan timestamp lokal yang dapat bergeser hari.
- Nominal salary tidak dipetakan ke state Profil. Slip gaji terlindungi tetap RD-017.
- Dokumen/atasan tidak dibuat dari prototipe; section dokumen memiliki unavailable state, bukan baris PDF/sertifikat palsu.
- Switch tema membaca brightness aktual, mengubah theme controller yang sama, dan menyimpan preferensi device. Logout tidak menghapus preferensi tema, tetapi menghapus sesi/state akun.
- Bahasa Indonesia berupa informasi read-only. Pemilihan bahasa serta push setting tidak diklaim aktif tanpa implementasi.
- Versi dan build number berasal dari `PackageInfo.fromPlatform()`, bukan nilai 1.4.0 prototipe. Penggunaan API mengikuti [dokumentasi package_info_plus 8.3.1](https://pub.dev/packages/package_info_plus/versions/8.3.1).

## Bukti pengujian

- Kontrak Kalender: self query, tahun kabisat, pergantian tahun, identitas/periode/tanggal tidak valid, respons gagal/tidak lengkap.
- Widget Kalender: tanggal/agenda, perpindahan bulan/tahun, Today, offline/retry, race bulan, Tab dan Enter, 320dp pada text scale 200%, light/dark.
- Notifikasi: kontrak GET/PUT, count/schema/identity mismatch, allowlist route, gagal read dan retry, account switch, filter/read-all 320dp 200% light/dark.
- Router: badge Beranda membuka inbox tanpa floating nav, baca item menyinkronkan badge, resource tidak didukung membuka sheet, Tutup dan Kembali berfungsi.
- Profil: mapping server/date-only, permission tanpa request terlarang, identitas tidak sesuai, error/retry, metadata build override, persistensi tema, menu unavailable.
- Regresi sebelumnya tetap mencakup logout/account switch, auth restore/refresh, absensi nyata, dan Pengajuan.
- Delapan golden 390 x 844 memakai font Plus Jakarta Sans, MaterialIcons, dan shadow sebenarnya, termasuk Beranda setelah revisi header/avatar. Semua data fixture dilabeli eksplisit; tidak ada fixture yang dimasukkan ke provider produksi. Golden screen fokus tidak menyertakan shell navigation; shell diuji terpisah.

Baseline visual fixture:

- [Beranda light](../test/goldens/stage4/home_fixture_light.png), [Beranda dark](../test/goldens/stage4/home_fixture_dark.png)
- [Kalender light](../test/goldens/stage4/calendar_fixture_light.png), [Kalender dark](../test/goldens/stage4/calendar_fixture_dark.png)
- [Notifikasi light](../test/goldens/stage4/notifications_fixture_light.png), [Notifikasi dark](../test/goldens/stage4/notifications_fixture_dark.png)
- [Profil light](../test/goldens/stage4/profile_fixture_light.png), [Profil dark](../test/goldens/stage4/profile_fixture_dark.png)

### Quality gate lokal sebelum revisi header/avatar

- `dart format --output=none --set-exit-if-changed lib test`: PASS, 153 file, tidak ada perubahan format tersisa.
- `flutter analyze`: PASS, tidak ada issue.
- `flutter test`: PASS, 210 test termasuk enam golden.
- `flutter build apk --debug`: PASS, menghasilkan `build/app/outputs/flutter-apk/app-debug.apk`.
- `flutter build web --release`: PASS, menghasilkan `build/web` untuk JavaScript.
- `git diff --check`: PASS.
- Gate antislop UI lokal: PASS, bukti per item di bawah. Tidak ada uji perangkat/staging/iOS atau push end-to-end yang diklaim lulus.

### Revisi header Beranda dan avatar, 15 September 2026

- Chat dan notifikasi selalu terlihat di kanan atas Beranda, termasuk saat layar dipakai standalone. Urutan chat lalu notifikasi mengikuti referensi pengguna. Tombol memakai surface theme, ikon outline, tap target minimal 44dp, dan gap 8dp.
- Avatar inisial Beranda (42dp) dan Profil (88dp) memakai `BoxShape.circle`. Instruksi terbaru pengguna tentang lingkaran menggantikan bentuk persegi membulat pada handoff gambar/HTML.
- Notifikasi produksi tetap membuka inbox yang sama dan memakai unread count server. Jika callback inbox tidak diberikan pada layar standalone, tombol menjelaskan bahwa inbox belum terhubung, bukan menjadi kontrol mati.
- Chat membuka dialog unavailable tanpa badge rekaan, percakapan contoh, atau panggilan API chat. Tutup dan Escape diuji pada light/dark dengan teks 200%.
- Test geometry 320 x 568 memeriksa urutan, jarak antartombol, ukuran target, batas kanan, dan avatar di bawah status-bar inset 30dp. Golden Beranda/Profil light dan Beranda dark juga diperiksa secara visual dari file lokal.
- `dart format --output=none --set-exit-if-changed lib test`: PASS, 154 file, 0 perubahan.
- `flutter analyze`: PASS, tidak ada issue.
- `flutter test`: PASS, 216 test termasuk delapan golden.
- `flutter build apk --debug`: PASS. Warning KGP `package_info_plus` yang sudah tercatat masih ada.
- `git diff --check`: PASS. Web/iOS/perangkat live tidak diuji ulang untuk revisi ini. Tahap 5 belum dimulai.
- Delivery Gate dan checklist skill di bawah diperiksa kembali untuk scope revisi: bentuk avatar mengikuti instruksi pengguna; tap target, spacing, safe-area, theme, keyboard, dan state unavailable diuji; tidak ada angka atau konten server rekaan.

## Click-through yang diuji

- Kalender: Bulan sebelumnya, Bulan berikutnya, tanggal, Today, Coba lagi; pull-to-refresh tersedia melalui repository yang sama.
- Notifikasi: Buka notifikasi, Tandai dibaca, Semua, Belum dibaca, Approval, item, retry, Muat lebih banyak, pull-to-refresh, sheet detail unavailable, Tutup, Kembali. Progressive limit 50 ke 100 dan refresh limit 100 diverifikasi melalui interaksi widget.
- Profil: Mode gelap, Keluar, retry detail; Bahasa/Versi adalah informasi noninteraktif.
- Chat: Buka chat menampilkan keterangan unavailable; Tutup dan Escape bekerja. Push/dokumen yang belum tersedia tidak memiliki kontrol mati yang terlihat.

## Antislop Delivery Gate untuk scope UI lokal

### Hard Gate

- R-02 PASS: copy baru tidak memakai em dash.
- R-03 PASS: widget Kalender/Notifikasi, header Beranda serta regresi Profil lulus pada 320dp dan text scaling 200%.
- R-17 PASS: jadwal/count/status berasal dari respons server; golden berlabel fixture test.
- R-18 PASS: tidak ada testimonial atau identitas pengguna rekaan dalam provider produksi.
- R-23 PASS: tidak ada logo/foto/aset visual baru; avatar memakai identitas sesi/profil.
- R-24 PASS: resource route memakai allowlist tujuan yang sudah tersedia.
- R-25 PASS: theme contrast tests tetap lulus; checker success 4.57:1, warning 4.51:1, dark success 7.71:1, dark warning 7.96:1.
- R-26 PASS: kontrol yang dirilis memiliki handler; chat membuka dialog unavailable sesuai revisi pengguna, push toggle dan baris dokumen semu tidak ditampilkan.
- R-27 PASS: Kalender/inbox/detail Profil memiliki loading, empty/unavailable, error dan retry yang relevan.
- R-28 PASS: tidak ada FAQ atau section promosi yang ditambahkan.
- R-32 PASS: test Tab/Enter Kalender, Escape overlay bersama, dan Escape dialog chat lulus; kontrol memakai focus/semantics Material.
- R-33 PASS: seluruh perubahan fitur ditulis dalam source dengan apply_patch, tidak lewat script patch eksternal.
- R-34 PASS: widget/golden light/dark lulus; theme switch mengikuti brightness aktual.
- R-35 PASS: aplikasi dibangun Android/web dan click-through lokal dicatat; staging/perangkat tidak diklaim selesai.
- R-36 PASS: tidak ada klaim push aktif, proteksi payroll, atau otorisasi server yang dipalsukan.
- R-37 PASS: Design Read dan dials dinyatakan sebelum implementasi, memakai handoff pengguna.
- R-38 PASS: provider produksi tidak memilih fixture/demo; unsupported capability tidak dibuat sebagai konten realistis.

### Purpose Gate

- R-01 PASS: tanpa gradient/glow baru; surface mengikuti HTML.
- R-04 PASS: ikon kalender, shift, inbox dan status menjelaskan konten masing-masing.
- R-06 PASS: Plus Jakarta Sans dan section labels mengikuti identitas handoff ESS Indonesia.
- R-07 PASS: grid hanya kalender tanggal, bukan dekorasi background.
- R-08 PASS: chevron untuk perpindahan bulan/back, bukan dekorasi CTA.
- R-09 PASS: unread badge menunjukkan count server; chip merupakan filter nyata.
- R-10 PASS: tidak menambahkan glassmorphism.
- R-12 PASS: shadow kartu/navigasi memakai elevation handoff, bukan glow baru.
- R-13 PASS: tidak ada glow tambahan.
- R-14 PASS: grid tanggal, daftar notifikasi, dan kelompok profil memiliki komposisi sesuai fungsi berbeda.
- R-19 PASS: tidak menambahkan animasi berulang; busy/loading memberi feedback proses.
- R-22 PASS: tidak ada ilustrasi generik tambahan.

### Liveliness

- Dials PASS: ENERGY 2 / RHYTHM 2 / MOTION 2 eksplisit dan tidak dinaikkan.
- Konsistensi PASS: komposisi langsung dari HTML, tanpa pola promosi baru.
- Fokus PASS: tanggal/agenda, inbox/unread, dan identitas/settings adalah fokus tiap layar.
- Whitespace PASS: safe-area, section gaps, dan padding memisahkan tugas/konten.
- Accent PASS: biru untuk seleksi/aksi; semantic tone hanya untuk kategori/status.
- Motif PASS: Plus Jakarta Sans, kartu lembut dan avatar inisial melanjutkan handoff.
- Design Read PASS: direction dinyatakan sebelum source diubah.

### Craftsmanship dan Quality Locks

- C-1 PASS: perubahan layout mengikuti HTML atau alasan keamanan/kontrak/responsivitas yang dicatat.
- C-2 PASS: handler tersedia; capability tanpa kontrak tidak menjadi tombol mati.
- C-3 PASS: setiap section melayani jadwal, inbox, identitas atau pengaturan, bukan template promosi.
- C-4 PASS: state/loading/error/retry, theme, 320dp/390dp dan keyboard lokal diuji.
- C-5 PASS: test fixture dilabeli, tidak dianggap bukti server/staging.
- R-05 PASS: komposisi berbeda per tugas, tidak menambah template hero/stat/chart.
- R-11 PASS: avatar Beranda/Profil berbentuk lingkaran sesuai instruksi terbaru pengguna; kartu, icon control dan chip mempertahankan hierarchy handoff.
- R-15 PASS: CTA menyebut tindakan: Coba lagi, Tandai dibaca, Muat lebih banyak, Keluar.
- R-16 PASS: tidak ada buzzword pemasaran baru.
- R-20 PASS: kalender kerja/approval/kepegawaian spesifik ESS, bukan dashboard generik.
- R-21 PASS: light default serta preferensi dark tetap bekerja dan tersimpan.
- R-29 PASS: neutral/primary dan semantic tones memakai token theme yang sama.
- R-30 PASS: sumber visual adalah HTML pengguna, bukan clone produk lain.
- R-31 PASS: alasan major layout, typography, spacing, badges dan unavailable states dicatat di atas.

### Checklist skill pendamping

- UI PASS: source visual, semantic icon/tone, filter pill, dan composition diperiksa terhadap HTML/golden.
- Mobile PASS: tap target tanggal minimal 44dp, grid Monday-first, safe-area dan scroll diuji pada 320dp.
- Human PASS: contrast dihitung, semantics state/selection/busy tersedia, font offline, keyboard dan text scaling diuji.
- Copy PASS: Bahasa Indonesia menyebut konteks/error/tindakan; label perangkat dan unavailable tidak menyembunyikan keterbatasan kontrak.

## Syarat sebelum acceptance live

1. Fixture tersanitasi dari deployment untuk resolved calendar, notifications, unread/read, dan profile employee.
2. Field timezone kantor dan tanggal server, atau endpoint self yang menyediakan keduanya.
3. Kontrak cuti tim jika akan ditampilkan, serta pagination page/cursor jika backend mendukungnya.
4. Kontrak register/unregister push token, konfigurasi Firebase dan payload resource/identity.
5. Kontrak dokumen/atasan; payroll unlock tetap ditinjau di RD-017.
6. Akun employee/manager uji dan server HTTPS staging untuk smoke test.

Warning build yang harus masuk hardening: `package_info_plus` 8.3.1 masih menerapkan Kotlin Gradle Plugin dan perlu migrasi sebelum upgrade Flutter yang mewajibkan Built-in Kotlin. Web JavaScript berhasil; dry-run Wasm masih tidak kompatibel dengan legacy imports `flutter_secure_storage_web`. Tidak ada upgrade dependency massal dilakukan dalam Tahap 4.
