class Subscription {
  final String docId;
  final String halisahaId;
  final String userId;
  final String halisahaName;
  final String location;
  final int dayOfWeek;
  final String time;
  final num price;
  final String startDate;
  final String endDate;
  final String nextSession;
  final String status;

  Subscription({
    required this.docId,
    required this.halisahaId,
    required this.userId,
    required this.halisahaName,
    required this.location,
    required this.dayOfWeek,
    required this.time,
    required this.price,
    required this.startDate,
    required this.endDate,
    required this.nextSession,
    required this.status,
  });

  factory Subscription.fromMap(Map<String, dynamic> map, String docId) {
    return Subscription(
      docId: docId,
      halisahaId: map['halisahaId'],
      userId: map['userId'],
      halisahaName: map['halisahaName'] ?? 'Bilinmiyor',
      location: map['location'] ?? 'Bilinmiyor',
      dayOfWeek: map['dayOfWeek'] ?? 1,
      price: map['price'] ?? 0,
      time: map['time'] ?? '00:00-01:00',
      startDate: map['startDate'],
      endDate: map['endDate'],
      nextSession: map['nextSession'] ?? 'Bekleniyor',
      status: map['status'] ?? 'Bilinmiyor',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'docId': docId,
      'halisahaId': halisahaId,
      'userId': userId,
      'halisahaName': halisahaName,
      'location': location,
      'dayOfWeek': dayOfWeek,
      'time': time,
      'price': price,
      'startDate': startDate,
      'endDate': endDate,
      'nextSession': nextSession,
      'status': status,
    };
  }
}

class SubscriptionStatus {
  static const String beklemede = "Beklemede";
  static const String aktif = "Aktif";
  static const String iptal = "İptal Edildi";
  static const String sonaErdi = "Sona Erdi";
}
