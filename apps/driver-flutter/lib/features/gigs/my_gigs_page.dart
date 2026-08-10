import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/gig_repository.dart';
import '../../models/relocation_request.dart';
import 'gig_card.dart';

class MyGigsPage extends StatefulWidget {
  const MyGigsPage({super.key, this.onBrowseAvailable});

  /// CTA target for the empty state — takes the driver back to the Available tab.
  final VoidCallback? onBrowseAvailable;

  @override
  State<MyGigsPage> createState() => _MyGigsPageState();
}

class _MyGigsPageState extends State<MyGigsPage> {
  // Field, initialised once. The page lives inside an IndexedStack, so this
  // subscription survives every tab switch instead of being rebuilt.
  late final Stream<List<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    final uid = Supabase.instance.client.auth.currentUser!.id;
    _stream = GigRepository().myGigs(uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _EmptyMyGigs(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load your gigs',
            body: '${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final gigs = snapshot.data!.map(RelocationRequest.fromMap).toList();
        if (gigs.isEmpty) {
          return _EmptyMyGigs(
            icon: Icons.local_shipping_outlined,
            title: 'No gigs booked yet',
            body: 'Everything you book shows up here, with its current status.',
            ctaLabel: 'Browse available gigs',
            onCta: widget.onBrowseAvailable,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: gigs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => GigCard(request: gigs[i]),
        );
      },
    );
  }
}

/// An illustrated empty state with one line of copy and a way out — never Text('No gigs').
class _EmptyMyGigs extends StatelessWidget {
  const _EmptyMyGigs({
    required this.icon,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.onCta,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 96,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 14,
                    child: Container(
                      width: 34,
                      height: 6,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 16,
                    child: Container(
                      width: 22,
                      height: 6,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Icon(icon, size: 28, color: scheme.primary),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (ctaLabel != null) ...[
              const SizedBox(height: 18),
              FilledButton.tonal(onPressed: onCta, child: Text(ctaLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
