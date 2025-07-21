import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';

class PhoneVerifyDialog extends StatefulWidget {
  const PhoneVerifyDialog({super.key, required this.onVerified});
  final VoidCallback onVerified;

  @override
  State<PhoneVerifyDialog> createState() => _PhoneVerifyDialogState();
}

class _PhoneVerifyDialogState extends State<PhoneVerifyDialog> {
  final formKey = GlobalKey<FormState>();
  final phoneCtrl = TextEditingController();
  final smsCtrl = TextEditingController();
  String? verifyId;
  bool smsSent = false;
  bool busy = false;
  String? errorMessage;

  // --- sayaç için eklenenler:
  Timer? _timer;
  int _secondsLeft = 30;
  bool _canResend = false;

  @override
  void dispose() {
    phoneCtrl.dispose();
    smsCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  InputDecoration _dec(String hint, {String? prefix}) => InputDecoration(
    hintText: hint,
    prefixText: prefix,
    filled: true,
    fillColor: Colors.grey.shade100,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14), gapPadding: 4),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  Future<void> _sendSms() async {
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;

    final raw = phoneCtrl.text.trim();
    final phone = '+90$raw';

    if (!RegExp(r'^\+905\d{9}$').hasMatch(phone)) {
      setState(() => errorMessage = 'Geçerli bir telefon numarası girin.');
      return;
    }

    setState(() {
      busy = true;
      errorMessage = null;
      _canResend = false;
    });

    try {
      final exists = await _checkPhoneExists(phone);
      if (exists) {
        setState(() {
          busy = false;
          errorMessage = 'Bu telefon numarası başka bir kullanıcı tarafından kullanılıyor.';
        });
        return;
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential cred) async {
          if (!mounted) return;
          await _link(cred, phone);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            busy = false;
            errorMessage = AppErrorHandler.getMessage(e);
          });
        },
        codeSent: (String id, int? _) {
          if (!mounted) return;
          setState(() {
            verifyId = id;
            smsSent = true;
            busy = false;
            errorMessage = null;
          });
          _startCountdown();
        },
        codeAutoRetrievalTimeout: (_) {
          if (!mounted) return;
          setState(() => busy = false);
        },
      );
    } catch (e) {
      setState(() {
        busy = false;
        errorMessage = 'SMS gönderilemedi. Lütfen tekrar deneyin.';
      });
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = 30;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft == 0) {
        timer.cancel();
        if (mounted) setState(() => _canResend = true);
      } else {
        if (mounted) setState(() => _secondsLeft--);
      }
    });
  }

  Future<bool> _checkPhoneExists(String phone) async {
    final callable =
    FirebaseFunctions.instance.httpsCallable('checkPhoneExists');
    try {
      final result = await callable.call({'phone': phone});
      final data = result.data;
      return data['alreadyExists'] == true;
    } catch (e) {
      AppErrorHandler.getMessage(e);
      rethrow;
    }
  }

  Future<void> _verifyCode() async {
    if (smsCtrl.text.length != 6) {
      _showError('6 haneli kod girin');
      return;
    }
    setState(() => busy = true);
    final cred = PhoneAuthProvider.credential(
      verificationId: verifyId!,
      smsCode: smsCtrl.text,
    );
    final phone = '+90${phoneCtrl.text}';
    await _link(cred, phone);
  }

  Future<void> _link(AuthCredential cred, String phone) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Kullanıcı bulunamadı.';
      await user.linkWithCredential(cred);
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      await ref.set({'phone': phone}, SetOptions(merge: true));
      widget.onVerified();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Doğrulama başarısız.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      elevation: 6,
      backgroundColor: Colors.white,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                        theme.colorScheme.primary.withOpacity(.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Ionicons.shield_checkmark,
                          color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Text('Telefon Doğrula',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 28),

                // 1️⃣ NUMARA GİRME BÖLÜMÜ
                if (!smsSent) ...[
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    style: const TextStyle(letterSpacing: 1.1),
                    decoration: _dec('5XXXXXXXXX', prefix: '+90 '),
                    validator: (v) => (v == null || v.length != 10)
                        ? '10 hane girin'
                        : null,
                  ),
                  const SizedBox(height: 6),
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(errorMessage!,
                          style: TextStyle(
                              color: Colors.red.shade700),
                          softWrap: true,
                          overflow: TextOverflow.fade,
                          maxLines: 2),
                    ),
                  if (errorMessage == null)
                    Row(
                      children: [
                        Icon(Ionicons.information_circle_outline,
                            color: Colors.grey.shade800),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            'Rezervasyon yapabilmek için numaranı doğrula !',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(
                                color: Colors.grey.shade800),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 28),
                ],

                // 2️⃣ SMS KOD ALANI
                if (smsSent) ...[
                  PinCodeTextField(
                    appContext: context,
                    controller: smsCtrl,
                    length: 6,
                    animationType: AnimationType.fade,
                    pinTheme: PinTheme(
                      shape: PinCodeFieldShape.box,
                      borderRadius: BorderRadius.circular(12),
                      fieldHeight: 50,
                      fieldWidth: 44,
                      inactiveColor: Colors.grey.shade400,
                      selectedColor: theme.colorScheme.primary,
                      activeColor: theme.colorScheme.primary
                          .withOpacity(.6),
                    ),
                    cursorColor: theme.colorScheme.primary,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {},
                  ),

                  const SizedBox(height: 12),

                  // ⏱️ 30s Sayaç / Tekrar Gönder
                  if (!_canResend)
                    Text(
                      'SMS gönderildi! 00:${_secondsLeft.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey.shade700),
                    )
                  else
                    TextButton(
                      onPressed: busy ? null : () {
                        _sendSms();
                        _startCountdown(); // sayaç tekrar baş  lasın
                      },                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('SMS gelmedi mi?'),
                          SizedBox(width: 5,),
                          const Text('Tekrar gönder',style: TextStyle(decoration: TextDecoration.underline,
                            decorationThickness: 2,
                          ),),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),

                  if (errorMessage != null)
                    Padding(
                      padding:
                      const EdgeInsets.only(bottom: 16.0, top: 0),
                      child: Text(errorMessage!,
                          style: TextStyle(
                              color: Colors.red.shade700),
                          softWrap: true,
                          overflow: TextOverflow.fade,
                          maxLines: 2),
                    ),
                ],

                // 3️⃣ ALT BUTONLAR
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed:
                        busy ? null : () => Navigator.pop(context),
                        child: const Text('İptal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                        busy ? null : (smsSent ? _verifyCode : _sendSms),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          theme.colorScheme.primary,
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(12)),
                        ),
                        child: busy
                            ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                            : Text(smsSent ? 'Doğrula' : 'Kod Gönder',
                            style:
                            const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void openPhoneVerify(BuildContext ctx, VoidCallback onSuccess) {
  showDialog(
    context: ctx,
    barrierDismissible: false,
    builder: (_) => PhoneVerifyDialog(onVerified: onSuccess),
  );
}
