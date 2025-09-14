class FillRequest {
  final String id;
  final String requestOwnerId;
  final String city;
  final int neededCount;
  final int acceptedCount;
  final DateTime matchTime;
  final String? level;
  final List<String>? positions;
  final String? note;
  final String status;
  final DateTime createdAt;

  FillRequest(
      {required this.id,
      required this.requestOwnerId,
      required this.city,
      required this.neededCount,
      required this.acceptedCount,
      required this.matchTime,
      this.level,
      this.positions,
      this.note,
      required this.status,
      required this.createdAt})
      : assert(neededCount >= 1, 'neededCount must be ≥ 1'),
        assert(acceptedCount >= 0, 'acceptedCount must be ≥ 0'),
        assert(acceptedCount <= neededCount,
            'acceptedCount must be ≤ neededCount'),
        assert(
          status == 'open' ||
              status == 'filled' ||
              status == 'cancelled' ||
              status == 'expired',
          'invalid status',
        );

  int get remaining => (neededCount - acceptedCount).clamp(0, neededCount);

  bool get isOpen => status == 'open';
}
