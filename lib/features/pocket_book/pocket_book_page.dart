import 'package:flutter/material.dart';

import '../../shared/models/modules.dart';
import '../modules/module_list_view.dart';

/// Buku Saku: tab "Saya" (pribadi) terpisah dari "Organisasi" (informasi bersama).
class PocketBookPage extends StatelessWidget {
  const PocketBookPage({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Buku Saku'),
            bottom: TabBar(
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              indicator: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              labelStyle: const TextStyle(fontWeight: FontWeight.w800),
              tabs: const [
                Tab(height: 48, text: 'Buku Saku Saya'),
                Tab(height: 48, text: 'Organisasi'),
              ],
            ),
          ),
          body: TabBarView(children: [
            ModuleListView(module: modules['notes']!),
            ModuleListView(module: modules['org_book']!),
          ]),
        ),
      );
}

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Informasi PERKAPI')),
        body: ModuleListView(module: modules['announcements']!),
      );
}
