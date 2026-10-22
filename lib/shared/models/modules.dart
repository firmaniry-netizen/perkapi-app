import 'package:flutter/material.dart';

/// [date] = tanggal saja (yyyy-MM-dd). [datetime] = tanggal + jam, disimpan UTC (ISO 8601) dan ditampilkan waktu lokal.
enum FieldType { text, multiline, markdown, number, date, datetime, select, boolean, lookup, tags }

class FieldDef {
  const FieldDef(
    this.key,
    this.label, {
    this.type = FieldType.text,
    this.required = false,
    this.options = const [],
    this.lookupTable,
    this.lookupLabel = 'name',
  });
  final String key;
  final String label;
  final FieldType type;
  final bool required;
  final List<String> options;
  final String? lookupTable;
  final String lookupLabel;
}

/// Definisi modul CRUD generik. Nama kolom di sini harus cocok dengan database
/// (lihat docs/SCHEMA_ASSUMPTIONS.md dan sql/02_additive_columns.sql).
class ModuleDef {
  const ModuleDef({
    required this.id,
    required this.title,
    required this.table,
    required this.icon,
    required this.titleKey,
    required this.fields,
    this.subtitleKeys = const [],
    this.searchKeys = const [],
    this.orderBy = 'created_at',
    this.readPerm,
    this.writePerm,
    this.ownerKey,
    this.ownOnly = false,
    this.readOnly = false,
    this.statusKey,
    this.filter = const {},
    this.markAllRead = false,
    this.offlineCache = false,
  });
  final String id, title, table, titleKey, orderBy;
  final IconData icon;
  final List<FieldDef> fields;
  final List<String> subtitleKeys, searchKeys;
  final String? readPerm, writePerm, ownerKey, statusKey;
  final bool ownOnly, readOnly, markAllRead, offlineCache;
  final Map<String, Object> filter;
}


final Map<String, ModuleDef> modules = {
  for (final m in [
    ModuleDef(
      offlineCache: true, id: 'notes', title: 'Buku Saku Saya', table: 'personal_notes',
      icon: Icons.menu_book_outlined, titleKey: 'title',
      subtitleKeys: ['content'], searchKeys: ['title', 'content'],
      ownerKey: 'member_id', ownOnly: true, statusKey: null,
      fields: [
        FieldDef('title', 'Judul', required: true),
        FieldDef('category_id', 'Kategori', type: FieldType.lookup, lookupTable: 'personal_note_categories'),
        FieldDef('content', 'Isi catatan', type: FieldType.markdown),
        FieldDef('tags', 'Tag (pisahkan koma)', type: FieldType.tags),
        FieldDef('reminder_at', 'Pengingat', type: FieldType.datetime),
        FieldDef('is_pinned', 'Sematkan', type: FieldType.boolean),
        FieldDef('is_favorite', 'Favorit', type: FieldType.boolean),
        FieldDef('is_archived', 'Arsipkan', type: FieldType.boolean),
      ],
    ),
    ModuleDef(
      offlineCache: true, id: 'org_book', title: 'Buku Saku Organisasi', table: 'pocket_book_contents',
      icon: Icons.account_balance_outlined, titleKey: 'title',
      subtitleKeys: ['category'], searchKeys: ['title', 'content', 'category'],
      writePerm: 'manage_announcement',
      fields: [
        FieldDef('title', 'Judul', required: true),
        FieldDef('category', 'Kategori', type: FieldType.select,
            options: ['Peraturan', 'SOP', 'Panduan', 'Struktur Organisasi', 'FAQ', 'Lainnya']),
        FieldDef('content', 'Isi', type: FieldType.markdown),
        FieldDef('is_published', 'Dipublikasikan', type: FieldType.boolean),
      ],
    ),
    ModuleDef(
      offlineCache: true, id: 'announcements', title: 'Pengumuman', table: 'announcements',
      icon: Icons.campaign_outlined, titleKey: 'title',
      subtitleKeys: ['category'], searchKeys: ['title', 'body'],
      writePerm: 'manage_announcement', ownerKey: 'created_by',
      fields: [
        FieldDef('title', 'Judul', required: true),
        FieldDef('category', 'Kategori', type: FieldType.select,
            options: ['Pengumuman', 'Berita', 'Organisasi', 'Peraturan', 'Agenda']),
        FieldDef('body', 'Isi', type: FieldType.markdown),
        FieldDef('is_published', 'Dipublikasikan', type: FieldType.boolean),
      ],
    ),
    ModuleDef(
      offlineCache: true, id: 'events', title: 'Agenda & Event', table: 'events', icon: Icons.event_outlined,
      titleKey: 'title', subtitleKeys: ['starts_at', 'location'],
      searchKeys: ['title', 'location'], orderBy: 'starts_at', writePerm: 'manage_event',
      fields: [
        FieldDef('title', 'Nama event', required: true),
        FieldDef('description', 'Deskripsi', type: FieldType.multiline),
        FieldDef('location', 'Lokasi'),
        FieldDef('latitude', 'Latitude', type: FieldType.number),
        FieldDef('longitude', 'Longitude', type: FieldType.number),
        FieldDef('starts_at', 'Mulai', type: FieldType.datetime, required: true),
        FieldDef('ends_at', 'Selesai', type: FieldType.datetime),
        // Terhubung dengan situs resmi (SQL 37): acara yang dinyalakan tampil di halaman Agenda situs.
        FieldDef('is_public', 'Tampilkan di situs resmi', type: FieldType.boolean),
      ],
    ),
    ModuleDef(
      id: 'forum', title: 'Forum Internal', table: 'forum_posts', icon: Icons.forum_outlined,
      titleKey: 'title', subtitleKeys: ['category'], searchKeys: ['title', 'body'],
      ownerKey: 'author_id',
      fields: [
        FieldDef('title', 'Judul', required: true),
        FieldDef('category', 'Kategori', type: FieldType.select,
            options: ['Diskusi', 'Kepailitan', 'PKPU', 'Organisasi', 'Pembelajaran', 'Pengumuman']),
        FieldDef('body', 'Isi', type: FieldType.multiline, required: true),
        FieldDef('is_hidden', 'Sembunyikan (moderasi)', type: FieldType.boolean),
      ],
    ),
    ModuleDef(
      id: 'members', title: 'Anggota', table: 'members', icon: Icons.badge_outlined,
      titleKey: 'full_name', subtitleKeys: ['member_number', 'status'],
      searchKeys: ['full_name', 'member_number', 'email'], statusKey: 'status',
      orderBy: 'full_name', readPerm: 'view_member', writePerm: 'manage_member',
      fields: [
        FieldDef('full_name', 'Nama lengkap', required: true),
        FieldDef('member_number', 'Nomor anggota (kosongkan = otomatis)'),
        FieldDef('email', 'Email'),
        FieldDef('phone', 'Telepon'),
        FieldDef('branch_id', 'Cabang', type: FieldType.lookup, lookupTable: 'branches'),
        FieldDef('status', 'Status', type: FieldType.select, options: ['Aktif', 'Nonaktif', 'Cuti']),
        FieldDef('valid_until', 'Masa berlaku', type: FieldType.date),
      ],
    ),
    ModuleDef(
      id: 'branches', title: 'Cabang', table: 'branches', icon: Icons.location_city_outlined,
      titleKey: 'name', subtitleKeys: ['city'], searchKeys: ['name', 'city'],
      orderBy: 'name', writePerm: 'manage_user',
      fields: [
        FieldDef('name', 'Nama cabang', required: true),
        FieldDef('code', 'Kode'),
        FieldDef('city', 'Kota'),
      ],
    ),
    ModuleDef(
      id: 'notifications', title: 'Notifikasi', table: 'notifications', icon: Icons.notifications_outlined,
      titleKey: 'title', subtitleKeys: ['body'], searchKeys: ['title', 'body'],
      ownerKey: 'member_id', ownOnly: true, readOnly: true, markAllRead: true, fields: [
        FieldDef('title', 'Judul'),
        FieldDef('body', 'Isi', type: FieldType.multiline),
      ],
    ),
    ModuleDef(
      id: 'audit', title: 'Audit Log', table: 'audit_logs', icon: Icons.history_outlined,
      titleKey: 'action', subtitleKeys: ['module', 'record_id'],
      searchKeys: ['action', 'module'], readPerm: 'view_audit_log', readOnly: true,
      fields: [FieldDef('action', 'Aksi'), FieldDef('module', 'Modul'), FieldDef('record_id', 'ID data')],
    ),
  ])
    m.id: m,
};
