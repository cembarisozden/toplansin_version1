import 'dart:ui';                               // ImageFilter
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:markdown_widget/markdown_widget.dart';

class AboutHelpPage extends StatelessWidget {
  const AboutHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
      elevation: 0,
      leading: IconButton(
        icon:
        const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Hakkında & Yardım',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          )),
      centerTitle: true,
        flexibleSpace: Container(
      decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.primary, AppColors.primaryDark],
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
      ),
    ),
    ),
    ),

      // ───── Arka plan gradyan
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary,AppColors.primaryDark],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
        ),
        child: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snap) {
            final version = snap.hasData
                ? 'Sürüm ${snap.data!.version} (${snap.data!.buildNumber})'
                : '';

            return ListView(
              padding:
              const EdgeInsets.fromLTRB(16, kToolbarHeight + 64, 16, 32),
              children: [
                // ─── Logo + sürüm
                Center(
                  child: Column(
                    children: [
                      _Glass(
                        radius: 60,
                        blur: 20,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child:  FittedBox(
                            fit: BoxFit.contain,
                            child: Image.asset('assets/logo2.png',
                                width: 92, height: 92),    // istediğin piksel boy
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(version,
                          style: theme.textTheme.labelMedium!
                              .copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // ─── Link kartları
                _LinkCard(
                  icon: Icons.help_outline,
                  text: 'SSS · Yardım Merkezi',
                  onTap: () =>
                      _openMarkdown(context, 'assets/about_help_texts/faq.md', 'SSS'),
                ),
                _LinkCard(
                  icon: Icons.privacy_tip_outlined,
                  text: 'Gizlilik Politikası',
                  onTap: () =>
                      _openMarkdown(context, 'assets/about_help_texts/privacy.md', 'Gizlilik Politikası'),
                ),
                _LinkCard(
                  icon: Icons.shield_outlined,
                  text: 'KVKK Aydınlatma Metni',
                  onTap: () =>
                      _openMarkdown(context, 'assets/about_help_texts/kvkk.md', 'KVKK Aydınlatma Metni'),
                ),
                _LinkCard(
                  icon: Icons.article_outlined,
                  text: 'Kullanım Şartları',
                  onTap: () =>
                      _openMarkdown(context, 'assets/about_help_texts/tos.md', 'Kullanım Şartları'),
                ),
                _LinkCard(
                  icon: Icons.code,
                  text: 'Açık Kaynak Lisansları',
                  onTap: () => showLicensePage(context: context),
                ),
                _LinkCard(
                  icon: Icons.email_outlined,
                  text: 'info@toplansin.com',
                  subtitle: 'Bize ulaşın',
                  onTap: () =>
                      launchUrl(Uri.parse('mailto:info@toplansin.com')),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /*──────── Şeffaf kart —────────*/
  Widget _LinkCard({
    required IconData icon,
    required String text,
    String? subtitle,
    required VoidCallback onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _Glass(
          blur: 16,
          radius: 20,
          child: ListTile(
            leading: Icon(icon, color: Colors.white, size: 28),
            title: Text(text,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            subtitle: subtitle != null
                ? Text(subtitle, style: const TextStyle(color: Colors.white70))
                : null,
            trailing:
            const Icon(Icons.chevron_right, color: Colors.white70, size: 26),
            onTap: onTap,
          ),
        ),
      );

  Widget _Glass({
    required double blur,
    required double radius,
    required Widget child,
  }) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: child,
          ),
        ),
      );

  void _openMarkdown(BuildContext ctx, String path, String title) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
          builder: (_) => MarkdownPage(assetPath: path, title: title)),
    );
  }
}

/*──────── Markdown viewer (markdown_widget) ────────*/
class MarkdownPage extends StatelessWidget {
  const MarkdownPage({required this.assetPath, required this.title, super.key});
  final String assetPath;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: FutureBuilder(
      future: DefaultAssetBundle.of(context).loadString(assetPath),
      builder: (_, snap) => snap.hasData
          ? MarkdownWidget(
        data: snap.data!,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        config: MarkdownConfig(
          configs: [
            PConfig(
              textStyle: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  !.copyWith(height: 1.5),
            ),
          ],
        ),
      )

          : const Center(child: CircularProgressIndicator()),
    ),
  );
}
