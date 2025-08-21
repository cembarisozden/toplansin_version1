import 'package:cloud_firestore/cloud_firestore.dart';

/// fields/{fieldId}/accessCodes/{codeId} dökümanını temsil eder
class AccessCode {
  final String id;
  final String code;
  final DateTime createdAt;
  final String createdBy;
  final bool isActive;
  final DateTime? deactivatedAt;

  AccessCode({
    required this.id,
    required this.code,
    required this.createdAt,
    required this.createdBy,
    required this.isActive,
    this.deactivatedAt,
  });

  factory AccessCode.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AccessCode(
      id: doc.id,
      code: data['code'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] as String,
      isActive: data['isActive'] as bool,
      deactivatedAt: data['deactivatedAt'] != null
          ? (data['deactivatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'createdAt': FieldValue.serverTimestamp(),
    'createdBy': createdBy,
    'isActive': isActive,
    'deactivatedAt': deactivatedAt != null
        ? Timestamp.fromDate(deactivatedAt!)
        : null,
  };
}
