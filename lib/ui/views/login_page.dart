import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/services/notification_service.dart';
import 'package:toplansin/ui/owner_views/owner_main_page.dart';
import 'package:toplansin/ui/user_views/main_page.dart';
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
  bool rememberMe = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool showEmailVerifyBanner = false;
  bool canResendEmail = false;
  int resendCountdown = 30;
  Timer? _timer;


  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    try {
      /* ───── 1) Firebase Auth ───── */
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (!cred.user!.emailVerified) {
        await cred.user!.sendEmailVerification(); // e-posta gönder
        setState(() {
          showEmailVerifyBanner = true;
        });
        startCountdown(); // geri sayımı başlat
        await _auth.signOut(); // kullanıcıyı çıkışa zorla
        return;
      }

      final uid = cred.user?.uid;
      if (uid == null) {
        _snack('Giriş başarısız: Kullanıcı bulunamadı.', Colors.red);
        return;
      }


      /* ───── 2) Firestore’dan role = owner/user zorunlu ───── */
      Person person = await _fetchPerson(uid);

      /* ───── 4) FCM token arka planda kaydedilsin ───── */
      if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
        await NotificationService.I.saveTokenToFirestore();
      }



      /* ───── 5) Yönlendirme ───── */
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
          person.role == 'owner'
              ? OwnerMainPage(currentOwner: person)
              : MainPage(currentUser: person),
        ),
      );
    }

    /* ───── 6) Hata yakalama ───── */
    on FirebaseAuthException catch (e) {
      final msg = getFriendlyErrorMessage(e);
      _snack('Giriş hatası: $msg', Colors.red);
    } on FirebaseException catch (e) {
      _snack('Firestore hatası: ${e.message}', Colors.red);
      await _auth.signOut();
    } catch (e) {
      _snack('Bilinmeyen hata: $e', Colors.red);
      await _auth.signOut();
    }
  }

/*───────── yardımcılar ─────────*/

  /// Firestore’dan sadece sunucu verisini getirir; rol eksikse
  /// 300 ms sonra bir kez daha dener. Eksik kalırsa 'unknown' kabul edilir.
  Future<Person> _fetchPerson(String uid) async {
    Future<DocumentSnapshot<Map<String, dynamic>>> getServer() =>
        _firestore
            .collection('users')
            .doc(uid)
            .get(const GetOptions(source: Source.server));

    var snap = await getServer();

    if (!snap.exists || snap.data()?['role'] == null) {
      // belge henüz yazılmamış olabilir → tek sefer daha dene
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

  void _snack(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: c),
    );
  }

  String getFriendlyErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Geçerli bir e-posta adresi girin.';
        case 'user-not-found':
          return 'Bu e-posta adresine kayıtlı kullanıcı bulunamadı.';
        case 'wrong-password':
          return 'Şifre hatalı. Lütfen tekrar deneyin.';
        case 'email-already-in-use':
          return 'Bu e-posta zaten kayıtlı.';
        case 'weak-password':
          return 'Şifre çok zayıf. En az 6 karakter olmalı.';
        case 'network-request-failed':
          return 'İnternet bağlantı hatası. Lütfen tekrar deneyin.';
        case 'too-many-requests':
          return 'Çok fazla deneme yapıldı. Bir süre bekleyin.';
        case 'requires-recent-login':
          return 'Bu işlemi yapmak için yeniden giriş yapmanız gerekiyor.';
        case 'invalid-credential':
          return 'Geçersiz ya da süresi dolmuş giriş bilgisi. Lütfen tekrar giriş yapın.';
        default:
          return 'Bir hata oluştu: ${error.message ?? "Bilinmeyen hata."}';
      }
    }

    // Firestore hataları veya diğer string içeren durumlar
    if (error.toString().contains("permission-denied")) {
      return "Bu işlem için yetkiniz yok.";
    }

    return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green[400]!,
              Colors.green[500]!,
              Colors.green[600]!
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
                  child: Icon(
                      Icons.sports_soccer, color: Colors.green, size: 50),
                ),
                SizedBox(height: 16),
                Text(
                  "Toplansın'a Hoş Geldiniz",
                  style: TextStyle(fontSize: 28,
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
                            onSaved: (value) => email = value!,
                            validator: (value) {
                              if (value == null || value.isEmpty ||
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
                            suffixIcon: IconButton(
                              icon: Icon(
                                showPassword ? Icons.visibility_off : Icons
                                    .visibility,
                              ),
                              onPressed: () =>
                                  setState(() {
                                    showPassword = !showPassword;
                                  }),
                            ),
                          ),
                          SizedBox(height: 16),
                          if (showEmailVerifyBanner)
                            Column(
                              children: [
                                SizedBox(height: 12),
                                Text(
                                  "E-postanızı doğrulamanız gerekiyor.",
                                  style: TextStyle(color: Colors.orange),
                                ),
                                if (!canResendEmail)
                                  Text("Tekrar göndermek için $resendCountdown saniye bekleyin.")
                                else
                                  TextButton(
                                    onPressed: resendVerificationEmail,
                                    child: Text("Tekrar Gönder"),
                                  ),
                                SizedBox(height: 12),
                              ],
                            ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: rememberMe,
                                    onChanged: (value) {
                                      setState(() {
                                        rememberMe = value!;
                                      });
                                    },
                                  ),
                                  Text('Beni hatırla'),
                                ],
                              ),
                              TextButton(
                                onPressed: () {
                                  _showChangePasswordDialog();
                                },
                                child: Text('Şifremi unuttum',
                                    style: TextStyle(color: Colors.green)),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
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
                              backgroundColor: Colors.green,
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
                              Navigator.pushReplacement(context,
                                  MaterialPageRoute(
                                      builder: (context) => SignUpPage()));
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_add, color: Colors.green),
                                SizedBox(width: 8),
                                Text(
                                  'Yeni Hesap Oluştur',
                                  style: TextStyle(color: Colors.green),
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
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green),
        ),
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
      onSaved: onSaved,
      validator: validator,
    );
  }

  void _showChangePasswordDialog() {
    TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
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
                    prefixIcon: Icon(Icons.email, color: Colors.green),
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
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () async {
                // 1) Veritabanında (Firestore) e-posta eşleşmesi kontrolü yapılır
                final email = emailController.text.trim().toLowerCase();
                final isEmailExists = await _checkEmailInDatabase(email);

                if (isEmailExists) {
                  // 2) E-posta bulunursa şifre sıfırlama e-postası gönder
                  try {
                    await _sendPasswordResetEmail(email);
                    // Kullanıcıya başarı mesajı göster
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            "$email adresine şifre sıfırlama linki gönderildi."),
                        backgroundColor: Colors.green.shade700,
                      ),
                    );
                  } catch (e) {
                    final msg = getFriendlyErrorMessage(e);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Şifre sıfırlama başarısız: $msg"),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  }
                } else {
                  // 3) E-posta bulunamazsa kullanıcıya uyarı ver
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Girilen e-posta kayıtlı değil!"),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                }

                Navigator.pop(ctx);
              },
              child: Text(
                "Onayla",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _checkEmailInDatabase(String email) async {
    try {
      // Firestore instance oluştur
      final firestore = FirebaseFirestore.instance;

      // users koleksiyonunda e-postayı sorgula
      final query = await firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      // Eğer sonuç dönerse e-posta veritabanında kayıtlı demektir
      if (query.docs.isNotEmpty) {
        return true; // E-posta var
      } else {
        return false; // E-posta yok
      }
    } catch (e) {
      // Hata durumunda false döndürüyoruz veya hatayı handle edebilirsiniz
      print("Veritabanı hatası: $e");
      return false;
    }
  }

  Future<void> _sendPasswordResetEmail(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } catch (e) {
      // Gönderim hatası
      final msg = getFriendlyErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("E-posta gönderilemedi: $msg"),
          backgroundColor: Colors.red,
        ),
      );
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
      await _auth.currentUser?.sendEmailVerification();
      startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Doğrulama e-postası tekrar gönderildi.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("E-posta gönderilemedi: $e")),
      );
    }
  }


}
