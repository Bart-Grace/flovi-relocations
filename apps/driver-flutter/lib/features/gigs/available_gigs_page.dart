import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/relocation_request.dart';
import 'book_sheet.dart';
import 'gig_card.dart';

class AvailableGigsPage extends StatefulWidget {
  const AvailableGigsPage({super.key});

  @override
  State<AvailableGigsPage> createState() => _AvailableGigsPageState();
}

class _AvailableGigsPageState extends State<AvailableGigsPage> {
  // The stream lives in a field, initialised once in initState. Building it inline in
  // build() would tear down and re-subscribe on every rebuild.
  late final Stream<List<Map<String, dynamic>>> _stream;
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = Supabase.instance.client.auth.currentUser!.id;

    // NO server-side .eq('status', 'open') here, deliberately. Read the SDK:
    // SupabaseStreamBuilder converts stream filters into a PostgresChangeFilter on the
    // realtime subscription, so they are evaluated by the server — and its UPDATE handler
    // only ever replaces or appends a record, never removes one. An UPDATE that moves a
    // row OUT of the filter therefore never arrives, and the row stays in the local cache
    // forever: a booked gig would sit in the Available list until a reload.
    //
    // So the whole predicate lives in _visible() below. The stream carries every change to
    // the table and the client decides what is still available. That is also the only way
    // the row can leave this list *via the stream* rather than by being removed by hand.
    //
    // ascending: true is NOT the default in the Dart client — .order() sorts descending
    // unless told otherwise, the opposite of supabase-js. A driver wants the soonest
    // pickup first, so this argument is load-bearing.
    _stream = Supabase.instance.client
        .from('relocation_requests')
        .stream(primaryKey: ['id'])
        .order('pickup_date', ascending: true);
  }

  /// The entire predicate, client-side. See the note in initState for why none of it
  /// can be pushed to the server.
  ///
  /// The second condition hides gigs this user dispatched themselves: book_request
  /// rejects those via `dispatcher_id <> v_uid` and raises "This gig is no longer
  /// available" — the right refusal carrying the wrong reason. Better never to offer
  /// the button than to explain a misleading error.
  List<RelocationRequest> _visible(List<Map<String, dynamic>> rows) => rows
      .map(RelocationRequest.fromMap)
      .where((r) => r.status == 'open' && r.dispatcherId != _uid)
      .toList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _Centered(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load gigs',
            body: '${snapshot.error}',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final gigs = _visible(snapshot.data!);
        if (gigs.isEmpty) {
          return const _Centered(
            icon: Icons.explore_outlined,
            title: 'No open gigs right now',
            body: 'New relocation requests appear here the moment a dispatcher creates one.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: gigs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => GigCard(
            request: gigs[i],
            onTap: () => showBookSheet(context, gigs[i]),
            trailing: FilledButton.tonal(
              onPressed: () => showBookSheet(context, gigs[i]),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(42)),
              child: const Text('Book'),
            ),
          ),
        );
      },
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 24, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
