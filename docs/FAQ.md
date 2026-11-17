# FAQ

## Apakah LajuMirror gratis?

Kode LajuMirror menggunakan lisensi MIT. scrcpy dan ADB adalah proyek pihak ketiga dengan lisensi masing-masing. Periksa halaman Releases untuk ketersediaan installer.

## Apakah hanya untuk Xiaomi?

Tidak. LajuMirror ditujukan untuk perangkat Android yang mendukung ADB. Nama menu dan pengalaman pengaturan dapat berbeda menurut merek dan versi Android.

## Apakah suara tetap keluar dari HP?

Ya, mode default memulai scrcpy dengan audio forwarding dinonaktifkan. Suara tetap mengikuti pilihan output audio di Android, misalnya speaker HP atau earphone Bluetooth yang terhubung.

## Apakah bisa tanpa kabel?

Bisa. Gunakan Wireless Debugging untuk Android 11 ke atas atau ADB TCP/IP setelah melakukan koneksi USB awal.

## Apakah HP bisa dikontrol dengan mouse dan keyboard?

Bisa, selama perangkat mengizinkan kontrol melalui scrcpy dan sesi berjalan dengan sukses. Beberapa layar keamanan atau aplikasi tertentu dapat membatasi input.

## Apakah bisa fullscreen?

Gunakan kontrol jendela scrcpy untuk memperbesar atau masuk ke mode fullscreen. Jendela mirroring dibuka terpisah dari dashboard LajuMirror.

## Apakah harus memasang aplikasi di HP?

Tidak perlu memasang aplikasi LajuMirror Android. ADB dan scrcpy menghubungkan HP langsung ke komputer.

## Kenapa perangkat harus mengaktifkan Developer options?

ADB membutuhkan debugging interface Android. LajuMirror tidak dapat melewati mekanisme otorisasi Android.

## Apakah aman menggunakan Wi-Fi publik?

Tidak disarankan. Wireless Debugging dan ADB TCP/IP sebaiknya hanya digunakan pada jaringan lokal yang kamu percaya. Matikan debugging setelah selesai.

## Kenapa perangkat tidak terdeteksi?

Periksa kabel data, USB debugging, otorisasi RSA, status layar HP, serta apakah ADB tersedia. Lihat [Troubleshooting](TROUBLESHOOTING.md).

## Apakah tersedia untuk macOS atau Linux?

Versi awal berfokus pada Windows 10/11 64-bit. Dukungan platform lain belum dijanjikan.