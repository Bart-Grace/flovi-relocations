import 'package:flutter/material.dart';
import '../../models/relocation_request.dart';
import '../../theme.dart';

/// Origin → destination on ONE row led by a route icon. Not a bullet list of fields.
class GigCard extends StatelessWidget {
  const GigCard({super.key, required this.request, this.trailing, this.onTap});

  final RelocationRequest request;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = statusStyle(request.status, scheme);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.route_outlined, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.route,
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: status.bg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: status.fg, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status.label,
                          style: theme.textTheme.labelSmall?.copyWith(color: status.fg),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.event_outlined, size: 15, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(request.pickupDate),
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 14),
                  Icon(Icons.payments_outlined, size: 15, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    request.priceLabel,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              if (request.notes != null && request.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  request.notes!,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (trailing != null) ...[const SizedBox(height: 14), trailing!],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}
