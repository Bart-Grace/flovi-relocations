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
  Future<RelocationRequest> book(String id) async {
    final row = await _client.rpc<dynamic>(
      'book_request',
      params: {'p_request_id': id},
    );
    return RelocationRequest.fromMap(Map<String, dynamic>.from(row as Map));
  }
}
