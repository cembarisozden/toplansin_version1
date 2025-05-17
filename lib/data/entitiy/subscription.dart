class Subscription {
  final String halisahaId;
  final String userId;
  final String halisahaName;
  final String location;
  final String day;
  final String time;
  final num price;
  final String requestStatus;
  final String timeStatus;
  final DateTime startDate;
  final DateTime endDate;

  Subscription({
    required this.halisahaId,
    required this.userId,
    required this.halisahaName,
    required this.location,
    required this.day,
    required this.time,
    required this.price,
    required this.requestStatus,
    required this.timeStatus,
    required this.startDate,
    required this.endDate,
  });

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      halisahaId: map['halisahaId'],
      userId: map['userId'],
      halisahaName: map['halisahaName'],
      location: map['location'],
      day: map['day'],
      price: map['price'],
      time: map['time'],
      requestStatus: map['requestState'],
      timeStatus: map['timeState'],
      startDate: map['startDate'],
      endDate: map['endDate'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'halisahaId': halisahaId,
      'userId': userId,
      'halisahaName': halisahaName,
      'location': location,
      'day': day,
      'time': time,
      'price': price,
      'requestState': requestStatus,
      'timeState': timeStatus,
      'startDate': startDate,
      'endDate': endDate,
    };
  }
}
