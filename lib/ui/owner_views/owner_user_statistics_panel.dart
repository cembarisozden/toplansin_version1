import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/providers/owner_providers/StatsProvider.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';

class OwnerUserStatisticPanel extends StatefulWidget {
  final String haliSahaId;

  const OwnerUserStatisticPanel({
    Key? key,
    required this.haliSahaId,
  }) : super(key: key);

  @override
  State<OwnerUserStatisticPanel> createState() => _OwnerUserStatisticPanelState();
}

class _OwnerUserStatisticPanelState extends State<OwnerUserStatisticPanel> {
  String _sortKey = 'cancel'; // 'approve' | 'cancel'

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<StatsProvider>().loadAllUserStatsForField(widget.haliSahaId);
    });
  }

  Future<void> _refresh() async {
    await context.read<StatsProvider>().loadAllUserStatsForField(widget.haliSahaId);
  }

  @override
  Widget build(BuildContext context) {
    final statsProv = context.watch<StatsProvider>();

    // Listeyi TEK yerde sırala
    final sorted = [...statsProv.allUserStats]..sort((a, b) {
      final ca = (a['ownCancelledCount'] ?? 0) as int;
      final cb = (b['ownCancelledCount'] ?? 0) as int;
      final aa = (a['ownApprovedCount'] ?? 0) as int;
      final ab = (b['ownApprovedCount'] ?? 0) as int;
      if (_sortKey == 'cancel') return cb.compareTo(ca); // iptal çok → üste
      return ab.compareTo(aa); // onaylı çok → üste
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSubHeaderBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: statsProv.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : sorted.isEmpty
                    ? _buildEmpty()
                    : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _UserStatCard(stat: sorted[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      color: Colors.redAccent.shade700,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'Kullanıcı İstatistikleri',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildSubHeaderBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: AppColors.surface,
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Son 6 ayda bu halı sahaya yapılan rezervasyonlar:',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // pill’ler taşarsa yatay kaydır
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _SortPills(
              active: _sortKey,
              onChange: (k) => setState(() => _sortKey = k),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              'Bu saha için son 6 ayda istatistik bulunamadı',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────────────── Card ───────────────────────── */

class _UserStatCard extends StatelessWidget {
  const _UserStatCard({required this.stat});
  final Map<String, dynamic> stat;

  @override
  Widget build(BuildContext context) {
    final name  = (stat['name'] ?? '').toString();
    final email = (stat['email'] ?? '').toString();
    final phone = (stat['phone'] ?? '').toString();
    final ok    = (stat['ownApprovedCount']  ?? 0) as int;
    final can   = (stat['ownCancelledCount'] ?? 0) as int;

    return LayoutBuilder(
      builder: (context, c) {
        final isNarrow = c.maxWidth < 360; // dar ekran eşiği

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: isNarrow
            // DAR: dikey yığ
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderLine(name: name, email: email, phone: phone),
                const SizedBox(height: 10),
                _StatsWrap(ok: ok, can: can),
              ],
            )
            // GENİŞ: yatay, sağda istatistikler
                : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _HeaderLine(name: name, email: email, phone: phone)),
                const SizedBox(width: 8),
                _StatsWrap(ok: ok, can: can),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderLine extends StatelessWidget {
  const _HeaderLine({required this.name, required this.email, required this.phone});
  final String name;
  final String email;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.danger.withOpacity(.08),
          child: Text(
            (name.isNotEmpty ? name[0] : '?').toUpperCase(),
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'Bilinmeyen Kullanıcı' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (email.isNotEmpty)
                    _InfoChip(icon: Icons.email_outlined, text: email, maxWidth: 180),
                  if (phone.isNotEmpty)
                    _InfoChip(icon: Icons.phone_outlined, text: phone, maxWidth: 140),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsWrap extends StatelessWidget {
  const _StatsWrap({required this.ok, required this.can});
  final int ok;
  final int can;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _BadgeStat(label: 'Onaylı', value: ok, color: AppColors.success),
        _BadgeStat(label: 'İptal', value: can, color: AppColors.danger),
      ],
    );
  }
}

/* ───────────────────────── Small parts ───────────────────────── */

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text, this.maxWidth});
  final IconData icon;
  final String text;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth ?? 200),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeStat extends StatelessWidget {
  const _BadgeStat({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(.25)),
          ),
          child: Text(
            '$value',
            style: AppTextStyles.titleLarge.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _SortPills extends StatelessWidget {
  const _SortPills({required this.active, required this.onChange});
  final String active;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    Widget pill(String key, String label) {
      final isActive = key == active;
      return GestureDetector(
        onTap: () => onChange(key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: isActive ? AppColors.danger.withOpacity(.12) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? AppColors.danger : AppColors.divider,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: isActive ? AppColors.danger : AppColors.textSecondary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pill('cancel', 'İptale göre'),
        pill('approve', 'Onaylıya göre'),
      ],
    );
  }
}
