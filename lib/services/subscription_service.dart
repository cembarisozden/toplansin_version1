import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toplansin/data/entitiy/subscription.dart';
import 'package:intl/intl.dart';
import 'package:toplansin/services/time_service.dart';

Future<void> aboneOl(Subscription sub) async {
  final subscriptionRef =
      FirebaseFirestore.instance.collection('subscriptions');

  await subscriptionRef.add(sub.toMap());

  print("✅ Abonelik isteği gönderildi.");
}

Future<void> useraboneIstegiIptalEt(String subscriptionDocId) async {
  try {
    await FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(subscriptionDocId)
        .update({'status': 'İptal Edildi'});
  } catch (e) {
    throw Exception("Abonelik isteği iptal edilemedi: $e");
  }
}

Future<void> approveSubscription(String subscriptionId) async {
  final docRef = FirebaseFirestore.instance
      .collection('subscriptions')
      .doc(subscriptionId);

  try {
    await docRef.update({
      'status': 'Aktif',
      'lastUpdatedBy': 'owner',
    });

    print("✅ Abonelik onaylandı");
  } catch (e) {
    print("❌ Abonelik onaylama hatası: $e");
    rethrow;
  }
}

Future<void> cancelSubscription(String subscriptionId) async {
  await FirebaseFirestore.instance
      .collection('subscriptions')
      .doc(subscriptionId)
      .update({
    'status': 'İptal Edildi',
    'lastUpdatedBy': 'owner',
  });
}

Future<void> userCancelSubscription(String subscriptionId) async {
  await FirebaseFirestore.instance
      .collection('subscriptions')
      .doc(subscriptionId)
      .update({
    'status': 'İptal Edildi',
    'lastUpdatedBy': 'user',
  });
}

Future<void> ownerRejectSubscription(String subscriptionId) async {
  try {
    await FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(subscriptionId)
        .update({
      'status': 'İptal Edildi',
      'lastUpdatedBy': 'owner',
    });

    print("❌ Abonelik reddedildi");
  } catch (e) {
    print("🚨 Reddetme hatası: $e");
    // İstersen kullanıcıya hata gösterebilirsin:
    // ScaffoldMessenger.of(context).showSnackBar(
    //   SnackBar(content: Text('Abonelik reddedilirken hata oluştu.')),
    // );
  }
}

Future<void> addOwnerSubscription({
  required String halisahaId,
  required String halisahaName,
  required String location,
  required int dayOfWeek,
  required String time,
  required num price,
  required String ownerUserId,
  required String ownerName,
  required String ownerPhone,
  required String ownerEmail,
}) async {
  final createdAt = TimeService.now(); // sunucu zamanı
  final startDate = calculateFirstSession(createdAt, dayOfWeek, time);

  final subscription = Subscription(
    docId: '',
    halisahaId: halisahaId,
    userId: ownerUserId,
    halisahaName: halisahaName,
    location: location,
    dayOfWeek: dayOfWeek,
    time: time,
    price: price,
    startDate: startDate,
    endDate: '',
    nextSession: startDate,
    lastUpdatedBy: 'owner',
    status: 'Aktif',
    userName: ownerName,
    userPhone: ownerPhone,
    userEmail: ownerEmail,
  );

  await FirebaseFirestore.instance
      .collection('subscriptions')
      .add(subscription.toMap());

  print("✅ Owner tarafından abonelik oluşturuldu");
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

List<String> generateTimeSlots(String startHour, String endHour) {
  final startParts = startHour.split(':');
  final endParts = endHour.split(':');

  int startHourInt = int.parse(startParts[0]);
  int startMinute = int.parse(startParts[1]);
  int endHourInt = int.parse(endParts[0]);
  int endMinute = int.parse(endParts[1]);

  if (endHourInt < startHourInt ||
      (endHourInt == startHourInt && endMinute < startMinute)) {
    endHourInt += 24;
  }

  List<String> slots = [];
  for (int hour = startHourInt; hour < endHourInt; hour++) {
    int actualStartHour = hour % 24;
    int actualEndHour = (hour + 1) % 24;
    slots.add(
        '${actualStartHour.toString().padLeft(2, '0')}:00-${actualEndHour.toString().padLeft(2, '0')}:00');
  }

  slots.sort((a, b) {
    int aHour = int.parse(a.split(':')[0]);
    int bHour = int.parse(b.split(':')[0]);
    return aHour.compareTo(bHour);
  });

  return slots;
}

String getDayName(String id) {
  const dayMap = {
    "Pzt": "Pazartesi",
    "Sal": "Salı",
    "Çar": "Çarşamba",
    "Per": "Perşembe",
    "Cum": "Cuma",
    "Cmt": "Cumartesi",
    "Paz": "Pazar",
  };
  return dayMap[id] ?? id;
}

int getDayOfWeekNumber(String day) {
  const map = {
    "Pzt": 1,
    "Sal": 2,
    "Çar": 3,
    "Per": 4,
    "Cum": 5,
    "Cmt": 6,
    "Paz": 7,
  };
  return map[day]!;
}
