import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:go_router/go_router.dart';

import 'alert_service.dart';
import 'alert_style.dart';
import '../../core/constants/app_tokens.dart';

/// Banner peringatan penting/peringatan yang belum dibaca (dashboard).
class AlertBanner extends StatelessWidget {
  const AlertBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AlertService.instance,
      builder: (context, _) {
        final list = AlertService.instance.highlights;
        if (list.isEmpty) return const SizedBox.shrink();
        list.sort((a, b) => (b.severity == 'urgent' ? 1 : 0) - (a.severity == 'urgent' ? 1 : 0));
        final top = list.first;
        final s = AlertStyle.of(top.severity);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: s.color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppRadius.button),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.button),
              onTap: () => context.push('/alerts'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(s.icon, color: s.color, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(top.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: s.color, fontWeight: FontWeight.w800, fontSize: AppType.lead)),
                      if (list.length > 1)
                        Text('+${list.length - 1} peringatan lainnya',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: AppType.caption)),
                    ]),
                  ),
                  Icon(CupertinoIcons.chevron_right, color: s.color),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
