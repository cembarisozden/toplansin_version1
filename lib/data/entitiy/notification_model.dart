import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;        // Firestore doc ID
  final String userId;
  final String type;
  final String eventId;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? expireAt;   // ✅ TTL için eklendi
  final String? newStatus;
  bool read;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.eventId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.expireAt, // ✅
    this.newStatus,
    this.read = false,
  });

  factory NotificationModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id:        doc.id,
      userId:    data['userId'] as String,
      type:      data['type'] as String,
      eventId:   data['eventId'] as String,
      title:     data['title'] as String,
      body:      data['body'] as String,
      newStatus: data['newStatus'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expireAt:  data['expireAt'] != null
          ? (data['expireAt'] as Timestamp).toDate()
          : null,
      read:      data['read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId':    userId,
    'type':      type,
    'eventId':   eventId,
    'title':     title,
    'body':      body,
    'newStatus': newStatus ?? '',
    'createdAt': Timestamp.fromDate(createdAt),
    'expireAt':  expireAt != null ? Timestamp.fromDate(expireAt!) : null, // ✅
    'read':      read,
  };
}
