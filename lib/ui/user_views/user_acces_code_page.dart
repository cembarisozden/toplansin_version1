import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/providers/acces_code_provider.dart';
import 'package:toplansin/data/entitiy/hali_saha.dart';
import 'package:toplansin/ui/user_views/dialogs/show_styled_confirm_dialog.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';
import 'package:toplansin/ui/user_views/shared/widgets/images/progressive_images.dart';

class UserAccessCodePage extends StatefulWidget {
  const UserAccessCodePage({Key? key}) : super(key: key);

  @override
  _UserAccessCodePageState createState() => _UserAccessCodePageState();
}

class UserCodeEntry {
  final HaliSaha pitch;
  final String code;

  UserCodeEntry({required this.pitch, required this.code});
}

class _UserAccessCodePageState extends State<UserAccessCodePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  bool _isValidating = false;
  String? _errorText;
  HaliSaha? _foundPitch;
  List<UserCodeEntry> _userEntries = [];
  late AnimationController _btnAnim;
  Set<String> _visibleCodes = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _btnAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = await context.read<AccessCodeProvider>();
      final entries = await provider.loadUserCodes(context);
      setState(() {
        _userEntries = entries;
      });
      _isLoading=false;
    });
  }

  @override
  void dispose() {
    _btnAnim.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _validateCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorText = 'Lütfen bir kod girin');
      return;
    }
    setState(() {
      _isValidating = true;
      _errorText = null;
      _foundPitch = null;
    });
    _btnAnim.forward();

    final saha = await context
        .read<AccessCodeProvider>()
        .findPitchByCode(context, code);

    _btnAnim.reverse();
    setState(() {
      _isValidating = false;
      _foundPitch = saha;
      if (saha == null) _errorText = 'Geçersiz veya süresi dolmuş kod';
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _confirmAccess() async {
    if (_foundPitch == null) return;
    final code = _codeController.text.trim().toUpperCase();
    // provider’a kaydet
    await context
        .read<AccessCodeProvider>()
        .addUserAccessCode(context, code);
    final entries = await context.read<AccessCodeProvider>().loadUserCodes(
        context);
    setState(() {
      _userEntries = entries;
      _foundPitch = null;
      _codeController.clear();
    });
  }

  Future<void> _removeCode(String code) async {
    await context
        .read<AccessCodeProvider>()
        .removeUserAccessCode(context, code);
    setState(() {
      _userEntries.removeWhere((e) => e.code == code);
    });

  }

  @override
  Widget build(BuildContext context) {
    final btnScale = Tween(begin: 1.0, end: 0.95).animate(_btnAnim);

    return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(140),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accessOrange, AppColors.warning],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.vpn_key_rounded, size: 48, color: Colors.white),
                    const SizedBox(height: 8),
                    Text(
                      'Halı Saha Erişim Kodları',
                      style:
                      AppTextStyles.titleLarge.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Kod Girme Kartı ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Kod Ekle',
                        style: AppTextStyles.titleLarge
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _codeController,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(8),
                          UpperCaseTextFormatter(),
                        ],
                        decoration: InputDecoration(
                          hintText: 'ABCD1234',
                          labelText: 'Erişim Kodu',
                          errorText: _errorText,
                          prefixIcon: const Icon(
                            Icons.vpn_key,
                            color: AppColors.accessOrange,
                          ),
                          filled: true,
                          fillColor: AppColors.surfaceDark,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        onSubmitted: (_) => _validateCode(),
                      ),
                      const SizedBox(height: 16),
                      ScaleTransition(
                        scale: btnScale,
                        child: ElevatedButton(
                          onPressed: _isValidating ? null : _validateCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accessOrange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 6,
                            shadowColor:
                            AppColors.accessOrange.withOpacity(0.5),
                          ),
                          child: _isValidating
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : Text(
                            'Doğrula',
                            style: AppTextStyles.titleSmall
                                .copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- Bulunan Saha Kartı ---
                if (_foundPitch != null) ...[
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _confirmAccess,
                    child: Container(
                      height: 120,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ProgressiveImage(
                              imageUrl: _foundPitch!.imagesUrl.first,
                              fit: BoxFit.cover,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withOpacity(0.6),
                                    Colors.black.withOpacity(0.2),
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment
                                          .center,
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _foundPitch!.name,
                                          style: AppTextStyles.titleMedium
                                              .copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _foundPitch!.location,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(color: Colors.white70),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: _confirmAccess,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 12),
                                    ),
                                    child: Text(
                                      'Ekle',
                                      style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.bold),
                                    ),
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

                // --- Mevcut Kodlar Başlığı ---
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Mevcut Kodlar',
                    style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),

// Kart listesini bu şekilde oluşturuyoruz:
                _isLoading
                    ? const Center(
                  child: SizedBox(
                    width: 28, // daha küçük
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ):
                _userEntries.isEmpty
                    ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Erişim kodunuz bulunmamaktadır.",
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ):
                Column(
                  children: _userEntries.map((entry) {
                    final isVisible = _visibleCodes.contains(entry.code);
                    if(_visibleCodes.isEmpty){

                    }
                    return Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // 2) Saha adı ve kod
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.pitch.name,
                                    style: AppTextStyles.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      isVisible ? Icon(
                                        Ionicons.lock_open_outline,
                                        color: AppColors.accessOrange,
                                        size: 20,) : Icon(
                                        Ionicons.lock_closed_outline,
                                        color: AppColors.accessOrange,
                                        size: 20,),
                                      SizedBox(width: 4),
                                      Container(
                                        padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceDark,
                                          borderRadius: BorderRadius.circular(
                                              8),
                                        ),
                                        child: SelectableText(
                                          isVisible ? entry.code : '••••••••',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                            letterSpacing: 4,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // 3) Görüntüle/Gizle düğmesi
                            IconButton(
                              icon: Icon(
                                isVisible ? Icons.visibility_off : Icons
                                    .visibility,
                                color: AppColors.secondaryDark,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (isVisible)
                                    _visibleCodes.remove(entry.code);
                                  else
                                    _visibleCodes.add(entry.code);
                                });
                              },
                            ),

                            // 4) Silme düğmesi
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: AppColors.danger,
                              onPressed: () async{
                                  final confirm =
                                      await ShowStyledConfirmDialog.show(
                                    context,
                                    title: "Saha Erişim Kodunu Sil",
                                    message:
                                    "Kodu silerseniz bu halı sahaya rezervasyon veya abonelik yapabilmek için tekrardan kod girmeniz gerekecektir. Bu işlemi onaylıyor musunuz?",
                                    confirmText: "Evet,Sil",
                                  );
                                  if (confirm == true) {
                                    _removeCode(entry.code);
                                  }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.pop(context),
            backgroundColor: AppColors.accessOrange,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30)),
            child: const Icon(Icons.arrow_back_ios_new,color: Colors.white,)
        ),
    );
  }
}

/// Uppercase’a zorlayan input formatter
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue,
      TextEditingValue newValue,) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
