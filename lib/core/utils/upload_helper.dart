import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pilih file TANPA memuat isinya ke memori di Android/iOS (di web tetap perlu bytes).
/// Memuat foto kamera beresolusi besar sekaligus ke RAM bisa menutup aplikasi di HP berRAM kecil.
bool get pickWithData => kIsWeb;

/// File punya sumber yang bisa diunggah (path di perangkat, atau bytes di web).
bool hasSource(PlatformFile f) => kIsWeb ? f.bytes != null : f.path != null;

/// Foto lebih besar dari ini diperkecil saat dipilih (sisi terpanjang, piksel).
const _maxSide = 1920.0;
const _quality = 80;

/// Pilih foto dari galeri atau kamera.
///
/// Mengapa tidak lagi memakai FilePicker untuk foto: FileType.image di file_picker secara bawaan
/// meng-kompres tiap foto (compressionQuality 30) dengan memuat bitmap penuh ke RAM. Foto kamera
/// 48 MP butuh sekitar 190 MB, sehingga di HP RAM kecil aplikasi langsung mati begitu foto dipilih.
/// image_picker memperkecil foto langsung di sisi native sebelum sampai ke Dart.
Future<List<PlatformFile>> pickPhotos({bool camera = false, bool multiple = true}) async {
  final picker = ImagePicker();
  List<XFile> shots;
  if (camera) {
    final x = await picker.pickImage(
        source: ImageSource.camera, maxWidth: _maxSide, maxHeight: _maxSide, imageQuality: _quality);
    shots = x == null ? [] : [x];
  } else if (multiple) {
    shots = await picker.pickMultiImage(maxWidth: _maxSide, maxHeight: _maxSide, imageQuality: _quality);
  } else {
    final x = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: _maxSide, maxHeight: _maxSide, imageQuality: _quality);
    shots = x == null ? [] : [x];
  }
  final out = <PlatformFile>[];
  for (final x in shots) {
    final size = await x.length();
    if (kIsWeb) {
      out.add(PlatformFile(name: x.name, size: size, bytes: await x.readAsBytes()));
    } else {
      out.add(PlatformFile(name: x.name, size: size, path: x.path));
    }
  }
  return out;
}

/// Unggah ke Supabase Storage: dari path (streaming, hemat memori) atau dari bytes (web).
Future<void> uploadPicked(SupabaseClient db, String bucket, String path, PlatformFile f) async {
  if (!kIsWeb && f.path != null) {
    await db.storage.from(bucket).upload(path, File(f.path!));
  } else {
    await db.storage.from(bucket).uploadBinary(path, f.bytes!);
  }
}
