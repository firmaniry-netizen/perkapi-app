# Arsitektur

[← Kembali ke ringkasan](README.md)

## Gambaran sistem

```mermaid
flowchart LR
    subgraph HP["HP anggota"]
        A["Aplikasi Flutter<br/>Android & iOS"]
    end
    W["Website perkapi.or.id<br/>HTML · JS · Three.js<br/>(Hostinger)"]
    subgraph SB["Supabase"]
        AUTH["Auth"]
        DB[("PostgreSQL<br/>+ Row Level Security")]
        RT["Realtime"]
        ST["Storage<br/>foto & dokumen"]
        EF["Edge Functions<br/>TypeScript/Deno"]
    end
    FCM["Firebase Cloud Messaging<br/>(APNs untuk iOS)"]
    TURN["Server TURN<br/>WebRTC"]

    A -- login --> AUTH
    A -- query & RPC --> DB
    A <-- chat & notifikasi --> RT
    A -- unggah --> ST
    W -- data publik --> DB
    DB -- webhook notifikasi --> EF
    EF -- send-push --> FCM
    FCM -- push --> A
    A -- minta kredensial --> EF
    A <-- suara & video --> TURN
```

## Struktur kode aplikasi

Kode diatur per fitur (*feature-first*):

```
lib/
├── app/          # router (go_router), tema, controller tema
├── core/         # konstanta, layanan (Supabase, push, PIN), utilitas, widget bersama (Liquid Glass)
├── features/     # 31 modul: auth, chat, members, documents, cases, donations, ...
└── shared/       # model & repository data bersama
```

## Alur status pesan (✓ / ✓✓ / ✓✓ biru)

```mermaid
sequenceDiagram
    participant P as Pengirim
    participant DB as Supabase (PostgreSQL)
    participant R as Penerima
    P->>DB: insert chat_messages
    DB-->>R: Realtime + notifikasi
    R->>DB: rpc chat_mark_delivered()
    DB-->>P: Realtime: last_delivered_at (✓✓ abu-abu)
    R->>DB: buka chat → rpc chat_mark_read()
    DB-->>P: Realtime: last_read_at (✓✓ biru, "Dilihat")
```

## Alur notifikasi

1. Aplikasi menyimpan token FCM perangkat ke tabel `device_tokens`.
2. Saat ada baris baru di tabel `notifications`, database webhook memanggil Edge Function `send-push`.
3. `send-push` membuat token akses Google dari service account, lalu mengirim pesan ke FCM per perangkat.
4. Panggilan ke Android dikirim sebagai pesan data berprioritas tinggi supaya aplikasi menampilkan layar dering sendiri; ke iOS dikirim sebagai notifikasi *time-sensitive*.
5. Hasil kirim dicatat di tabel `push_log` untuk diagnosis.
