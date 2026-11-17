# Privasi dan keamanan

## Prinsip desain

LajuMirror adalah aplikasi desktop lokal. Tujuannya adalah menampilkan layar Android di komputer yang kamu pilih tanpa membutuhkan akun LajuMirror, backend akun, cloud relay, atau upload screen recording ke layanan LajuMirror.

## Data yang diproses di komputer

Aplikasi membaca daftar perangkat dari ADB, termasuk serial koneksi, status, dan metadata model/product yang disediakan Android Debug Bridge. Nilai ini digunakan untuk menampilkan daftar perangkat.

Saat mirroring dimulai, aplikasi menjalankan scrcpy dengan opsi video yang dipilih. Audio forwarding dinonaktifkan secara eksplisit.

## Koneksi jaringan

Ketika memakai Wireless Debugging atau ADB TCP/IP, komputer berkomunikasi langsung dengan layanan debugging Android di jaringan lokal. LajuMirror tidak menyediakan server relay sendiri. Router, firewall, antivirus, dan kebijakan jaringan tetap dapat memengaruhi koneksi.

ADB melalui jaringan adalah fitur debugging, bukan protokol berbagi layar publik yang aman untuk Wi-Fi umum. Gunakan hanya jaringan yang kamu percaya dan matikan debugging setelah selesai.

## Izin perangkat

Saat pertama kali menghubungkan lewat USB, Android menampilkan dialog otorisasi USB debugging. Periksa bahwa komputer yang meminta izin memang laptop milikmu. Otorisasi yang sudah disimpan dapat dicabut dari Developer options → Revoke USB debugging authorizations.

## Hal yang tidak dilakukan aplikasi

- Tidak memerlukan akun LajuMirror.
- Tidak mengunggah layar HP ke server LajuMirror.
- Tidak mengirim audio HP ke laptop dalam mode default.
- Tidak meminta akses kontak, SMS, lokasi, kamera, atau mikrofon melalui permission aplikasi Android.
- Tidak mengubah konfigurasi keamanan Android selain menjalankan perintah ADB yang dipilih pengguna.

## Laporan kerentanan

Jangan memublikasikan detail celah keamanan yang belum diperbaiki. Ikuti [Security policy](../SECURITY.md) untuk melaporkan isu secara bertanggung jawab.