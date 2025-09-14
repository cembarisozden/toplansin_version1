import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toplansin/features/team_fill/domain/entities/fill_request.dart';

class FillRequestDto {
  final String id;                 // doc.id (alanlarda saklanmaz)
  final String requestOwnerId;     // Firestore alan adı: requestOwnerId
  final String city;
  final int neededCount;
  final int acceptedCount;
  final Timestamp matchTime;       // Firestore tipi
  final String? level;             // opsiyonel
  final List<String>? positions;   // opsiyonel
  final String? note;              // opsiyonel
  final String status;             // "open" | "filled" | "cancelled" | "expired"
  final Timestamp createdAt;

  FillRequestDto({
    required this.id,
    required this.requestOwnerId,
    required this.city,
    required this.neededCount,
    required this.acceptedCount,
    required this.matchTime,
    this.level,
    this.positions,
    this.note,
    required this.status,
    required this.createdAt,
  });

  /// Firestore'a yazarken: id'yi YAZMA!
  Map<String, dynamic> toFirestore() => {
    'requestOwnerId': requestOwnerId,
    'city': city,
    'neededCount': neededCount,
    'acceptedCount': acceptedCount,
    'matchTime': matchTime,
    'level': level,
    'positions': positions,
    'note': note,
    'status': status,
    'createdAt': createdAt,
  }..removeWhere((k, v) => v == null);

  /// Firestore'dan okurken: id + data birlikte alınır
  factory FillRequestDto.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data()!;
    return FillRequestDto(
      id: doc.id,
      requestOwnerId: data['requestOwnerId'] as String,
      city: data['city'] as String,
      neededCount: (data['neededCount'] ?? 0) as int,
      acceptedCount: (data['acceptedCount'] ?? 0) as int,
      matchTime: data['matchTime'] as Timestamp,
      level: data['level'] as String?,
      positions: (data['positions'] as List?)?.map((e) => e.toString()).toList(),
      note: data['note'] as String?,
      status: data['status'] as String,
      createdAt: data['createdAt'] as Timestamp,
    );
  }

  /// DTO -> Domain Entity (UTC normalizasyonu)
  FillRequest toEntity() {
    return FillRequest(
      id: id,
      requestOwnerId: requestOwnerId,             // entity alan adıyla birebir
      city: city,
      neededCount: neededCount,
      acceptedCount: acceptedCount,
      matchTime: matchTime.toDate().toUtc(),      // DateTime(UTC)
      status: status,
      createdAt: createdAt.toDate().toUtc(),      // DateTime(UTC)
      level: level,
      positions: positions,
      note: note,
    );
  }

  /// (Opsiyonel) Entity -> DTO (ör. create/update için)
  factory FillRequestDto.fromEntity(FillRequest e) {
    return FillRequestDto(
      id: e.id,
      requestOwnerId: e.requestOwnerId,                 // tutarlı isim
      city: e.city,
      neededCount: e.neededCount,
      acceptedCount: e.acceptedCount,
      matchTime: Timestamp.fromDate(e.matchTime),       // Entity DateTime -> TS
      level: e.level,
      positions: e.positions,
      note: e.note,
      status: e.status,
      createdAt: Timestamp.fromDate(e.createdAt),
    );
  }
}
