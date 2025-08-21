import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_snackbar/app_snackbar.dart';
import 'package:toplansin/ui/user_views/shared/widgets/loading_spinner/loading_spinner.dart';
import 'package:toplansin/ui/views/auth_check_screen.dart';
import 'package:toplansin/ui/views/login_page.dart';
import 'package:url_launcher/url_launcher.dart';

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

  bool _agreeTerms = false; // Kullanım Şartları
  bool _agreePrivacy = false; // Gizlilik/ KVKK

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

    // Form geçerliyse kaydet
    if (_formKey.currentState!.validate()) {
      // Checkbox güvenliği (buton pasifleştirilmiş olsa da ekstra koruma)
      if (!_agreeTerms || !_agreePrivacy) {
        AppSnackBar.error(
            context, "Devam etmek için gerekli onayları veriniz.");
        return;
      }

      _formKey.currentState!.save();

      // Şifre eşleşme kontrolü
      if (password != confirmPassword) {
        AppSnackBar.error(context, "Şifreler eşleşmiyor!");
        return;
      }

      // Tüm kontroller geçti -> loader aç
      showLoader(context);

      try {
        UserCredential userCredential =
        await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await userCredential.user?.sendEmailVerification();

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
        AppSnackBar.error(context, "Kayıt başarısız: $msg");
      } finally {
        hideLoader();
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
            colors: [AppColors.primaryDark, AppColors.primary],
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
                  child: Icon(Icons.sports_soccer,
                      color: AppColors.primary, size: 50),
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
                          SizedBox(
                            height: 12,
                          ),
                          // Ad Soyad
                          _buildTextField(
                            label: 'Ad Soyad',
                            icon: Icons.person,
                            onSaved: (value) => name = value ?? '',
                            validator: (value) {
                              if (value == null || value
                                  .trim()
                                  .isEmpty) {
                                return "Ad soyad boş olamaz";
                              }
                              if (value
                                  .trim()
                                  .length < 2) {
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
                              prefixIcon:
                              Icon(Icons.lock, color: AppColors.primary),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  showPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () =>
                                    setState(
                                            () => showPassword = !showPassword),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide:
                                BorderSide(color: AppColors.primary),
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
                              prefixIcon: Icon(Icons.lock_outline,
                                  color: AppColors.primary),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  showConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () =>
                                    setState(() =>
                                    showConfirmPassword = !showConfirmPassword),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide:
                                BorderSide(color: AppColors.primary),
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
                          SizedBox(height: 8),


// 1) Kullanım Şartları
                          _policyCheckbox(
                            value: _agreeTerms,
                            onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                            title: RichText(
                              text: TextSpan(
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                                children: [
                                  TextSpan(
                                    text: 'Kullanım Şartları’nı',
                                    style: const TextStyle(
                                      decoration: TextDecoration.underline,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        showPolicySheet(
                                          context: context,
                                          assetPath: 'assets/about_help_texts/tos.md',
                                          title: 'Kullanım Şartları',
                                          icon: Icons.description_outlined,
                                          onAccepted: () => setState(() => _agreeTerms = true),
                                        );
                                      },
                                  ),
                                  const TextSpan(text: ' okudum ve kabul ediyorum.'),
                                ],
                              ),
                            ),
                          ),

// 2) Gizlilik + KVKK
                          _policyCheckbox(
                            value: _agreePrivacy,
                            onChanged: (v) => setState(() => _agreePrivacy = v ?? false),
                            title: RichText(
                              text: TextSpan(
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                                children: [
                                  TextSpan(
                                    text: 'Gizlilik Politikası’nı',
                                    style: const TextStyle(
                                      decoration: TextDecoration.underline,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        showPolicySheet(
                                          context: context,
                                          assetPath: 'assets/about_help_texts/privacy.md',
                                          title: 'Gizlilik Politikası',
                                          icon: Icons.privacy_tip_outlined,
                                          onAccepted: () => setState(() => _agreePrivacy = true),
                                        );

                                      },
                                  ),
                                  const TextSpan(text: ' ve '),
                                  TextSpan(
                                    text: 'KVKK Aydınlatma Metni’ni',
                                    style: const TextStyle(
                                      decoration: TextDecoration.underline,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        showPolicySheet(
                                          context: context,
                                          assetPath: 'assets/about_help_texts/kvkk.md',
                                          title: 'KVKK Aydınlatma Metni',
                                          icon: Icons.shield,
                                          onAccepted: () => setState(() => _agreePrivacy = true),
                                        );
                                      },
                                  ),
                                  const TextSpan(
                                      text: ' okudum; kişisel verilerimin işlenmesine açık rıza veriyorum.'),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 10),

                          // Kayıt butonu
                          ElevatedButton(
                            onPressed: (_agreeTerms && _agreePrivacy)
                                ? _handleSubmit
                                : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 32),
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              disabledBackgroundColor:
                              AppColors.primary.withOpacity(0.4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.person_add, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Hesap Oluştur',
                                    style: TextStyle(color: Colors.white)),
                              ],
                            ),
                          ),
                          SizedBox(height: 6),

                          Divider(color: Colors.grey[300]),
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
                                Icon(Icons.arrow_back,
                                    color: AppColors.primary),
                                SizedBox(width: 8),
                                Text(
                                  'Giriş Sayfasına Dön',
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

  Widget _linkText({
    required String linkText,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        linkText,
        style: const TextStyle(
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w600,
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
        hintText: '5XXXXXXXXX',
        // örnek 10 hane
        prefixText: '+90 ',
        prefixIcon: const Icon(Icons.phone, color: Colors.green),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green),
        ),
      ),
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly, // yalnızca rakam
        LengthLimitingTextInputFormatter(10), // en çok 10 hane
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
          onSaved(null); // ➜ kaydedilmez
        } else {
          onSaved('+90$value'); // ➜ +90XXXXXXXXXX
        }
      },
    );
  }





  Widget _policyCheckbox({
    required bool value,
    required Function(bool?) onChanged,
    required Widget title,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        checkboxTheme: CheckboxThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          side: const BorderSide(color: Colors.grey, width: 1),
          visualDensity: VisualDensity.compact, // kutuyu küçültür
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      child: CheckboxListTile(
        dense: true, // dikey padding azaltır
        contentPadding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        controlAffinity: ListTileControlAffinity.leading,
        value: value,
        onChanged: onChanged,
        title: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 13, height: 1.4), // yazı boyutu
          child: title,
        ),
      ),
    );
  }

  Future<void> showPolicySheet({
    required BuildContext context,
    required String assetPath,
    required String title,
    required VoidCallback onAccepted, // ← kabul geldiğinde ne olacak?
    IconData? icon,
    String acceptLabel = 'Okudum, kabul ediyorum',
  }) async {
    final md = await rootBundle.loadString(assetPath);

    final mdConfig = MarkdownConfig(configs: [
      PConfig(textStyle: const TextStyle(fontSize: 13, height: 1.5)),
      H1Config(style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      H2Config(style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      H3Config(style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      CodeConfig(style: const TextStyle(fontSize: 12)),
      LinkConfig(
        style: const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
        onTap: (url) {
          if (url == null) return;
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        },
      ),
    ]);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.7;

        bool localAgree = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(
                        children: [
                          Icon(icon ?? Icons.policy_outlined, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Kapat',
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // İçerik
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: MarkdownWidget(
                          data: md,
                          config: mdConfig,
                        ),
                      ),
                    ),

                    // Onay kutusu + butonlar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: localAgree,
                            onChanged: (v) => setSheetState(() {
                              localAgree = v ?? false;
                            }),
                            title: const Text(
                              'Okudum ve kabul ediyorum.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Kapat'),
                              ),
                              const Spacer(),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: localAgree ? Colors.green : Colors.grey.shade400,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                onPressed: localAgree
                                    ? () {
                                  Navigator.pop(ctx);
                                  onAccepted();
                                }
                                    : null,
                                child: Text(acceptLabel),
                              )

                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
