# Panduan koneksi USB

USB adalah cara yang paling mudah untuk memulai dan biasanya paling konsisten untuk penggunaan lama.

## Di HP Android

1. Buka Settings / Setelan → About phone / Tentang ponsel.
2. Aktifkan Developer options dengan mengetuk Build number, MIUI version, atau OS version sesuai merek dan versi sistem.
3. Buka Developer options.
4. Aktifkan USB debugging.
5. Sambungkan kabel data ke laptop.
6. Pilih mode USB yang mengizinkan data bila HP menampilkan notifikasi USB.
7. Terima dialog otorisasi USB debugging di HP.

Pada Xiaomi, menu yang umum adalah Settings → Additional settings → Developer options. Jangan mengubah opsi pengembang lain yang tidak diperlukan.

## Di LajuMirror

1. Buka tab USB.
2. Pilih perangkat yang statusnya Ready / Siap.
3. Atur kualitas layar.
4. Tekan Start mirroring.

Jika perangkat menampilkan status Waiting for approval, buka layar HP dan setujui dialog otorisasi.

## Kabel dan port

- Gunakan kabel yang mendukung data, bukan kabel charge-only.
- Coba port USB lain langsung pada laptop, bukan melalui hub yang tidak memiliki daya cukup.
- Jika koneksi sering terputus, coba kabel yang lebih pendek atau berkualitas lebih baik.
- Jangan menarik kabel saat proses pairing atau transfer sedang berlangsung.

## Audio

LajuMirror menjalankan scrcpy dengan audio forwarding dinonaktifkan. Suara media tetap mengikuti pengaturan output audio Android. Jika HP tersambung ke earphone atau perangkat Bluetooth, Android tetap dapat mengirim suara ke perangkat tersebut.

## Jika tidak terdeteksi

1. Pastikan USB debugging aktif.
2. Cabut dan sambungkan ulang kabel.
3. Buka kunci layar HP.
4. Periksa apakah dialog otorisasi muncul.
5. Pilih Revoke USB debugging authorizations di Developer options, sambungkan kembali, lalu setujui komputer sekali lagi.
6. Buka [Troubleshooting](TROUBLESHOOTING.md) untuk langkah lanjutan.