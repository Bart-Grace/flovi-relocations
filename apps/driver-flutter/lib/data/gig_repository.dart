import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/relocation_request.dart';

class GigRepository {
  GigRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Booking is ONE call: the RPC.
  ///
  /// Do NOT read the row first and check `status == 'open'` in Dart. That is a
  /// time-of-check/time-of-use race: two drivers tapping within the same second both
  /// read `open`, both pass the check, and both proceed to write. The guard is the
  /// single conditional UPDATE inside `book_request` and it lives nowhere else —
  /// under READ COMMITTED the loser blocks on the row lock, re-evaluates its WHERE
  /// against the committed row, matches nothing, and the function raises.
  ///
  /// Errors are not translated here. `book_request` already returns the sentence the
  /// driver should read — "This gig is no longer available" — and rewording it in the
  /// client is how a message drifts away from the behaviour it describes.
  /// Gigs belonging to this driver, live.
  ///
  /// This used to carry a server-side `.eq('driver_id', …)`, with a note saying the filter
  /// would have to move client-side the moment a release button existed. That moment
  /// arrived. `release_request` clears `driver_id`, so the row leaves the filter — and
  /// SupabaseStreamBuilder pushes stream filters onto the realtime subscription while its
  /// UPDATE branch only ever replaces or appends. The release would never be delivered and
  /// the gig would hang in My gigs forever.
  ///
  /// So the predicate lives in the caller now, exactly as it does in AvailableGigsPage.
  Stream<List<Map<String, dynamic>>> allRequests() {
    return _client
        .from('relocation_requests')
        .stream(primaryKey: ['id'])
        .order('pickup_date', ascending: true);
  }

  Future<RelocationRequest> book(String id) async {
    final row = await _client.rpc<dynamic>(
      'book_request',
      params: {'p_request_id': id},
    );
    return RelocationRequest.fromMap(Map<String, dynamic>.from(row as Map));
  }

  /// Give a booked gig back. Same shape as [book]: one guarded UPDATE inside
  /// `release_request`, which checks the row is still yours and still booked. The
  /// function shipped with the very first migration and only now has a button —
  /// the guard was never the thing that was missing.
  Future<RelocationRequest> release(String id) async {
    final row = await _client.rpc<dynamic>(
      'release_request',
      params: {'p_request_id': id},
    );
    return RelocationRequest.fromMap(Map<String, dynamic>.from(row as Map));
  }
}
