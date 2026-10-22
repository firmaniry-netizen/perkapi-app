import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_assets.dart';

/// Baris logo mitra/instansi ("Didukung oleh") di atas kotak putih agar logo resmi
/// tetap terbaca di tema gelap. Logo yang filenya tidak ada otomatis dilewati;
/// bila tidak ada satu pun, widget ini tidak menampilkan apa-apa.
class PartnerLogos extends StatefulWidget {
  const PartnerLogos({super.key, this.height = 36});
  final double height;
  @override
  State<PartnerLogos> createState() => _PartnerLogosState();
}

class _PartnerLogosState extends State<PartnerLogos> {
  static const _paths = [
    AppAssets.logoKementerian,
    AppAssets.logoAhu,
    AppAssets.logoGovernment,
  ];
  late final Future<List<String>> _existing = _find();

  Future<List<String>> _find() async {
    final out = <String>[];
    for (final p in _paths) {
      try {
        await rootBundle.load(p);
        out.add(p);
      } catch (_) {
        // file tidak ada: lewati
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _existing,
      builder: (context, snap) {
        final list = snap.data ?? const <String>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Didukung oleh',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 18,
              runSpacing: 8,
              children: [
                for (final p in list)
                  Image.asset(p, height: widget.height, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ],
            ),
          ),
        ]);
      },
    );
  }
}
