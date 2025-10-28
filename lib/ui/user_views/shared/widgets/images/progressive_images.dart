import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

const _kFallbackAsset = 'assets/no_image.webp';

class ProgressiveImage extends StatelessWidget {
  const ProgressiveImage({
    super.key,
    required this.imageUrl,           // nullable
    this.thumbnailUrl,
    this.blurHash,
    this.width,
    this.height,
    this.borderRadius = 0,
    this.fit = BoxFit.cover,
    this.onTap,
    this.debugLog = false,
  });

  final String? imageUrl;
  final String? thumbnailUrl;
  final String? blurHash;
  final double? width, height;
  final double borderRadius;
  final BoxFit fit;
  final VoidCallback? onTap;
  final bool debugLog;

  // — boyuta göre decode limitleri (çift eksen)
  (int? w, int? h) _decodeTarget(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    final wPx = (width  != null) ? (width!  * dpr).round() : null;
    final hPx = (height != null) ? (height! * dpr).round() : null;
    return (wPx, hPx);
  }

  // — hafif placeholder: BlurHash varsa onu tek başına kullan,
  //   yoksa düz renk kutu (Shimmer yok → CPU rahat)
  Widget _placeholder() {
    if ((blurHash ?? '').isNotEmpty) {
      return BlurHash(hash: blurHash!, imageFit: fit);
    }
    return const ColoredBox(color: Color(0xFFE2E8F0));
  }

  // — küçük resim → büyük resim crossfade
  Widget _thumbThenFull({
    required BuildContext context,
    required String fullUrl,
    String? thumbUrl,
    required int? memW,
    required int? memH,
  }) {
    // Eğer küçük görsel varsa, önce onu çiz, tam görsel gelince hafifçe geç
    if (thumbUrl != null && thumbUrl.isNotEmpty) {
      return _CrossFadeNetworkImage(
        small: CachedNetworkImage(
          imageUrl: thumbUrl,
          fit: fit,
          memCacheWidth:  (memW != null) ? (memW / 2).round() : null,
          memCacheHeight: (memH != null) ? (memH / 2).round() : null,
          filterQuality: FilterQuality.low,
        ),
        big: CachedNetworkImage(
          imageUrl: fullUrl,
          fit: fit,
          fadeInDuration: const Duration(milliseconds: 120),
          memCacheWidth:  memW,
          memCacheHeight: memH,
          filterQuality: FilterQuality.low,
          cacheKey: Uri.parse(fullUrl).replace(queryParameters: {}).toString(),
          progressIndicatorBuilder: (_, __, progress) => Stack(
            fit: StackFit.expand,
            children: [
              _placeholder(),
               Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.red),
        ),
      );
    }

    // küçük yoksa doğrudan büyük + hafif placeholder + spinner overlay
    return CachedNetworkImage(
      imageUrl: fullUrl,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 120),
      memCacheWidth:  memW,
      memCacheHeight: memH,
      filterQuality: FilterQuality.low,
      cacheKey: Uri.parse(fullUrl).replace(queryParameters: {}).toString(),
      placeholder: (_, __) => Stack(
        fit: StackFit.expand,
        children: [
          _placeholder(),
           Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
      errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.red),
    );

  }

  @override
  Widget build(BuildContext context) {
    final (memW, memH) = _decodeTarget(context);
    final bool isRemote = (imageUrl?.isNotEmpty ?? false) && imageUrl!.startsWith('http');

    Widget child;
    if (isRemote) {
      child = _thumbThenFull(
        context: context,
        fullUrl: imageUrl!,
        thumbUrl: thumbnailUrl,
        memW: memW,
        memH: memH,
      );
    } else {
      child = Image.asset(
        _kFallbackAsset,
        fit: fit,
        filterQuality: FilterQuality.low,
      );
    }

    if (borderRadius > 0) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      );
    }

    return GestureDetector(onTap: onTap, child: child);
  }
}

/*───────────────────────────────────────────────────────────────────────────────
  Basit crossfade widget’ı (küçük → büyük). Animation maliyeti hafif.
───────────────────────────────────────────────────────────────────────────────*/
class _CrossFadeNetworkImage extends StatelessWidget {
  const _CrossFadeNetworkImage({
    required this.small,
    required this.big,
  });

  final Widget small;
  final Widget big;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        small,
        // Büyük resim gelir gelmez hafif görünür:
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 120),
          child: big,
        ),
      ],
    );
  }
}
