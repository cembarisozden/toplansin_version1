import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toplansin/data/entitiy/subscription.dart';
import 'package:intl/intl.dart';

Future<void> aboneOl(Subscription sub) async {
  final subscriptionRef =
  FirebaseFirestore.instance.collection('subscriptions');

  await subscriptionRef.add(sub.toMap());

  print("✅ Abonelik isteği gönderildi.");
}

Future<void> aboneIstegiIptalEt(String subscriptionDocId) async {
  try {
    await FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(subscriptionDocId)
        .update({'status': 'İptal Edildi'});
  } catch (e) {
    throw Exception("Abonelik isteği iptal edilemedi: $e");
  }
}

String calculateFirstSession(DateTime createdAt, int dayOfWeek, String time) {
  // Pazartesi = 1, Pazar = 7
  int currentWeekday = createdAt.weekday;

  // Aynı haftadaki hedef güne kalan gün + 7 (daima bir sonraki hafta)
  int daysUntilTarget = (dayOfWeek - currentWeekday + 7) % 7;
  int dayOffset = daysUntilTarget + 7;

  DateTime targetDay = createdAt.add(Duration(days: dayOffset));

  // Saat ayır
  final startTime = time.split('-').first;
  final hourMinute = startTime.split(':');
  final hour = int.parse(hourMinute[0]);
  final minute = int.parse(hourMinute[1]);

  final sessionDateTime = DateTime(
    targetDay.year,
    targetDay.month,
    targetDay.day,
    hour,
    minute,
  );

  final formattedDate = DateFormat("yyyy-MM-dd").format(sessionDateTime);
  return "$formattedDate $time"; // ex: 2025-05-26 20:00-21:00
}

String calculateNextSession(String currentSession) {
  // currentSession: "2025-04-05 12:00-13:00"
  List<String> parts = currentSession.split(" ");
  if (parts.length != 2) return currentSession;

  String datePart = parts[0]; // "2025-04-05"
  String timePart = parts[1]; // "12:00-13:00"

  // 🔧 Doğru formatla parse et
  DateTime date = DateFormat("yyyy-MM-dd").parse(datePart);

  DateTime nextDate = date.add(Duration(days: 7));
  String nextDateStr = DateFormat("yyyy-MM-dd").format(nextDate);

  return "$nextDateStr $timePart";
}

