import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/services/firebase_functions_service.dart';
import 'package:toplansin/services/user_notification_service.dart';
import 'package:toplansin/ui/owner_views/owner_main_page.dart';
import 'package:toplansin/ui/user_views/main_page.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_snackbar/app_snackbar.dart';
import 'package:toplansin/ui/user_views/shared/widgets/loading_spinner/loading_spinner.dart';
import 'package:toplansin/ui/views/sign_up_page.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool showPassword = false;
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool showEmailVerifyBanner = false;
  bool canResendEmail = false;
  int resendCountdown = 30;
  Timer? _timer;

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    showLoader(context);
    try {
      /* ───── 1) Firebase Auth ───── */
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user!.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser!;
      if (!refreshedUser.emailVerified) {
        await sendVerificationEmail(email); // e-posta gönder
        setState(() {
          showEmailVerifyBanner = true;
        });
        startCountdown(); // geri sayımı başlat
        await _auth.signOut(); // kullanıcıyı çıkışa zorla
        return;
      }

      final uid = cred.user?.uid;
      if (uid == null) {
        AppSnackBar.error(context, "Giriş başarısız kullanıcı bulunamadı.");
        return;
      }

      /* ───── 2) Firestore’dan role = owner/user zorunlu ───── */
      Person person = await _fetchPerson(uid);

      /* ───── 4) FCM token arka planda kaydedilsin ───── */
      if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
        await UserNotificationService.I.saveTokenToFirestore();
      }

      /* ───── 5) Yönlendirme ───── */
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => person.role == 'owner'
              ? OwnerMainPage(currentOwner: person)
              : MainPage(currentUser: person),
        ),
        (route) => false,
      );
    }

    /* ───── 6) Hata yakalama ───── */
    on FirebaseException catch (e) {
      final msg = AppErrorHandler.getMessage(e);
      AppSnackBar.error(context, msg);
      await _auth.signOut();
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e);
      AppSnackBar.error(context, msg);
      await _auth.signOut();
    } finally {
      hideLoader();
    }
  }

/*───────── yardımcılar ─────────*/

  /// Firestore’dan sadece sunucu verisini getirir; rol eksikse
  /// 300 ms sonra bir kez daha dener. Eksik kalırsa 'unknown' kabul edilir.
  Future<Person> _fetchPerson(String uid) async {
    Future<DocumentSnapshot<Map<String, dynamic>>> getServer() => _firestore
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server));

    var snap = await getServer();

    if (!snap.exists || snap.data()?['role'] == null) {
      await Future.delayed(const Duration(milliseconds: 300));
      snap = await getServer();
    }

    if (!snap.exists || snap.data()?['role'] == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Rol bilgisi bulunamadı.',
      );
    }

    return Person.fromMap(snap.data()!); // rol artık owner/user olmalı
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryDark,
              AppColors.primary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.sports_soccer,
                      color: AppColors.primary, size: 50),
                ),
                SizedBox(height: 16),
                Text(
                  "Toplansın'a Hoş Geldiniz",
                  style: TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Halı saha keyfinize devam edin!',
                  style: TextStyle(fontSize: 16, color: Colors.green[100]),
                ),
                SizedBox(height: 32),
                Card(
                  color: Colors.white,
                  margin: EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildTextField(
                            label: 'E-posta',
                            icon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (_) => _clearEmailWarningIfVisible(),
                            onSaved: (value) => email = value!,
                            validator: (value) {
                              if (value == null ||
                                  value.isEmpty ||
                                  !value.contains('@')) {
                                return 'Lütfen geçerli bir e-posta giriniz';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          _buildTextField(
                            label: 'Şifre',
                            icon: Icons.lock,
                            obscureText: !showPassword,
                            onSaved: (value) => password = value!,
                            onChanged: (_) => _clearEmailWarningIfVisible(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(() {
                                showPassword = !showPassword;
                              }),
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  _showChangePasswordDialog();
                                },
                                child: Text('Şifremi unuttum',
                                    style: TextStyle(color: AppColors.primary)),
                              ),
                            ],
                          ),
                          if (showEmailVerifyBanner)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.orange.shade300),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: Colors.orange, size: 28),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "E-posta doğrulaması gerekiyor!",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.orange.shade800,
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          "Doğrulama e-postası gönderildi. Eğer ulaşmadıysa tekrar göndermek için butona basabilirsiniz.",
                                          style: TextStyle(
                                            fontWeight: FontWeight.normal,
                                            fontSize: 13,
                                            color: Colors.grey[800],
                                            height: 1.4,
                                          ),
                                        ),
                                        SizedBox(height: 10),
                                        if (!canResendEmail)
                                          Text(
                                            "Tekrar göndermek için $resendCountdown saniye bekleyin.",
                                            style: TextStyle(
                                                fontSize: 12.5,
                                                color: Colors.grey[800]),
                                          )
                                        else
                                          ElevatedButton.icon(
                                            onPressed: resendVerificationEmail,
                                            icon: Icon(Icons.send_rounded,
                                                size: 18, color: Colors.white),
                                            label: Text(
                                              "E-postayı tekrar gönder",
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.orange.shade400,
                                              elevation: 0,
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 10),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _handleSubmit,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.login, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Giriş Yap',
                                    style: TextStyle(color: Colors.white)),
                              ],
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 32),
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          Divider(color: Colors.grey[300]),
                          SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => SignUpPage()));
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_add,
                                    color: AppColors.primary),
                                SizedBox(width: 8),
                                Text(
                                  'Yeni Hesap Oluştur',
                                  style: TextStyle(color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    Function(String?)? onSaved,
    String? Function(String?)? validator,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
      onSaved: onSaved,
      validator: validator,
      onChanged: onChanged ?? (_) {},
    );
  }

  void _clearEmailWarningIfVisible() {
    if (showEmailVerifyBanner) {
      setState(() {
        showEmailVerifyBanner = false;
        canResendEmail = false;
        _timer?.cancel();
      });
    }
  }

  void _showChangePasswordDialog() {
    TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Şifre Değiştir",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
              SizedBox(height: 8),
              Divider(
                thickness: 1,
                color: Colors.grey.shade300,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Şifre sıfırlama e-postasını almak için lütfen hesabınıza kayıtlı e-posta adresini girin.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.3,
                ),
              ),
              SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "E-posta Adresi",
                    prefixIcon: Icon(Icons.email, color: AppColors.primary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: EdgeInsets.only(bottom: 8, right: 8),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
              ),
              child: Text("İptal"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () async {
                final email = emailController.text.trim().toLowerCase();
                await resetPasswordSafe(context, email); // 🔑 yeni fonksiyon
                Navigator.pop(ctx); // işlem sonrası diyalogu kapat
              },
              child: const Text(
                "Onayla",
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> resetPasswordSafe(BuildContext context, String rawEmail) async {
    final email = rawEmail.trim().toLowerCase();

    try {
      await sendPasswordResetEmail(email);
    } catch (_) {
      // user-not-found dahil tüm hataları yutarız → enumeration koruması
    }

    AppSnackBar.show(context,
        "Şifre sıfırlama bağlantısı, sistemde kayıtlıysa $email adresine gönderildi.");
  }

  Future<void> sendPasswordResetEmail(String email) async {
    // Bölgeyi mutlaka seninkiyle aynı ver: "europe-west1"
    final callable = functions.httpsCallable('sendPasswordResetEmail');

    try {
      final res = await callable.call<Map<String, dynamic>>({'email': email});
      // res.data => {"ok": true} bekleniyor
      // burada kullanıcıya başarı mesajı gösterebilirsin.
      // AppSnackBar.show(context, "Şifre sıfırlama maili gönderildi.");
    } on FirebaseFunctionsException catch (e) {
      final msg = switch (e.code) {
        'invalid-argument' => 'E-posta adresi geçersiz.',
        'failed-precondition' =>
          'Sunucu yapılandırması eksik (RESEND_API_KEY vb.).',
        _ => e.message ?? 'Beklenmeyen bir hata oluştu.'
      };
      rethrow; // ya da kullanıcıya göster
    } catch (e) {
      AppSnackBar.error(context, "Bağlantı hatası. Lütfen tekrar deneyin.");
      rethrow;
    }
  }

  void startCountdown() {
    canResendEmail = false;
    resendCountdown = 30;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (resendCountdown == 0) {
        timer.cancel();
        setState(() {
          canResendEmail = true;
        });
      } else {
        setState(() {
          resendCountdown--;
        });
      }
    });
  }

  Future<void> resendVerificationEmail() async {
    try {
      await sendVerificationEmail(email);
      startCountdown();
      AppSnackBar.show(context, "Doğrulama e-postası tekrar gönderildi.");
    } catch (e) {
      final msg = AppErrorHandler.getMessage(e);
      AppSnackBar.error(context, msg);
    }
  }

  Future<void> sendVerificationEmail(String email) async {
    try {
      final callable = functions.httpsCallable('sendVerificationEmail');
      await callable.call({'email': email});
      // başarı
    } on FirebaseFunctionsException catch (e) {
      final msg = AppErrorHandler.getMessage(e);
      AppSnackBar.error(context, "Hata: $msg");
      rethrow;
    }
  }
}
