import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/providers/acces_code_provider.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';

class OwnerAccessCodePage extends StatefulWidget {
  final String haliSahaId;

  const OwnerAccessCodePage({
    Key? key,
    required this.haliSahaId,
  }) : super(key: key);

  @override
  _OwnerAccessCodePageState createState() => _OwnerAccessCodePageState();
}

class _OwnerAccessCodePageState extends State<OwnerAccessCodePage> {
  late String _accessCode;
  bool _isLoading = false;
  final ownerUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _accessCode = '---- ----';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prov = context.read<AccessCodeProvider>();
      prov.loadActiveCode(context, widget.haliSahaId);
      prov.loadInactiveCodes(context, widget.haliSahaId);
    });
  }

  Future<void> _generateNewCode(BuildContext context) async {
    setState(() => _isLoading = true);
    final newCode = _randomCode();
    await context.read<AccessCodeProvider>().createCode(
          context: context,
          haliSahaId: widget.haliSahaId,
          ownerUid: ownerUid,
          newCode: newCode,
        );
    final prov = context.read<AccessCodeProvider>();
    setState(() {
      _accessCode = prov.activeCode?.code ?? newCode;
      _isLoading = false;
    });
    prov.loadInactiveCodes(context, widget.haliSahaId);
  }

  String _randomCode({int length = 8, bool withDash = false}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    final code =
        List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
    if (!withDash) return code;
    final buf = StringBuffer();
    for (var i = 0; i < code.length; i++) {
      buf.write(code[i]);
      if (i % 4 == 3 && i != code.length - 1) buf.write('-');
    }
    return buf.toString();
  }

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kod kopyalandı!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AccessCodeProvider>();
    final displayCode = prov.activeCode?.code ?? _accessCode;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        ),
        title: Text(
          'Saha Erişim Kodu',
          style: AppTextStyles.titleLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFFE65100),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning, width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dikkat! Kullanıcılar bu kod ile sahanıza rezervasyon yapabilir, kodu paylaşırken dikkatli olun. '
                      'Kod değişikliğinde eski kod devre dışı kalır; işlemlerde '
                      'lütfen emin olun.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Aktif kod kartı
            GestureDetector(
              onTap: () => _copyToClipboard(displayCode),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 28),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE65100), width: 2),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, 6)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(
                      displayCode,
                      style: AppTextStyles.titleMedium.copyWith(
                          fontSize: 32,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.copy, color: AppColors.secondaryDark, size: 24),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Yeni kod butonu
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _generateNewCode(context),
              icon: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Icon(Icons.autorenew, color: Colors.white, size: 24),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _isLoading ? 'Oluşturuluyor...' : 'Yeni Kod Oluştur',
                  style: AppTextStyles.titleSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                elevation: 6,
                shadowColor: Colors.deepOrange.withOpacity(0.4),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Paylaştığınız kod yalnızca size ait sahada geçerlidir ve güncellendiğinde eski kod devre dışı kalır.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey[700]),
            ),

            const SizedBox(height: 32),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Geçmiş Kodlar',
                style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),

            const SizedBox(height: 12),

            // Geçmiş Kodlar Listesi
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4))
                ],
              ),
              child: prov.inactiveCodes.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Henüz geçmiş kod yok.',
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemCount: prov.inactiveCodes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final code = prov.inactiveCodes[i];
                        return Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        code.code,
                                        style: AppTextStyles.titleSmall
                                            .copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Oluşturma: ${_formatDate(code.createdAt)}',
                                        style: AppTextStyles.bodySmall,
                                      ),
                                      if (code.deactivatedAt != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Pasif: ${_formatDate(code.deactivatedAt!)}',
                                          style: AppTextStyles.bodySmall,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  color: AppColors.secondaryDark,
                                  onPressed: () => _copyToClipboard(code.code),
                                ),
                                ElevatedButton(
                                  onPressed: () => context
                                      .read<AccessCodeProvider>()
                                      .activateCodeAgain(
                                        context: context,
                                        haliSahaId: widget.haliSahaId,
                                        codeId: code.id,
                                      ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                  child: Text(
                                    'Aktifleştir',
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
