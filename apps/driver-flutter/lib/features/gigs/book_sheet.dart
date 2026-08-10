import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/gig_repository.dart';
import '../../models/relocation_request.dart';

/// A bottom sheet, not a default-styled AlertDialog: this is the confirmation step
/// in the demo's money shot and it is what the camera is pointed at.
Future<void> showBookSheet(BuildContext context, RelocationRequest request) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _BookSheet(request: request),
  );
}

class _BookSheet extends StatefulWidget {
  const _BookSheet({required this.request});
  final RelocationRequest request;

  @override
  State<_BookSheet> createState() => _BookSheetState();
}

class _BookSheetState extends State<_BookSheet> {
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await GigRepository().book(widget.request.id);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Booked ${widget.request.route}.')),
      );
      // The row leaves the Available list through the stream — its status is no longer
      // 'open', so the server stops sending it. Nothing is removed by hand here.
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      navigator.pop();
      // VERBATIM. book_request already says exactly what the driver needs to hear.
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = widget.request;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Book this gig', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.route_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(r.route, style: theme.textTheme.titleSmall)),
              ],
            ),
            const SizedBox(height: 12),
            _Line(label: 'Pickup', value: _date(r.pickupDate)),
            _Line(label: 'Payout', value: r.priceLabel),
            if (r.vehicleType != null && r.vehicleType!.isNotEmpty)
              _Line(label: 'Vehicle', value: r.vehicleType!),
            if (r.notes != null && r.notes!.isNotEmpty) _Line(label: 'Notes', value: r.notes!),
            const SizedBox(height: 24),
            FilledButton(
              // Disabled while the call is in flight: a double tap must not become
              // two RPC calls.
              onPressed: _busy ? null : _confirm,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm booking'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }

  static String _date(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
