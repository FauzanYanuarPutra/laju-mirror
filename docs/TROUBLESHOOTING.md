# Troubleshooting

## Perangkat tidak muncul

- Pastikan kabel USB mendukung transfer data.
- Aktifkan USB debugging di Developer options.
- Buka kunci layar Android dan setujui dialog Allow USB debugging.
- Coba port USB lain dan hindari hub yang bermasalah.
- Di HP, pilih Revoke USB debugging authorizations, sambungkan ulang, lalu setujui prompt baru.
- Tutup aplikasi desktop lain yang mungkin sedang menjalankan ADB versi berbeda, lalu buka ulang LajuMirror.

## Status Unauthorized / Menunggu izin

Android belum mengizinkan komputer ini. Periksa layar HP, pastikan sidik jari RSA berasal dari komputer yang benar, lalu pilih Allow. Jangan menyetujui komputer publik atau komputer yang tidak dikenal.

## Status Offline

Cabut dan sambungkan ulang kabel, buka kunci HP, lalu tekan Refresh. Jika memakai Wi-Fi, periksa apakah HP dan laptop masih berada di jaringan yang sama dan gunakan alamat serta port terbaru dari halaman Wireless Debugging.

## ADB atau scrcpy tidak ditemukan

Installer yang dipublikasikan melalui workflow resmi disiapkan untuk membawa scrcpy dan ADB. Untuk development lokal, tempatkan file resmi scrcpy Windows di src-tauri/resources/tools/scrcpy atau tambahkan scrcpy dan ADB ke PATH.

Periksa halaman resmi scrcpy: https://github.com/Genymobile/scrcpy

## Pairing Wi-Fi gagal

- Pastikan Wireless Debugging aktif.
- Gunakan alamat IP dan port Pair device with pairing code untuk pairing.
- Kode harus masih aktif dan dimasukkan persis seperti yang ditampilkan.
- Pastikan tidak menggunakan Connection port untuk kolom Pairing address.
- Jika kode kedaluwarsa, tampilkan pairing code baru dari Android.

## Pairing berhasil tetapi Connect gagal

Pairing port dan connection port adalah dua hal berbeda. Kembali ke halaman utama Wireless debugging dan gunakan alamat IP:port koneksi yang sedang ditampilkan di sana. Periksa juga bahwa HP dan laptop berada di jaringan lokal yang sama.

## TCP/IP tidak dapat tersambung

- Pastikan perangkat USB sedang berstatus Ready.
- Periksa IP HP dari jaringan Wi-Fi yang benar.
- Pastikan port yang digunakan sama dengan port yang diaktifkan.
- Beberapa router mengaktifkan client/AP isolation sehingga perangkat Wi-Fi tidak dapat saling berkomunikasi.
- Jaringan kantor atau publik dapat memblokir port ADB.

## Jendela mirroring tidak terbuka

Pastikan scrcpy dan ADB yang digunakan berasal dari paket yang kompatibel. Restart LajuMirror dan perangkat Android. Periksa apakah antivirus atau kebijakan Windows memblokir executable yang diunduh.

## Mirroring patah-patah

Turunkan FPS, resolusi, atau bitrate. Coba USB untuk mengisolasi masalah jaringan. Lihat [Performance](PERFORMANCE.md).

## Tetap bermasalah?

Buat issue di GitHub dan sertakan:

- Versi LajuMirror.
- Versi Windows.
- Merek dan model Android serta versi Android.
- Metode koneksi (USB, Wireless Debugging, atau TCP/IP).
- Langkah yang sudah dicoba.
- Pesan error yang tampil.

Jangan sertakan pairing code, alamat IP publik, nomor seri perangkat, screenshot pribadi, atau data sensitif.