/// Mirrors supabase/migrations/0001_init.sql. The schema is the source of truth:
/// propose a migration, never invent a column.
class RelocationRequest {
  const RelocationRequest({
    required this.id,
    required this.dispatcherId,
    required this.origin,
    required this.destination,
    required this.pickupDate,
    required this.status,
    required this.priceCents,
    this.notes,
    this.vehicleType,
    this.driverId,
  });

  final String id;
  final String dispatcherId;
  final String origin;
  final String destination;
  final DateTime pickupDate;
  final String status;
  final int priceCents;
  final String? notes;
  final String? vehicleType;
  final String? driverId;

  factory RelocationRequest.fromMap(Map<String, dynamic> map) {
    return RelocationRequest(
      id: map['id'] as String,
      dispatcherId: map['dispatcher_id'] as String,
      origin: map['origin'] as String,
      destination: map['destination'] as String,
      pickupDate: DateTime.parse(map['pickup_date'] as String),
      status: map['status'] as String,
      priceCents: (map['price_cents'] as num?)?.toInt() ?? 0,
      notes: map['notes'] as String?,
      vehicleType: map['vehicle_type'] as String?,
      driverId: map['driver_id'] as String?,
    );
  }

  String get route => '$origin → $destination';

  String get priceLabel =>
      priceCents > 0 ? '€${(priceCents / 100).toStringAsFixed(2)}' : '—';
}
