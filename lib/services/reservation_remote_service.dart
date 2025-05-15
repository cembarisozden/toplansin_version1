import 'package:cloud_functions/cloud_functions.dart';

class ReservationRemoteService {
  final _functions = FirebaseFunctions.instance;

  /// bookedSlots'a yeni slot ekler (rezervasyon oluşturma)
  Future<bool> reserveSlot({
    required String haliSahaId,
    required String bookingString,
  }) async {
    try {
      final callable =
      _functions.httpsCallable("reserveSlotAndUpdateBookedSlots");

      final result = await callable.call({
        "haliSahaId": haliSahaId,
        "bookingString": bookingString,
      });

      return result.data["success"] == true;
    } catch (e) {
      print("❌ Slot rezerve edilirken hata: $e");
      return false;
    }
  }

  /// bookedSlots'tan slot siler (iptal durumunda)
  Future<bool> cancelSlot({
    required String haliSahaId,
    required String bookingString,
  }) async {
    try {
      final callable =
      _functions.httpsCallable("cancelSlotAndUpdateBookedSlots");

      final result = await callable.call({
        "haliSahaId": haliSahaId,
        "bookingString": bookingString,
      });

      return result.data["success"] == true;
    } catch (e) {
      print("❌ Slot iptali sırasında hata: $e");
      return false;
    }
  }
}
