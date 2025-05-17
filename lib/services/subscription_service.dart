import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toplansin/data/entitiy/subscription.dart';

Future<void> aboneOl(Subscription sub) async {
  final subscriptionRef =
      FirebaseFirestore.instance.collection('subscriptions');

  await subscriptionRef.add(sub.toMap());

  print("✅ Abonelik isteği gönderildi.");
}
