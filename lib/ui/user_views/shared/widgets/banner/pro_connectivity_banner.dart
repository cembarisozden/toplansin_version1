import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';

class ProConnectivityBanner extends StatefulWidget {
  final bool offline;

  const ProConnectivityBanner({super.key, required this.offline});

  @override
  State<ProConnectivityBanner> createState() => _ProConnectivityBannerState();
}

class _ProConnectivityBannerState extends State<ProConnectivityBanner>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  bool _show = false;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);

    if (widget.offline) {
      _show = true;
      _ctrl.forward();
    }
  }

  @override
  void didUpdateWidget(covariant ProConnectivityBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.offline != oldWidget.offline) {
      if (widget.offline) {
        setState(() {
          _show = true;
          _wasOffline = true;
        });
        _ctrl.forward();
      } else if (_wasOffline) {
        // İnternet geri geldiğinde yeşil banner’ı kısa süre göster
        setState(() {
          _show = true;
          _wasOffline = false;
        });
        _ctrl.forward();
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _ctrl.reverse().then((_) {
              if (mounted) setState(() => _show = false);
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isOffline = widget.offline;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 35,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _fade,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                color: isOffline
                    ? Colors.red.withOpacity(0.15)
                    : Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isOffline
                      ? Colors.redAccent.withOpacity(0.4)
                      : Colors.greenAccent.withOpacity(0.4),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                    color: isOffline ? Colors.red : AppColors.primaryLight,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOffline
                              ? 'Bağlantı koptu'
                              : 'Bağlantı yeniden sağlandı',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isOffline ? Colors.red: Colors.white,
                          ),
                        ),
                        if (isOffline)
                          Text(
                            'Lütfen internet bağlantınızı kontrol edin',
                            style: theme.textTheme.bodySmall?.merge(
                              const TextStyle(color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isOffline)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2,color: Colors.white,),
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
}
