import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/services/firebase_functions_service.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_snackbar/app_snackbar.dart';

class PhoneVerifyDialog extends StatefulWidget {
  const PhoneVerifyDialog({super.key, required this.onVerified});
  final VoidCallback onVerified;

  @override
  State<PhoneVerifyDialog> createState() => _PhoneVerifyDialogState();
}

class _PhoneVerifyDialogState extends State<PhoneVerifyDialog> {
  final formKey = GlobalKey<FormState>();
  final phoneCtrl = TextEditingController();
  late TextEditingController smsCtrl;

  String? verifyId;
  bool smsSent = false;
  bool busy = false;
  String? errorMessage;

  // Sayaç
  Timer? _timer;
  int _secondsLeft = 30;
  bool _canResend = false;

  // Instant verification bilgisi
  bool _autoVerified = false;

  // Çift link/snackbar koruması
  bool _linkingOrDone = false;

  @override
  void initState() {
    super.initState();
    smsCtrl = TextEditingController();
  }

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
      borderRadius: BorderRadius.circular(14),
      gapPadding: 4,
    ),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  Future<void> _sendSms() async {
    FocusScope.of(context).unfocus();
    if (!formKey.currentState!.validate()) return;

    final raw = phoneCtrl.text.trim();
    final phone = '+90$raw';

    if (!RegExp(r'^\+905\d{9}$').hasMatch(phone)) {
      if (!mounted) return;
      setState(() => errorMessage = 'Geçerli bir telefon numarası girin.');
      return;
    }

    setState(() {
      busy = true;
      errorMessage = null;
      _canResend = false;
      _autoVerified = false;
      verifyId = null; // temiz başlangıç
      // yeni sms akışında eski kodu sıfırlayalım
      // PinCodeTextField ağaçtan çıkınca eski controller dispose ediliyor olabilir.
      // Güvenli: önce dispose et, sonra yeni bir tane oluştur.
      try { smsCtrl.dispose(); } catch (_) {}
      smsCtrl = TextEditingController();
      smsSent = false;
    });

    try {
      final exists = await _checkPhoneExists(phone);
      if (!mounted) return;
      if (exists) {
        setState(() {
          busy = false;
          errorMessage =
          'Bu telefon numarası başka bir kullanıcı tarafından kullanılıyor.';
        });
        return;
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),

        // Otomatik doğrulama (bazı cihazlarda tetiklenir)
        verificationCompleted: (PhoneAuthCredential cred) async {
          if (!mounted || _linkingOrDone) return;

          final autoCode = cred.smsCode; // bazı cihazlarda null olabilir
          if (autoCode != null && autoCode.length == 6) {
            // Controller'a güvenli atama
            smsCtrl.value = TextEditingValue(text: autoCode);
            if (!mounted) return;
            setState(() {
              _autoVerified = true;
              busy = false;
              smsSent = true;
            });
          } else {
            if (!mounted) return;
            setState(() {
              _autoVerified = true;
              busy = false;
              smsSent = false;
            });
          }

          // Tek seferlik link; snackbar ve kapanış _link içinde
          await _link(cred, phone, closeAfter: true, showSuccessSnack: true);
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
            smsSent = true; // PIN alanını göster
            busy = false;
            errorMessage = null;
          });
          _startCountdown();
        },

        codeAutoRetrievalTimeout: (_) {
          if (!mounted) return;
          setState(() {
            busy = false;
            _canResend = true; // süre dolunca tekrar gönder aktif olsun
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
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
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft == 0) {
        timer.cancel();
        setState(() => _canResend = true);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<bool> _checkPhoneExists(String phone) async {
    final callable =
    functions.httpsCallable('checkPhoneExists');
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
    if (verifyId == null) {
      _showError('Önce doğrulama kodu isteyin.');
      return;
    }
    final code = smsCtrl.text; // controller değerini kopyala
    if (code.length != 6) {
      _showError('6 haneli kod girin');
      return;
    }
    setState(() => busy = true);

    final cred = PhoneAuthProvider.credential(
      verificationId: verifyId!,
      smsCode: code,
    );
    final phone = '+90${phoneCtrl.text}';
    await _link(cred, phone, closeAfter: true, showSuccessSnack: true);
  }

  Future<void> _link(
      AuthCredential cred,
      String phone, {
        bool closeAfter = true,
        bool showSuccessSnack = true,
      }) async {
    if (_linkingOrDone) return; // çift işlem koruması
    _linkingOrDone = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Kullanıcı bulunamadı.';

      await user.linkWithCredential(cred);
      await user.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(updatedUser!.uid)
          .set({'phone': phone}, SetOptions(merge: true));

      widget.onVerified();

      if (mounted && showSuccessSnack) {
        AppSnackBar.success(
          context,
          "Telefon numarası doğrulandı.",
        );
      }

      if (mounted && closeAfter) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      _linkingOrDone = false; // hata varsa tekrar denemeye izin ver
      String msg;
      switch (e.code) {
        case 'credential-already-in-use':
          msg = 'Bu telefon başka bir hesapla ilişkili.';
          break;
        case 'provider-already-linked':
          msg = 'Telefon numarası zaten bu hesapla bağlantılı.';
          break;
        case 'requires-recent-login':
          msg = 'Güvenlik için yeniden giriş yapın.';
          break;
        default:
          msg = AppErrorHandler.getMessage(e);
      }
      _showError(msg);
    } catch (_) {
      _linkingOrDone = false;
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                        color: theme.colorScheme.primary.withOpacity(.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Ionicons.shield_checkmark,
                          color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Telefon Doğrula',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Otomatik doğrulama bilgisi
                if (_autoVerified)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Numaranız otomatik doğrulandı.',
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 1) Numara alanı (PIN görünmüyorsa)
                if (!smsSent) ...[
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    style: const TextStyle(letterSpacing: 1.1),
                    decoration: _dec('5XXXXXXXXX', prefix: '+90 '),
                    validator: (v) =>
                    (v == null || v.length != 10) ? '10 hane girin' : null,
                  ),
                  const SizedBox(height: 6),

                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                        softWrap: true,
                        overflow: TextOverflow.fade,
                        maxLines: 2,
                      ),
                    )
                  else
                    Row(
                      children: [
                        Icon(Ionicons.information_circle_outline,
                            color: Colors.grey.shade800),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            'Rezervasyon yapabilmek için numaranı doğrula !',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 28),
                ],

                // 2) PIN alanı (kod gönderildiyse veya otomatik doldurulduysa)
                if (smsSent) ...[
                  PinCodeTextField(
                    autoDisposeControllers: false,
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
                      activeColor:
                      theme.colorScheme.primary.withOpacity(.6),
                    ),
                    cursorColor: theme.colorScheme.primary,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {},
                    onCompleted: (_) {
                      if (!busy) _verifyCode(); // 6 hane dolunca otomatik
                    },
                  ),

                  const SizedBox(height: 12),

                  if (!_canResend)
                    Text(
                      'SMS gönderildi! 00:${_secondsLeft.toString().padLeft(2, '0')}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: busy ? null : _sendSms, // çift sayaç yok
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text('SMS gelmedi mi?'),
                          SizedBox(width: 5),
                          Text(
                            'Tekrar gönder',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                              decorationThickness: 2,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),

                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0, top: 0),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                        softWrap: true,
                        overflow: TextOverflow.fade,
                        maxLines: 2,
                      ),
                    ),
                ],

                // 3) Alt butonlar
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: busy ? null : () => Navigator.pop(context),
                        child: const Text('İptal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                        busy ? null : (smsSent ? _verifyCode : _sendSms),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: busy
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child:
                          CircularProgressIndicator(strokeWidth: 2),
                        )
                            : Text(
                          smsSent ? 'Doğrula' : 'Kod Gönder',
                          style:
                          const TextStyle(color: Colors.white),
                        ),
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
