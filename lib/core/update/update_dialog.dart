import 'package:flutter/material.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';

/// Modern ve markaya uygun sade güncelleme dialogu.
/// Zorunlu (mandatory) durumda geri dönme, dışa tıklama ve kapatma engellenir.
Future<void> showUpdateDialog({
  required BuildContext context,
  required bool mandatory,
  required VoidCallback onUpdate,
  VoidCallback? onLater,
  String title = 'Güncelleme Gerekli',
  String message = '',
  String ctaUpdate = 'Güncelle',
  String ctaLater = 'Daha Sonra',
}) async {
  const Color primaryColor = AppColors.primary; // Toplansın yeşili
  const Color textColor = AppColors.textPrimary;
  const Color background = Colors.white;

  await showDialog(
    context: context,
    barrierDismissible: !mandatory,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (ctx) {
      return PopScope(
        canPop: !mandatory,
        onPopInvokedWithResult: (didPop, result) {},
        child: Dialog(
          backgroundColor: background,
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 📱 Üstte ikon
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: primaryColor,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),

                // Başlık
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 12),

                // Açıklama
                Text(
                  message.isNotEmpty
                      ? message
                      : (mandatory
                      ? 'Uygulamanın son sürümünü yüklemeden devam edemezsiniz.'
                      : 'Yeni bir sürüm mevcut. Şimdi güncellemek ister misiniz?'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black87,
                    height: 1.4,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 24),

                // Butonlar
                Row(
                  children: [
                    if (!mandatory)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            onLater?.call();
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: primaryColor.withOpacity(0.4)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            ctaLater,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (!mandatory) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          onUpdate(); // mağazayı aç
                          if (!mandatory) Navigator.of(ctx).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          ctaUpdate,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
