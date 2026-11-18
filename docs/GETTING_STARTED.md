# Mulai menggunakan LajuMirror

Panduan ini untuk pengguna Windows yang ingin menampilkan dan mengontrol HP Android dari laptop, sementara suara tetap diputar dari HP.

## 1. Persiapan

- Windows 10 atau Windows 11 versi 64-bit.
- HP Android yang masih mendapat dukungan USB debugging atau Wireless Debugging.
- Kabel USB yang mendukung transfer data untuk koneksi pertama.
- LajuMirror dari halaman GitHub Releases.

## 2. Instal aplikasi

1. Unduh file installer MSI atau EXE dari halaman Releases setelah tersedia.
2. Pastikan penerbit/signature Windows valid sebelum menjalankannya.
3. Jangan memasang artifact CI unsigned preview pada perangkat yang menerapkan Smart App Control.
4. Jalankan installer tepercaya dan ikuti petunjuk di layar.
5. Buka LajuMirror dari Start menu.
6. Jika Windows memblokir file, jangan mematikan Smart App Control atau Defender. Gunakan hanya rilis bertanda tangan tepercaya atau minta administrator perangkat meninjau kebijakan yang berlaku.

## 3. Siapkan Android

Nama menu berbeda antar-merek dan versi Android.

1. Buka Settings / Setelan → About phone / Tentang ponsel.
2. Ketuk Build number / Nomor bentukan atau OS version beberapa kali sampai Developer options aktif. Pada Xiaomi, labelnya bisa berupa MIUI version atau OS version.
3. Kembali ke Settings → Additional settings / Setelan tambahan → Developer options / Opsi pengembang.
4. Aktifkan USB debugging.
5. Hubungkan HP menggunakan kabel data.
6. Saat dialog "Allow USB debugging?" muncul, periksa sidik jari RSA dan pilih Allow. Aktifkan "Always allow from this computer" hanya pada laptop pribadi yang kamu percaya.

## 4. Mulai mirroring

1. Buka LajuMirror.
2. Tunggu daftar perangkat diperbarui.
3. Pilih HP dengan status Ready / Siap.
4. Atur resolusi, FPS, dan bitrate. Pengaturan awal yang seimbang adalah 1080p, 60 FPS, dan 12 Mbps.
5. Pastikan indikator Phone audio menunjukkan bahwa suara tetap di HP.
6. Tekan Start mirroring.

Jendela scrcpy akan terbuka terpisah. Gunakan mouse dan keyboard laptop untuk mengontrol HP.

## 5. Beralih ke Wi-Fi

Setelah koneksi USB berhasil, kamu dapat berpindah ke tab Wi-Fi. Untuk Android 11 ke atas, Wireless Debugging pairing merupakan pilihan yang disarankan. Lihat [panduan Wi-Fi](WIFI.md).

## 6. Menghentikan sesi

Tekan Stop mirroring di LajuMirror untuk menghentikan sesi yang dimulai dari aplikasi. Menutup jendela mirroring juga menghentikan proses mirroring. Untuk keamanan, matikan USB debugging atau Wireless Debugging setelah selesai menggunakan perangkat bersama atau jaringan yang tidak dipercaya.

## Butuh bantuan?

Lihat [Troubleshooting](TROUBLESHOOTING.md) atau [FAQ](FAQ.md).