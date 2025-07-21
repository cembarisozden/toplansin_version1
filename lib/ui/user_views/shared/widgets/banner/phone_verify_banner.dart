import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';

/// Küçük, dikkat çekici ve kapatılabilir telefon doğrulama uyarısı
class PhoneVerifyBanner extends StatefulWidget {
  const PhoneVerifyBanner({Key? key, required this.onAction}) : super(key: key);
  final VoidCallback onAction;

  @override
  State<PhoneVerifyBanner> createState() => _PhoneVerifyBannerState();
}

class _PhoneVerifyBannerState extends State<PhoneVerifyBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  )..forward();

  bool _closed = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_closed) return const SizedBox.shrink();

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -0.1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              // Sol vurgu şeridi
              Container(
                width: 4,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6F00), // turuncu vurgu
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // İkon
              const Icon(Ionicons.warning_outline,
                  color: Color(0xFFFF6F00), size: 24),
              const SizedBox(width: 10),
              // Metin
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Telefonunuzu doğrulayın',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Rezervasyon yapabilmek için telefonunu ekleyip onayla.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              // CTA
              TextButton(
                onPressed: widget.onAction,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7043),
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Doğrula',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              // Kapat butonu
              IconButton(
                padding: const EdgeInsets.all(4),
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _closed = true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
