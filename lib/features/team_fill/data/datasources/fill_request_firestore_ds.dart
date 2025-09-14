import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toplansin/features/team_fill/data/dto/fill_request_dto.dart';
import 'package:toplansin/services/time_service.dart';

class FillRequestFirestoreDs {
  final FirebaseFirestore _db;

  FillRequestFirestoreDs(this._db);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('fill_requests');

  Stream<List<FillRequestDto>> listOpen(
      {String? city, int limit = 50, DateTime? nowUtc}) {
    final now = TimeService.nowUtc();
    Query<Map<String, dynamic>> _query = _col
        .where('status', isEqualTo: 'open')
        .where('matchTime', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('matchTime')
        .limit(limit);

    if (city == null) {
      _query= _query.where('city',isEqualTo: city);
    }

    final snapshot = _query.snapshots();
    return snapshot.map((event) =>
        event.docs.map((doc) => FillRequestDto.fromFirestore(doc)).toList());
  }

  Future<FillRequestDto?> fetchById({required String requestId}) async {
    final _query = _col.doc(requestId);

    final snapshot = await _query.get();
    if (!snapshot.exists) return null;
    return FillRequestDto.fromFirestore(snapshot);
  }

  Stream<FillRequestDto?> streamById({required String requestId}) {
    return _col.doc(requestId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return FillRequestDto.fromFirestore(doc);
    });
  }

  Stream<List<FillRequestDto>> listMine(
      {required String requestOwnerId, int limit = 50}) {
    final _query = _col
        .where('requestOwnerId', isEqualTo: requestOwnerId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    return _query.snapshots().map((qs) =>
        qs.docs.map((doc) => FillRequestDto.fromFirestore(doc)).toList());
  }

}
