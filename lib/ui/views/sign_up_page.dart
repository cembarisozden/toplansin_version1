import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/ui/views/auth_check_screen.dart';
import 'package:toplansin/ui/views/login_page.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // Form durumunu takip etmek için
  final _formKey = GlobalKey<FormState>();

  // Ekrandaki text alanlarından gelen veriler
  String name = '';
  String email = '';
  String phone = '';
  String password = '';
  String confirmPassword = '';

  // TextEditingController'lar
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Şifre görünür/gizli kontrolü
  bool showPassword = false;
  bool showConfirmPassword = false;

  // Firebase erişimi
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Şifre gücü göstergesi için
  String _passwordStrengthLabel = '';
  Color _passwordStrengthColor = Colors.red;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Şifre gücü ölçüm fonksiyonu (0-4 arası puanlama)
  void _checkPasswordStrength(String pass) {
    int score = 0;
    if (pass.length >= 8) score++; // 1) En az 8 karakter
    if (RegExp(r'[0-9]').hasMatch(pass)) score++; // 2) En az 1 rakam
    if (RegExp(r'[A-Za-z]').hasMatch(pass)) score++; // 3) En az 1 harf
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pass))
      score++; // 4) En az 1 özel karakter

    switch (score) {
      case 0:
      case 1:
        _passwordStrengthLabel = "Zayıf";
        _passwordStrengthColor = Colors.red;
        break;
      case 2:
        _passwordStrengthLabel = "Orta";
        _passwordStrengthColor = Colors.orange;
        break;
      case 3:
        _passwordStrengthLabel = "İyi";
        _passwordStrengthColor = Colors.blue;
        break;
      case 4:
        _passwordStrengthLabel = "Çok Güçlü";
        _passwordStrengthColor = Colors.green;
        break;
    }
    setState(() {});
  }

  // Asıl şifre alanı için kurallar
  String? _passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return "Şifre boş olamaz";
    }
    if (value.length < 8) {
      return "Şifre en az 8 karakter olmalı";
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return "Şifre en az bir rakam içermeli";
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) {
      return "Şifre en az bir harf içermeli";
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    // Form geçerli mi?
    if (_formKey.currentState!.validate()) {
      // Tüm onSaved fonksiyonlarını tetikler
      _formKey.currentState!.save();

      // (Opsiyonel) Son bir kez password/confirmPassword eşit mi diye bakabilirsiniz
      if (password != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Şifreler eşleşmiyor!")),
        );
        return;
      }

      try {
        // Firebase Authentication ile kullanıcı oluştur
        UserCredential userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // E-posta doğrulama gönder
        await userCredential.user?.sendEmailVerification();

        // Firestore'a kullanıcı kaydı
        Person newUser = Person(
          id: userCredential.user!.uid,
          name: name,
          email: email,
          phone: phone,
          role: 'user',
        );

        await _firestore
            .collection('users')
            .doc(userCredential.user?.uid)
            .set(newUser.toMap());

        await _auth.signOut();

        _showVerificationDialog();
      } catch (e) {
        final msg = AppErrorHandler.getMessage(e, context: 'auth');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıt başarısız: $msg')),
        );
      }
    }
  }

  // E-posta doğrulama uyarısı
  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Doğrulama E-postası Gönderildi'),
          content:
              Text('Lütfen e-postanızı kontrol ederek hesabınızı doğrulayın.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Dialogu kapat
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
              child: Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Yeşil tonlarda gradyan arkaplan
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
                // Logo vb.
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  child:
                      Icon(Icons.sports_soccer, color: Colors.green, size: 50),
                ),
                SizedBox(height: 16),
                Text(
                  "Toplansın'a Katılın",
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Halı saha keyfiniz bir tık uzakta!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.green[100],
                  ),
                ),
                SizedBox(height: 32),

                // Kayıt formu
                Card(
                  color: Colors.white,
                  margin: EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          SizedBox(height: 12,),
                          // Ad Soyad
                          _buildTextField(
                            label: 'Ad Soyad',
                            icon: Icons.person,
                            onSaved: (value) => name = value ?? '',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Ad soyad boş olamaz";
                              }
                              if (value.trim().length < 2) {
                                return "Lütfen geçerli bir ad girin";
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          // E-posta
                          _buildTextField(
                            label: 'E-posta',
                            icon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                            onSaved: (value) => email = value ?? '',
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

                          // Şifre
                          TextFormField(
                            controller: _passwordController,
                            // Controller ekleyin
                            decoration: InputDecoration(
                              labelText: "Şifre",
                              prefixIcon: Icon(Icons.lock, color: Colors.green),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  showPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () => setState(
                                    () => showPassword = !showPassword),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.green),
                              ),
                            ),
                            obscureText: !showPassword,
                            onChanged: (value) {
                              _checkPasswordStrength(value);
                              setState(() {
                                password =
                                    value; // Anlık olarak şifreyi güncelleyin
                              });
                            },
                            onSaved: (value) => password = value ?? '',
                            validator: _passwordValidator,
                          ),
                          SizedBox(height: 8),

                          // Şifre gücü görseli
                          _buildPasswordStrengthBar(),
                          SizedBox(height: 16),

                          // Şifre Tekrar
                          TextFormField(
                            controller: _confirmPasswordController,
                            // Controller ekleyin
                            decoration: InputDecoration(
                              labelText: "Şifre Tekrar",
                              prefixIcon:
                                  Icon(Icons.lock_outline, color: Colors.green),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  showConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () => setState(() =>
                                    showConfirmPassword = !showConfirmPassword),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.green),
                              ),
                            ),
                            obscureText: !showConfirmPassword,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Şifre tekrar alanı boş olamaz";
                              }
                              if (value != _passwordController.text) {
                                // Controller ile karşılaştırın
                                return "Şifreler eşleşmiyor";
                              }
                              return null;
                            },
                            onSaved: (value) => confirmPassword = value ?? '',
                          ),
                          SizedBox(height: 24),

                          // Kayıt butonu
                          ElevatedButton(
                            onPressed: _handleSubmit,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_add, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Hesap Oluştur',
                                    style: TextStyle(color: Colors.white)),
                              ],
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 32,
                              ),
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),

                          Divider(color: Colors.grey[300]),
                          SizedBox(height: 16),

                          // Giriş sayfasına dön
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => AuthCheckScreen()),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back, color: Colors.green),
                                SizedBox(width: 8),
                                Text(
                                  'Giriş Sayfasına Dön',
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

  // Şifre gücü göstergesi
  Widget _buildPasswordStrengthBar() {
    double fillPercent = 0.0;
    switch (_passwordStrengthLabel) {
      case "Zayıf":
        fillPercent = 0.25;
        break;
      case "Orta":
        fillPercent = 0.50;
        break;
      case "İyi":
        fillPercent = 0.75;
        break;
      case "Çok Güçlü":
        fillPercent = 1.0;
        break;
      default:
        fillPercent = 0.0;
    }
    if (fillPercent == 0.0 && (_passwordStrengthLabel.isEmpty)) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // İlerleme barı
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fillPercent,
            minHeight: 6,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
          ),
        ),
        SizedBox(height: 4),
        // Metin
        if (_passwordStrengthLabel.isNotEmpty)
          Text(
            "Şifre gücü: $_passwordStrengthLabel",
            style: TextStyle(
              color: _passwordStrengthColor,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  // Ortak kullanımlık TextFormField builder'ı
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

  /// Sabit +90’lı telefon alanı
  Widget buildPhoneField({
    required void Function(String?) onSaved,
    String label = 'Telefon (isteğe bağlı)',
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        hintText: '5XXXXXXXXX',                    // örnek 10 hane
        prefixText: '+90 ',
        prefixIcon: const Icon(Icons.phone, color: Colors.green),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green),
        ),
      ),
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,      // yalnızca rakam
        LengthLimitingTextInputFormatter(10),        // en çok 10 hane
      ],
      // Opsiyonel alan: boş bırakılırsa hata yok
      validator: (value) {
        if (value == null || value.isEmpty) return null;
        if (value.length != 10) {
          return 'Lütfen 10 haneli telefon numarası giriniz';
        }
        return null;
      },
      onSaved: (value) {
        // Hiçbir şey girilmediyse DB’ye null gönder
        if (value == null || value.isEmpty) {
          onSaved(null);                             // ➜ kaydedilmez
        } else {
          onSaved('+90$value');                      // ➜ +90XXXXXXXXXX
        }
      },
    );
  }
}
