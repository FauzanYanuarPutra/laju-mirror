# Panduan koneksi Wi-Fi

Koneksi Wi-Fi memungkinkan HP tetap berada di tangan sementara tampilannya dibuka di laptop. HP dan laptop harus dapat saling menjangkau melalui jaringan lokal yang sama.

> Gunakan Wi-Fi pada jaringan rumah atau jaringan pribadi yang kamu percaya. ADB melalui jaringan dapat memberi komputer yang sudah diotorisasi akses debugging ke perangkat.

## Metode A: Wireless Debugging (Android 11 ke atas)

Metode ini menggunakan pairing code dan debugging port yang ditampilkan Android. Kedua alamat port tersebut dapat berbeda.

### 1. Aktifkan Wireless Debugging

1. Sambungkan HP dan laptop ke jaringan Wi-Fi yang sama.
2. Aktifkan Developer options di HP.
3. Buka Developer options → Wireless debugging dan aktifkan.
4. Setujui permintaan jaringan jika muncul.

### 2. Pair perangkat

1. Di halaman Wireless debugging, pilih Pair device with pairing code.
2. Android akan menampilkan alamat IP dan port pairing serta kode numerik sementara.
3. Di LajuMirror, buka tab Wi-Fi.
4. Masukkan alamat IP:port pairing ke kolom Pairing address.
5. Masukkan kode pairing yang masih berlaku.
6. Tekan Pair device.

### 3. Connect perangkat

1. Kembali ke halaman utama Wireless debugging di HP.
2. Catat IP address dan port yang ditampilkan untuk koneksi debugging. Jangan gunakan port pairing jika Android menampilkan port yang berbeda.
3. Masukkan alamat IP:port tersebut pada kolom Connection address.
4. Tekan Connect.
5. Perangkat akan muncul di daftar perangkat LajuMirror. Pilih perangkat Wi-Fi itu, lalu mulai mirroring.

Android dapat mengganti port setelah Wireless Debugging dimatikan atau jaringan berubah. Ulangi langkah pairing atau connect dengan alamat terbaru bila diperlukan.

## Metode B: ADB TCP/IP melalui USB

Metode ini memerlukan koneksi USB yang sudah diotorisasi.

1. Sambungkan HP melalui USB dan pastikan statusnya Ready / Siap.
2. Pastikan laptop dan HP berada di Wi-Fi yang sama.
3. Cari alamat IP HP pada detail jaringan Wi-Fi yang sedang terhubung.
4. Di LajuMirror, buka tab Wi-Fi.
5. Masukkan IP HP tanpa port, misalnya 192.168.1.8.
6. Gunakan port 5555 atau port yang kamu tetapkan.
7. Tekan Enable and connect.
8. Setelah perangkat Wi-Fi muncul, kamu dapat melepas kabel USB.

Jika proses gagal, pastikan firewall dan router tidak memblokir komunikasi antarperangkat dalam jaringan lokal.

## Memutus koneksi

Gunakan Disconnect Wi-Fi di LajuMirror atau matikan Wireless Debugging dari pengaturan Android. Pada metode TCP/IP, kamu juga dapat memutuskan koneksi melalui tombol yang tersedia pada aplikasi.

## Catatan keamanan

- Hindari mengaktifkan ADB TCP/IP pada Wi-Fi publik.
- Jangan membagikan pairing code atau alamat debugging ketika sesi masih aktif.
- Matikan Wireless Debugging setelah selesai.
- Cabut otorisasi komputer yang tidak lagi digunakan dari Developer options.
- Jangan meneruskan port debugging Android ke internet melalui router.