/*───────────────────────────────────────────────────────────────
   EDIT‑PROFILE DIALOG  –  modern glass popup + stylish form
───────────────────────────────────────────────────────────────*/
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_snackbar/app_snackbar.dart';

/*───────────────────────────── 1. LAUNCHER ─────────────────────────────*/
Future<Person?> openEditProfileDialog(BuildContext context, Person user) {
  // rootContext → SnackBar’ı ana scaffold’da göstermek için
  return showGeneralDialog<Person?>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Profili Güncelle',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, __, ___) =>
        _EditProfileDialog(currentUser: user, rootContext: context),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: .92, end: 1)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
  );
}

/*───────────────────────────── 2. DIALOG ─────────────────────────────*/
class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.currentUser,
    required this.rootContext,
  });

  final Person currentUser;
  final BuildContext rootContext;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtl;
  late final TextEditingController _phoneCtl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final String? rawPhone =
        widget.currentUser.phone?.replaceFirst(RegExp(r'^\+90'), '');
    _nameCtl = TextEditingController(text: widget.currentUser.name);
    _phoneCtl = TextEditingController(text: rawPhone);
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    /*────────────────────────────
    Responsive ölçüler:
    • Mobil   (<600 px)  → genişliğin %92’si
    • Tablet  (600‑960)  → sabit 560 px
    • Desktop (>960 px)  → ekranın %60’ı, üst sınır 680 px
  ────────────────────────────*/
    double maxW;
    if (size.width < 600) {
      maxW = size.width * 0.92;
    } else if (size.width < 960) {
      maxW = 560;
    } else {
      maxW = size.width * 0.60;
      maxW = maxW.clamp(560, 680); // 560‑680 arası tut
    }

    /* Yükseklik: ekranın en çok %90’ı (içerik fazla ise kaydırılabilir) */
    final maxH = size.height * 0.90;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Material(
              color: Colors.white,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
                    child: _dialogBody(context),
                  ),
                  if (_saving)
                    Positioned.fill(
                      child: Container(
                        color: Colors.white.withOpacity(0.6),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 26),
                      splashRadius: 22,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /*───────────────────────── BODY ─────────────────────────*/
  Widget _dialogBody(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Profili Düzenle',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 30),

            /*──────── Stylish Inputs ────────*/
            _glassField(
              maxLen: 30,
              controller: _nameCtl,
              hint: 'Ad Soyad',
              icon: Icons.person,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ad girin' : null,
            ),
            const SizedBox(height: 18),
            /*_glassField(
              maxLen: 10,
              controller: _phoneCtl,
              hint: 'Telefon (10 hane)',
              icon: Icons.phone,
              keyboard: TextInputType.phone,
              prefixText: '+90 ',
              formatter: FilteringTextInputFormatter.digitsOnly,
              validator: (v) =>
              v != null && v.replaceAll(RegExp(r'\D'), '').length == 10
                  ? null
                  : '10 haneli telefon',
            ),
            const SizedBox(height: 18),*/
            _saveButton(),
          ],
        ),
      ),
    );
  }

  /*──────────────────── 3. GLASS FIELD  ───────────────────*/
  Widget _glassField({
    TextEditingController? controller,
    String? initial,
    required String hint,
    required IconData icon,
    bool readOnly = false,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
    String? prefixText,
    TextInputFormatter? formatter,
    int? maxLen,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withOpacity(0.5), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: TextFormField(
        maxLength: maxLen,
        controller: controller,
        initialValue: controller == null ? initial : null,
        readOnly: readOnly,
        keyboardType: keyboard,
        inputFormatters: formatter != null ? [formatter] : null,
        validator: validator,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: InputBorder.none,
          prefixIcon: Container(
            margin: const EdgeInsets.only(left: 12, right: 10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              ),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          prefixText: prefixText,
          prefixStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black54),
        ),
      ),
    );
  }

  /*──────────────────── 4. SAVE BUTTON ───────────────────*/
  Widget _saveButton() => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            setState(() => _saving = true);

            try {
              final updated = await _saveProfile();
              if (!mounted) return;
              Navigator.pop(context, updated); // close dialog first

              AppSnackBar.success(context, 'Profil başarıyla güncellendi');
            } catch (e) {
              if (!mounted) return;
              setState(() => _saving = false);
              final msg = AppErrorHandler.getMessage(e);
              AppSnackBar.error(context, msg);
            }
          },
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            foregroundColor: Colors.white,
            backgroundColor: Colors.transparent,
          ),
          child: Ink(
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF43A047), Color(0xFF1B5E20)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text('Kaydet', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      );

  /*──────────────────── 5. FIRESTORE UPDATE ───────────────────*/
  Future<Person> _saveProfile() async {
    final digits = _phoneCtl.text.replaceAll(RegExp(r'\D'), '');
    final fullPhone = '+90$digits';

    final data = {
      'name': _nameCtl.text.trim(),
    };
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUser.id)
          .update(data);

      widget.currentUser..name = data['name']!;

      return widget.currentUser;
    } catch (e) {
      AppErrorHandler.getMessage(e);
      return Future.error(e);
    }
  }
}

/*────────  ÜST WIDGET’TA KULLANIM  ────────
onPressed: () async {
  final updated = await openEditProfileDialog(context, currentUser);
  if (updated != null && mounted) setState(() => currentUser = updated);
}
──────────────────────────────────────────*/
