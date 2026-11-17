# Kualitas gambar dan performa

Kualitas mirroring bergantung pada kemampuan HP, laptop, koneksi, resolusi layar, aplikasi yang ditampilkan, dan kualitas kabel atau Wi-Fi.

## Preset yang tersedia

| Pengaturan | Cocok untuk |
| --- | --- |
| 720p · 30 FPS · 4 Mbps | Laptop lama, jaringan Wi-Fi yang kurang stabil |
| 1080p · 30 FPS · 8 Mbps | Penggunaan umum dan beban lebih ringan |
| 1080p · 60 FPS · 12 Mbps | Rekomendasi awal untuk tampilan responsif |
| 1440p · 60 FPS · 20 Mbps | Perangkat dan jaringan yang cukup kuat |
| Native size | Mengikuti resolusi sumber, gunakan bila laptop mampu |

Nilai di atas adalah batas konfigurasi video yang diminta ke scrcpy, bukan jaminan FPS atau resolusi aktual. Perangkat dapat menghasilkan performa lebih rendah.

## Jika gambar patah-patah

1. Turunkan 60 FPS menjadi 30 FPS.
2. Turunkan bitrate dari 12 Mbps ke 8 Mbps atau 4 Mbps.
3. Turunkan resolusi maksimum menjadi 720p.
4. Untuk Wi-Fi, dekatkan HP dan laptop ke access point dan hindari jaringan yang padat.
5. Coba USB untuk membandingkan apakah masalah berasal dari jaringan.
6. Tutup aplikasi berat di HP dan laptop.

## Jika gambar buram

Naikkan resolusi dan bitrate secara bertahap. Bitrate yang tinggi menggunakan lebih banyak bandwidth dan tidak selalu menghasilkan pengalaman yang lebih lancar.

## Ukuran jendela

Ukuran jendela mirroring dapat diatur langsung dari jendela scrcpy. LajuMirror mengatur batas ukuran video saat memulai sesi; ukuran akhir juga dipengaruhi orientasi dan resolusi layar HP.

## Audio

Audio forwarding sengaja dinonaktifkan. LajuMirror tidak memakai bandwidth untuk mengirim audio HP ke laptop.