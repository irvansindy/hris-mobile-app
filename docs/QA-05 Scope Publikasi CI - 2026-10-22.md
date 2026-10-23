# QA-05: Scope Publikasi CI

Tanggal scope: 22 Oktober 2026. Pembaruan eksekusi: 23 Oktober 2026.
Status: **scope disetujui, publikasi dan bukti CI IN_PROGRESS**.

## Tujuan

Pengguna memilih remote `origin`, yaitu `irvansindy/hris-mobile-app`.
Remote `draft` tidak menjadi tujuan push untuk QA-05 ini. CI perlu menguji
snapshot terbaru dari commit yang disepakati, bukan menjalankan ulang commit
September. Repository tujuan bersifat publik menurut metadata GitHub yang
diperiksa pada preflight; dokumentasi backend/audit ikut menjadi publik bila
dimasukkan ke commit.

## Scope yang diusulkan

Inventaris awal: 50 file tracked berubah dan 21 file untracked. Dokumen ini
menambah satu file baru. Inventaris meliputi perubahan staged maupun unstaged;
posisi staging bukan persetujuan publikasi seluruh perubahan.

| Kelompok | Perubahan yang dibawa |
| --- | --- |
| Firebase development | Adapter dan panel push, koordinasi token/logout, konfigurasi debug Android, guard app config, contoh env dan tes terkait |
| Revisi kontrak API Oktober | Wajib ganti password, employee ID/number, metadata multi-slip, carry-over, tracing request dan parser ESS; berikut tes kontraknya |
| Regresi QA-04 | Routing/navigasi Pengajuan, modal root, fixture flow dan guard bootstrap yang menunggu `/auth/me` |
| Guard native/CI | Constraint JUnit, pemeriksa dependency Gradle, checksum PDFium cache/AAB, workflow dan tes guard |
| Dokumentasi | README, panduan Firebase development, kontrak/backend checklist, matriks migrasi, rekap pending dan laporan/bukti audit JSON |

Usulan branch: `qa/remote-ci-baseline-2026-10-22`, lalu PR ke `master` pada
`origin`. Tidak melakukan merge otomatis atau push langsung ke `master`.
Commit integrasi perlu menjelaskan bahwa ini baseline validasi CI, bukan release
production. Review ini menginventarisasi scope; bukan review baru menyeluruh
atas setiap perubahan atau persetujuan release.

## File lokal yang tidak dipublikasikan

`.env`, `tmp/hris-mobile-smoke.json`, kedua lokasi Android `google-services.json`,
`ios/Runner/GoogleService-Info.plist`, output build dan coverage tidak masuk scope.
Pemeriksaan `git check-ignore` mengonfirmasi pola ignore tersebut, dan file
kredensial yang disebutkan tidak muncul pada daftar tracked.

Scan pola private key, GitHub token, AWS access ID dan Google API key pada source,
tes, tool, docs, integration dan konfigurasi yang diperiksa tidak menemukan
kecocokan. Ini pemeriksaan terbatas, bukan jaminan bebas seluruh jenis secret;
payload dan staging final tetap perlu ditinjau sebelum push.

Delapan PNG di `test/failures/requests_fixture_{dark,light}_320_text200_*`
masih tracked dari baseline lama. Ignore tidak mengeluarkannya dari Git.
Pengguna menyetujui pengeluaran hanya delapan file itu dari tracking pada commit
baru, dengan file di disk tetap disimpan. Bukan penghapusan golden acuan.

## Bukti dan langkah berikutnya

- Hasil lokal terakhir pada 21 Oktober: 675 tes lulus, analyzer/format bersih,
  dan APK non-demo debug berhasil dibangun; lihat laporan QA-04.
- Preflight 22 Oktober: enam tes struktur workflow lulus dan `git diff --check
  HEAD` bersih. Tidak mengulang full suite atau build dalam inventarisasi ini.
- Setelah scope disetujui, stage path secara eksplisit, tinjau diff staged dan
  file sensitif, lalu jalankan verifikasi pada snapshot yang akan dipublikasikan.
- Setelah commit/push/PR, catat SHA dan run URL. Pastikan quality, Android
  build/guard/integration dan macOS iOS unsigned benar-benar lulus. Kegagalan
  remote harus dianalisis; hasil lokal tidak menggantikannya.

## Eksekusi yang disetujui

Branch `qa/remote-ci-baseline-2026-10-22` dibuat dari HEAD lokal
`b90f8db62e53705d0e957459c2ee615b36274b78`. Remote `origin/master` masih pada
`3e9719e31dc5adef167240287177afbe76719133`, ancestor dari HEAD lokal. PR juga
akan membawa 35 commit pengembangan lokal yang sudah ada, tanpa rewrite history.

Verifikasi ulang sebelum publikasi: **675 tes PASS**, exit 0 (2 menit 4 detik),
analyzer tanpa issue dan format 285 file tanpa perubahan. Log sementara:
`/tmp/hris-qa05-20261022.GlG4lt/full-tests.log`. Scan pola secret umum pada diff
history outgoing dan source yang diperiksa tidak menemukan kecocokan. Path
kredensial utama juga tidak ditemukan pada history outgoing yang diperiksa.
Ini tetap bukan audit keamanan lengkap.

Scope commit/push/PR ke `origin` sudah disetujui pengguna. Tidak melakukan merge
otomatis. QA-05 belum DONE sampai bukti run untuk commit publikasi diverifikasi;
hasil lokal tidak menutup gate iOS atau release lain.

## Hasil publikasi dan hambatan PR

Commit integrasi `e883d61f4da3c57d9a26654eedebde1d55b320cc` berhasil dipush
ke `origin/qa/remote-ci-baseline-2026-10-22`. Worktree bersih sesudah commit.
Delapan PNG sudah tidak tracked; pemeriksaan SHA-256 sesudah operasi membuktikan
file lokal tetap sama. Tidak memodifikasi golden acuan atau menghapus file lokal.

Pembuatan PR melalui integrasi GitHub gagal dengan HTTP 403:
`Resource not accessible by integration`. Tidak ada PR terbuka yang ditemukan
untuk branch tersebut. Pemeriksaan run pada SHA integrasi mengembalikan nol run.
Workflow hanya terpicu oleh PR atau push ke `master`/`main`; push ke branch QA
sendiri belum menjalankan CI. Tidak menambahkan bypass trigger atau mengubah
permission workflow/akun untuk mengatasi pembatasan integrasi.

**PENDING tindakan pengguna:**
[buat PR dari branch QA ke master](https://github.com/irvansindy/hris-mobile-app/compare/master...qa/remote-ci-baseline-2026-10-22?expand=1)
melalui browser, atau berikan integrasi GitHub izin pull request write pada
repository ini. Jangan mengirim token/password di chat. Setelah PR tersedia,
lanjutkan pemantauan quality, Android dan iOS; QA-05 belum dinyatakan PASS.
Tidak melakukan merge, force-push atau push ke remote `draft`.
