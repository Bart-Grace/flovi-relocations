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
  /// Here the server-side filter IS safe, unlike the Available list. A row can only
  /// leave this filter if `driver_id` is cleared, and the only thing that clears it is
  /// `release_request` — which has no UI in this build. A dispatcher cancelling a booked
  /// gig sets `status = 'cancelled'` and **keeps** the driver, by design of the
  /// booked_requires_driver CHECK, so that update stays inside the filter and is
  /// delivered normally.
  ///
  /// If a release button is ever added, this filter has to move client-side for the same
  /// reason it had to in AvailableGigsPage: SupabaseStreamBuilder pushes stream filters
  /// onto the realtime subscription, and its UPDATE branch never removes a record.
  Stream<List<Map<String, dynamic>>> myGigs(String driverId) {
    return _client
        .from('relocation_requests')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .order('pickup_date', ascending: true);
  }

  Future<RelocationRequest> book(String id) async {
    final row = await _client.rpc<dynamic>(
      'book_request',
      params: {'p_request_id': id},
    );
    return RelocationRequest.fromMap(Map<String, dynamic>.from(row as Map));
  }
}
