import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:get/get.dart';

class PhoneVerificationProvider with ChangeNotifier {
  String? _error;
  bool _isVerifying = false;
  final _auth = FirebaseAuth.instance;
  var verificationId = ''.obs;

  // ----- getters -----
  bool get isVerifying => _isVerifying;

  bool get isPhoneVerified =>
      FirebaseAuth.instance.currentUser?.phoneNumber != null;

  String? get error => _error;

  // ----- error helper -----
  void _setError(dynamic err) {
    if (err == null) {
      _error = null;
    } else {
      _error = AppErrorHandler.getMessage(err);
    }
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────── verify ──
  /// [phoneE164] parametresi **zaten +90 ile başlayan** E.164 biçiminde gelmeli
  Future<void> verifyPhone(String phoneE164) async {
    _isVerifying = true;
    _setError(null); // temizle & notify

    try {
      FirebaseAuth.instance.setLanguageCode('tr');

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneE164,
        // ❌ '+90' EKLENMEDİ
        verificationCompleted: (credential) async {
          await _auth.signInWithCredential(credential);
        },

        verificationFailed: (e) {
          print('❌ verificationFailed: ${e.code} – ${e.message}');
          _isVerifying = false;
          _setError(e);
        },
        codeSent: (verificationId, resendToken) {
          print('✅ codeSent → id: $verificationId');
          this.verificationId.value = verificationId;
          _isVerifying = false;
          notifyListeners();
        },
        codeAutoRetrievalTimeout: (verificationId) {
          this.verificationId.value = verificationId;
          _isVerifying = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _isVerifying = false;
      _setError(e);
    }
  }

  Future<bool> verifyOtp(String otp) async {
    var credentials = await _auth.signInWithCredential(PhoneAuthProvider.credential(
        verificationId: verificationId.value, smsCode: otp));

    return credentials.user != null ? true : false;
  }

  // ───────────────────────────────────────────────────────── code ──
  /* Future<void> submitCode(String smsCode) async {
    if (this.verificationId.isEmpty) return;

    _isVerifying = true;
    _setError(null);

    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: this.verificationId.value,
        smsCode: smsCode,
      );
      await FirebaseAuth.instance.currentUser?.linkWithCredential(cred);
    } catch (e) {
      _setError(e);
    }

    _isVerifying = false;
    notifyListeners();
  }*/

  // ───────────────────────────────────────────────────────── update ──
  Future<void> updatePhoneNumber(String phoneForStore) async {
    print(phoneForStore);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _setError("Kullanıcı oturum açmamış.");
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'phone': phoneForStore});

      _setError(null); // başarı → hata temizle
    } catch (e) {
      _setError(e);
    }
  }
}
