import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// Merkezi hata yöneticisi ― tüm katmanlardan gelen hataları kullanıcı‑dostu
/// metinlere dönüştürür. Yeni ekranda yalnızca
/// `AppErrorHandler.getMessage(error, context: 'reservation')` çağrısı yeterlidir.
///
/// * [context] parametresi eşleşen "not‑found" mesajını özelleştirir.
/// * Kod olabildiğince kapsayıcı tutulmuştur; bilinmeyen her şey _unknown ile biter.
class AppErrorHandler {
  /// Ana erişim noktası.
  static String getMessage(
      dynamic error, {
        String context = '',
      }) {
    if (error == null) return _unknown;

    debugPrint('❌ [HATA]: ${error.toString()}');
    debugPrint('[AppError] ${error.runtimeType}: $error');

    // 1️⃣ Firebase Authentication
    if (error is FirebaseAuthException) return _auth(error);

    // 2️⃣ Diğer FirebaseException (Firestore, Storage, Functions, Messaging…)
    if (error is FirebaseException) {
      return _firebase(error, context: context);
    }

    // 3️⃣ Platform kanal hataları (örn. MethodChannel)
    if (error is PlatformException) {
      return error.message ?? _unknown;
    }

    // 4️⃣ Ağ & IO hataları
    if (error is SocketException) return 'İnternet bağlantısı yok.';
    if (error is TimeoutException) {
      return 'İşlem zaman aşımına uğradı. Lütfen tekrar deneyin.';
    }
    if (error is HttpException) {
      return 'Sunucuya ulaşılamıyor. Lütfen tekrar deneyin.';
    }

    // 5️⃣ Format/parsing (ör. JSON decode)
    if (error is FormatException) {
      return 'Beklenmedik veri biçimi alındı.';
    }

    // 6️⃣ Dio desteği (paket eklenmişse tip adı üzerinden algıla ‑ import gerekmez)
    if (error.runtimeType.toString() == 'DioException' ||
        error.runtimeType.toString() == 'DioError') {
      final dynamic dio = error; // dynamic cast
      final int? statusCode = dio.response?.statusCode as int?;
      if (statusCode == 401 || statusCode == 403) return 'Bu işlemi yapmaya yetkiniz yok.';
      if (statusCode == 404) return _notFound(context);
      if (statusCode == 408) return 'İstek zaman aşımına uğradı.';
      if (statusCode == 429) return 'Çok fazla istek. Bir süre sonra tekrar deneyin.';
      if (statusCode == 500) return 'Sunucu hatası. Lütfen daha sonra tekrar deneyin.';
      return 'Bağlantı hatası. Lütfen tekrar deneyin.';
    }


    // 7️⃣ String eşleştirmeleri (geliştirici eksik yakaladıysa)
    final str = error.toString();
    if (str.contains('permission-denied')) return 'Bu işlemi yapmaya yetkiniz yok.';
    if (str.contains('network-request-failed')) return 'İnternet bağlantısı yok.';
    if (str.contains('not-found')) return _notFound(context);
    if (str.contains('already-exists')) return 'Bu kayıt zaten mevcut.';
    if (str.contains('quota-exceeded')) {
      return 'Depolama kotası aşıldı. Lütfen yöneticinize başvurun.';
    }

    if (str.contains('play_integrity_token') || str.contains('not authorized to use Firebase')) {
      return 'Uygulama Firebase ile yapılandırılmamış. Lütfen yöneticinize başvurun.';
    }


    // 8️⃣ Son çare: bilinmeyen hata
    return _unknown;
  }

  // ------------------------------------------------------------
  // 🔒 Firebase Auth hata kodları
  // ------------------------------------------------------------
  static String _auth(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Geçersiz e‑posta adresi.';
      case 'user-disabled':
        return 'Hesabınız devre dışı bırakılmış.';
      case 'user-not-found':
        return 'Kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu e‑posta zaten kayıtlı.';
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter olmalı.';
      case 'requires-recent-login':
        return 'Lütfen yeniden giriş yapın.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Bir süre bekleyin.';
      case 'invalid-credential':
        return 'Geçersiz kimlik bilgisi. Lütfen tekrar deneyin.';
      case 'credential-already-in-use':
        return 'Bu kimlik bilgisi başka bir hesapta kullanılıyor.';
      case 'account-exists-with-different-credential':
        return 'Bu e‑posta farklı bir giriş yöntemiyle kayıtlı.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok.';
      case 'operation-not-allowed':
        return 'Bu giriş yöntemi şu anda devre dışı.';
      case 'invalid-action-code':
      case 'expired-action-code':
        return 'Bağlantı geçersiz veya süresi dolmuş.';
      case 'invalid-verification-code':
        return 'Doğrulama kodu hatalı.';
      case 'session-expired':
        return 'Oturum süresi doldu. Lütfen yeniden deneyin.';
      case 'user-mismatch':
        return 'Kimlik bilgisi farklı bir kullanıcıya ait.';
      case 'provider-already-linked':
        return 'Bu sağlayıcı zaten hesabınıza bağlı.';
      case 'multi-factor-auth-required':
        return 'Ek doğrulama gerekli. Lütfen yönergeleri izleyin.';
      case 'popup-closed-by-user':
        return 'İşlem iptal edildi.';

      default:
        return 'Giriş sırasında bir hata oluştu.';
    }
  }

  // ------------------------------------------------------------
  // 🔧 Diğer FirebaseException kodları
  // ------------------------------------------------------------
  static String _firebase(
      FirebaseException e, {
        required String context,
      }) {
    switch (e.code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'Bu işlemi yapmaya yetkiniz yok.';
      case 'unavailable':
        return 'Sunucu şu anda kullanılamıyor. Lütfen daha sonra tekrar deneyin.';
      case 'deadline-exceeded':
        return 'İstek zaman aşımına uğradı.';
      case 'already-exists':
        return 'Bu kayıt zaten mevcut.';
      case 'not-found':
        return _notFound(context);
      case 'resource-exhausted':
        return 'Kota aşıldı. Lütfen sonra tekrar deneyin.';
      case 'aborted':
      case 'internal':
        return 'Sunucu hatası oluştu. Lütfen tekrar deneyin.';
      case 'invalid-argument':
        return 'Geçersiz istek. Lütfen alanları kontrol edin.';
      case 'failed-precondition':
        return 'Ön koşullar sağlanmadı. Lütfen işlemi tekrar deneyin.';
      case 'out-of-range':
        return 'İstenen veri aralık dışında.';
      case 'cancelled':
        return 'İşlem iptal edildi.';
      case 'unknown':
        return 'Bilinmeyen bir hata oluştu.';
      case 'data-loss':
        return 'Veri kaybı oluştu. Lütfen tekrar deneyin.';
      case 'unimplemented':
        return 'Bu özellik henüz kullanılamıyor.';

      default:
        return _unknown;
    }
  }

  // ------------------------------------------------------------
  // 📄 "not‑found" bağlam mesajları
  // ------------------------------------------------------------
  static String _notFound(String context) {
    switch (context) {
      case 'review':
        return 'Yorum bulunamadı veya silinmiş.';
      case 'reservation':
        return 'Rezervasyon bulunamadı veya silinmiş.';
      case 'field':
        return 'Halı saha kaydı bulunamadı.';
      case 'subscription':
        return 'Abonelik kaydı bulunamadı.';
      case 'fill_request':            // 🔹 yeni: team_fill list/detail için
        return 'İlan bulunamadı veya silinmiş.';
      default:
        return 'İlgili kayıt bulunamadı.';
    }
  }

  // ------------------------------------------------------------
  // 🔚 Genel bilinmeyen mesaj
  // ------------------------------------------------------------
  static const String _unknown = 'Bir hata oluştu. Lütfen daha sonra tekrar deneyin.';
}
