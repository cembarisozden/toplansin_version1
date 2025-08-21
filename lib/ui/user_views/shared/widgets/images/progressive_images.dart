import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:shimmer/shimmer.dart';

///  Küresel yedek görsel yolu
const _kFallbackAsset = 'assets/images/no_image.webp';

class ProgressiveImage extends StatelessWidget {
  const ProgressiveImage({
    super.key,
    required this.imageUrl,           // artık nullable
    this.thumbnailUrl,
    this.blurHash,
    this.width,
    this.height,
    this.borderRadius = 0,
    this.fit = BoxFit.cover,
    this.onTap,
    this.debugLog = false,
  });

  /*──────────────── Parametreler ────────────────*/
  final String? imageUrl;             //  ❗ nullable
  final String? thumbnailUrl;
  final String? blurHash;
  final double? width, height;
  final double borderRadius;
  final BoxFit fit;
  final VoidCallback? onTap;
  final bool debugLog;

  /*──────────── Placeholder (şimmer) ────────────*/
  Widget _buildPlaceholder() {
    Widget w;
    if (blurHash?.isNotEmpty ?? false) {
      w = BlurHash(hash: blurHash!, imageFit: fit);
    } else if (thumbnailUrl != null) {
      w = CachedNetworkImage(imageUrl: thumbnailUrl!, fit: fit);
    } else {
      w = const ColoredBox(color: Color(0xFFCBD5E1));
    }
    return Shimmer.fromColors(
      baseColor: const Color(0xFFCBD5E1),
      highlightColor: const Color(0xFFE2E8F0),
      child: w,
    );
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = _buildPlaceholder();

    // 1️⃣ — URL geçerli mi?
    final bool isRemote =
        (imageUrl?.isNotEmpty ?? false) && imageUrl!.startsWith('http');

    // 2️⃣ — Ekran‑bazlı RAM limiti
    final memLimit = height != null
        ? (height! * MediaQuery.of(context).devicePixelRatio).round()
        : null;

    Widget img;

    if (isRemote) {
      /*────────  Uzak görsel  ────────*/
      img = CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 150),
        progressIndicatorBuilder: (_, url, progress) {
          final total = progress.totalSize;
          final value =
          (total != null && total > 0) ? progress.downloaded / total : null;
          if (debugLog) {
            debugPrint('⬇️ [$url] down=${progress.downloaded} '
                'total=${total ?? "NULL"}');
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              placeholder,
              const Center(
                child: SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2,color: Colors.white,),
                ),
              ),
            ],
          );
        },
        errorWidget: (_, url, err) {
          if (debugLog) debugPrint('❌ [$url] ERROR: $err');
          return const Icon(Icons.broken_image, color: Colors.red);
        },
        memCacheHeight: memLimit,
        cacheKey: Uri.parse(imageUrl!).replace(queryParameters: {}).toString(),
      );
    } else {
      /*────────  Yerel yedek  ────────*/
      img = Image.asset(_kFallbackAsset, fit: fit);
    }

    if (borderRadius > 0) {
      img = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: img,
      );
    }
    return GestureDetector(onTap: onTap, child: img);
  }
}
