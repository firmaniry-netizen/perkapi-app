# CI/CD dengan Codemagic

[← Kembali ke ringkasan](README.md)

Aplikasi iOS hanya bisa dikompilasi di macOS, sedangkan pengembangan dilakukan di Windows. Codemagic menyediakan
Mac di cloud, sehingga build Android dan iOS berjalan otomatis dari repository GitHub.

| Workflow | Hasil | Dipakai untuk |
| --- | --- | --- |
| `android-apk` | APK rilis | Uji coba di HP Android |
| `ios-cek` | Cek kompilasi iOS | Memastikan kode iOS lolos build tanpa akun Apple |
| `ios-simulator` | `Runner.zip` | Uji coba di iPhone virtual (Appetize) |
| `ios-ipa-sideload` | IPA tanpa tanda tangan | Uji coba di iPhone lewat sideload |
| `ios-testflight` | IPA bertanda tangan | Distribusi ke penguji lewat TestFlight |

## Pengelolaan rahasia

- `lib/firebase_options.dart` dan `android/app/google-services.json` **tidak disimpan di Git**.
- Keduanya disimpan sebagai variabel terenkripsi (base64) di grup `firebase` Codemagic, lalu ditulis ulang saat build.
- Kunci App Store Connect dan sertifikat penandatanganan dikelola oleh integrasi Codemagic, bukan di repository.

## Masalah yang pernah diselesaikan

- **IPA kosong (166 byte)** — skrip build tidak berhenti saat `pod install` gagal. Diperbaiki dengan `set -ex`, menyalin `Runner.app` asli (mengikuti symlink) dengan `ditto`, dan menggagalkan build bila isi IPA kosong.
- **`mobile_scanner` butuh iOS 15.5** — deployment target iOS dinaikkan dari 15.0 ke 15.5.
