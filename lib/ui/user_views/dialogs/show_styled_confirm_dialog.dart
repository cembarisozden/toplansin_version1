import 'package:flutter/material.dart';

class ShowStyledConfirmDialog extends StatelessWidget {
  const ShowStyledConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = "Onayla",
    this.cancelText = "Vazgeç",
    this.isDestructive = true, // varsayılan: kırmızı tema
    this.icon = Icons.warning_amber_rounded,
  });

  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool isDestructive;
  final IconData icon;

  // ✅ Kolay kullanım için statik gösterici
  static Future<bool?> show(
      BuildContext context, {
        required String title,
        required String message,
        String confirmText = "Onayla",
        String cancelText = "Vazgeç",
        bool isDestructive = true,
        IconData icon = Icons.warning_amber_rounded,
        bool barrierDismissible = false,
      }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => ShowStyledConfirmDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Palet
    const dangerDark = Color(0xFF7F1D1D);
    const danger     = Color(0xFFB91C1C);
    const dangerLite = Color(0xFFDC2626);

    final Color gradStart = isDestructive ? dangerDark : const Color(0xFF0F766E);
    final Color gradMid   = isDestructive ? danger     : const Color(0xFF0EA5A4);
    final Color gradEnd   = isDestructive ? dangerLite : const Color(0xFF14B8A6);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Üst şerit
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [gradStart, gradMid],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(.14),
                      border: Border.all(color: Colors.white.withOpacity(.35)),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Mesaj
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Text(
                message,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 4),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // Butonlar (eş boy)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: gradEnd, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          foregroundColor: dangerDark,
                          backgroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15,
                          ),
                        ),
                        child: Text(cancelText),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15,
                          ),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [gradMid, gradEnd],
                            ),
                          ),
                          child: Center(child: Text(confirmText)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
