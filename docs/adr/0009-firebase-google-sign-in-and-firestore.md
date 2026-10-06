# 0009 — Masuk dengan Google lewat Firebase, dan Firestore di samping server ESAS

## Status

**Accepted — 2026-10-05.**
Menambah pintu masuk kedua; tidak mengubah pintu NIP + kata sandi.
Menambah endpoint `POST /api/v1/auth/firebase` di `tenancy-app` secara **aditif**.

## Context

Owner ingin aplikasi ini (Absensas) memakai Firebase sebagai backend: Firebase
Authentication dengan Google Sign-In, dan Cloud Firestore, di project Firebase
`absensascom`.

Hari ini semua layar — beranda, absensi, izin, profil — membaca dari
`tenancy-app` `/api/v1` dengan token Sanctum (ADR-0006). Identitas Google dari
Firebase bukan token itu, dan `tenancy-app` belum punya cara menerimanya.

Tiga pilihan ditimbang:

| Opsi | Akibat |
|---|---|
| Ganti server ESAS sepenuhnya dengan Firebase | Setiap fitur ditulis ulang; karyawan yang sudah ada harus mendaftar ulang. |
| Tombol Google yang hanya masuk ke Firebase | Tidak ada layar yang bisa dibuka; tombol yang pasti mengecewakan. |
| **Google → Firebase → tukar token di server ESAS** | Satu pintu baru, semua layar tetap bekerja seperti sebelumnya. |

## Decision

**Firebase berdiri di samping server ESAS, bukan menggantikannya.**

1. **Alur masuk.** `google_sign_in` 7 → `FirebaseAuth.signInWithCredential` →
   ID token **Firebase** → `POST /api/v1/auth/firebase {id_token, device_id}`.
   Server memverifikasi token (RS256, `aud`/`iss` = `absensascom`), mensyaratkan
   `email_verified` dan `sign_in_provider = google.com`, mencocokkan email ke
   akun yang **sudah ada** di workspace itu, lalu menjawab persis seperti
   `POST /auth/login` — token, user, abilities, device. Server tidak pernah
   membuat akun.
2. **Penolakan membatalkan Firebase.** Bila server menolak, aplikasi keluar dari
   Firebase dan Google juga. Keluar dari aplikasi pun begitu. Di handset yang
   dipakai bergantian, akun Google orang sebelumnya tidak boleh terpakai ulang
   diam-diam.
3. **Firebase tetap opsional saat boot** (lihat `bootstrap.dart`). Bila gagal
   menyala, tombol Google tidak dirender; NIP tidak pernah membutuhkannya.
4. **Firestore** — database **Enterprise** `absensas` di `asia-southeast2`.
   Isinya baru satu dokumen per akun Google, `users/{uid}`, ditulis setelah
   masuk berhasil (gagal menulis tidak menggagalkan masuk). Data karyawan,
   absensi, dan izin tetap di server ESAS. Fitur yang kelak dipindah ke
   Firestore menggantung pada `uid` ini.
5. **Workspace di Firestore tidak boleh dipercaya dari klien.** `lastTenant`
   hanya petunjuk. Begitu Firestore menyimpan data per workspace, workspace
   harus datang dari *custom claim* yang dipasang server, bukan dari field yang
   bisa ditulis pengguna.

## Consequences

- `lib/firebase_options.dart` menggantikan `firebase_services.dart` yang mati
  (dead-code A1); `Firebase.initializeApp` kini menerima opsi eksplisit, di
  isolat utama dan di handler pesan latar.
- Konfigurasi Firebase dikelola di repo: `firebase.json`, `.firebaserc`,
  `firestore.rules`, `firestore.indexes.json`. Deploy:
  `npx -y firebase-tools@latest deploy --only auth,firestore`.
- **Versi FlutterFire dikunci** pada rilis 2026-08-03 (`firebase_core` 4.13,
  `firebase_auth` 6.5.7, `firebase_messaging` 16.5, `cloud_firestore` 6.8)
  selama proyek masih di Flutter 3.35. Lihat komentar di `pubspec.yaml`.
  Naik bersama upgrade Flutter, bukan sendiri-sendiri.
- Android memakai Kotlin Gradle plugin 2.3 (`firebase-auth` Android membawa
  metadata Kotlin 2.3).
- Google Sign-In Android butuh sidik jari SHA aplikasi di project Firebase.
  SHA debug sudah didaftarkan; **SHA rilis dan SHA Play App Signing belum**.
- `ios/Runner/Info.plist` membawa URL scheme `REVERSED_CLIENT_ID`; ia harus
  ikut berubah bila `GoogleService-Info.plist` diganti.
- Push iOS kini lewat `absensascom` (sebelumnya `esas-44d5d`), sama dengan
  Android. Pengirim push di server harus memakai kredensial project ini.
- Bundle id `com.example.esas` dipertahankan. App Store menolak `com.example.*`;
  menggantinya berarti mendaftarkan ulang aplikasi iOS dan Android di Firebase.
