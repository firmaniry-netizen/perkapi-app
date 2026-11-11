import 'package:flutter/cupertino.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode, CupertinoLocalizations, DatePickerDateOrder, DefaultCupertinoLocalizations;
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';

import 'smooth_overlays.dart';

/// Pemilih tanggal & jam gaya iOS: roda putar di dalam lembar kaca, "Batal" di kiri dan tombol pilih di kanan.
/// Nama parameter sengaja sama dengan showDatePicker / showTimePicker bawaan, jadi pemanggil cukup
/// mengganti nama fungsi. Mengembalikan null bila dibatalkan atau lembar ditutup.
Future<DateTime?> showIosDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
  String? cancelText,
  String? confirmText,
}) {
  final first = DateUtils.dateOnly(firstDate);
  final last = DateUtils.dateOnly(lastDate);
  // Roda iOS menolak nilai awal di luar rentang, jadi dijepit dulu.
  var value = DateUtils.dateOnly(initialDate);
  if (value.isBefore(first)) value = first;
  if (value.isAfter(last)) value = last;
  return showSmoothSheet<DateTime>(
    context: context,
    builder: (_) => _PickerSheet<DateTime>(
      title: helpText ?? 'Pilih tanggal',
      cancelText: cancelText ?? 'Batal',
      confirmText: confirmText ?? 'Pilih',
      read: () => value,
      picker: Localizations.override(
        context: context,
        delegates: const [_IdMonthsDelegate()],
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          dateOrder: DatePickerDateOrder.dmy,
          initialDateTime: value,
          minimumDate: first,
          maximumDate: last,
          onDateTimeChanged: (d) => value = DateUtils.dateOnly(d),
        ),
      ),
    ),
  );
}

/// Pemilih jam gaya iOS, selalu format 24 jam (kebiasaan Indonesia).
Future<TimeOfDay?> showIosTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String? helpText,
  String? cancelText,
  String? confirmText,
}) {
  var value = initialTime;
  return showSmoothSheet<TimeOfDay>(
    context: context,
    builder: (_) => _PickerSheet<TimeOfDay>(
      title: helpText ?? 'Pilih jam',
      cancelText: cancelText ?? 'Batal',
      confirmText: confirmText ?? 'Pilih',
      read: () => value,
      picker: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        use24hFormat: true,
        initialDateTime: DateTime(2000, 1, 1, initialTime.hour, initialTime.minute),
        onDateTimeChanged: (d) => value = TimeOfDay(hour: d.hour, minute: d.minute),
      ),
    ),
  );
}

/// Isi lembar pemilih: baris aksi (batal, judul, pilih) di atas roda setinggi 216 px (ukuran baku iOS).
class _PickerSheet<T> extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.cancelText,
    required this.confirmText,
    required this.read,
    required this.picker,
  });
  final String title;
  final String cancelText;
  final String confirmText;

  /// Nilai terakhir yang ditunjuk roda saat tombol pilih ditekan.
  final T Function() read;
  final Widget picker;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(cancelText)),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, read()),
              child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        SizedBox(height: 216, child: picker),
      ]),
    );
  }
}

/// Nama bulan bahasa Indonesia untuk roda tanggal. Aplikasi belum memasang paket lokalisasi penuh,
/// jadi hanya nama bulan yang diganti; teks lain memakai bawaan.
class _IdMonths extends DefaultCupertinoLocalizations {
  const _IdMonths();
  static const _names = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  String datePickerMonth(int monthIndex) => _names[monthIndex - 1];

  @override
  String datePickerStandaloneMonth(int monthIndex) => _names[monthIndex - 1];
}

class _IdMonthsDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const _IdMonthsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) => SynchronousFuture<CupertinoLocalizations>(const _IdMonths());

  @override
  bool shouldReload(_IdMonthsDelegate old) => false;
}
