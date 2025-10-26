class StartEndHours {
  int day;
  String startHour;
  String endHour;

  StartEndHours({
    required this.day,
    required this.startHour,
    required this.endHour,
  });

  /// JSON'dan nesneye dönüştürme
  factory StartEndHours.fromJson(Map<String, dynamic> json) {
    return StartEndHours(
      day: json['day'] as int,
      startHour: json['startHour'] as String,
      endHour: json['endHour'] as String,
    );
  }

  /// Nesneyi JSON'a dönüştürme
  Map<String, dynamic> toJson() {
    return {
      'day': day,
      'startHour': startHour,
      'endHour': endHour,
    };
  }
}
