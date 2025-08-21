import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/data/entitiy/subscription.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_colors.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';
import 'package:toplansin/ui/user_views/subscription_detail_page.dart';

enum DateFilter { all, today, last7Days, thisMonth }

class OwnerPastSubscriptionsPage extends StatefulWidget {
  final String haliSahaId;
  const OwnerPastSubscriptionsPage({super.key, required this.haliSahaId});

  @override
  State<OwnerPastSubscriptionsPage> createState() =>
      _OwnerPastSubscriptionsPageState();
}

class _OwnerPastSubscriptionsPageState extends State<OwnerPastSubscriptionsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _search = '';
  DateFilter _filter = DateFilter.all;

  Future<List<Subscription>> _fetchLogs(String status) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('subscription_logs')
          .where('haliSahaId', isEqualTo: widget.haliSahaId)
          .where('newStatus', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .get();

      return snap.docs
          .map((d) => Subscription.fromMap(d.data(), d.id))
          .toList();
    } catch (e) {
      print("Hata oluştu: $e");
      rethrow;
    }
  }

  DateTime? _parse(String raw) {
    try {
      final parts = raw.split(' ');
      return DateTime.parse('${parts[0]} ${parts[1].split('-').first}');
    } catch (_) {
      return null;
    }
  }

  List<Subscription> _applyFilters(List<Subscription> list) {
    final now = TimeService.now();
    DateTime? start;
    switch (_filter) {
      case DateFilter.today:
        start = DateTime(now.year, now.month, now.day);
        break;
      case DateFilter.last7Days:
        start = now.subtract(const Duration(days: 7));
        break;
      case DateFilter.thisMonth:
        start = DateTime(now.year, now.month, 1);
        break;
      case DateFilter.all:
        start = null;
        break;
    }
    return list.where((s) {
      final dt = _parse(s.endDate);
      final matchDate = start == null || (dt != null && dt.isAfter(start));
      final matchSearch =
      s.userName.toLowerCase().contains(_search.toLowerCase());
      return matchDate && matchSearch;
    }).toList();
  }

  Widget _buildList(List<Subscription> items) {
    if (items.isEmpty) {
      return Center(
        child: Text('Kayıt bulunamadı.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (_, i) => AbonelikCard(sub: items[i]),
    );
  }

  Widget _buildFutureTab(String status) {
    return FutureBuilder<List<Subscription>>(
      future: _fetchLogs(status),
      builder: (_, snap) {
        if (snap.hasError) {
          final msg = AppErrorHandler.getMessage(snap.error, context: 'subscription');
          return Center(
            child: Text(msg, style: const TextStyle(color: Colors.red)),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final list = _applyFilters(snap.data!);
        return _buildList(list);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFe0f7fa), Color(0xFFb2ebf2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 15),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.secondary),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text('Geçmiş Aboneler',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.titleLarge.copyWith(color: AppColors.secondary),
                ),
                ),
                const SizedBox(width: 48)
              ],
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintStyle: AppTextStyles.bodyMedium,
                    hintText: 'Kullanıcı ara...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<DateFilter>(
                value: _filter,
                items: [
                  DropdownMenuItem(value: DateFilter.all, child: Text('Tümü',style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w800),)),
                  DropdownMenuItem(value: DateFilter.today, child: Text('Bugün',style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w800),)),
                  DropdownMenuItem(value: DateFilter.last7Days, child: Text('Son 7 Gün',style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w800),)),
                  DropdownMenuItem(value: DateFilter.thisMonth, child: Text('Bu Ay',style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w800),)),
                ],
                onChanged: (v) => setState(() => _filter = v!),
              ),
            ]),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              labelColor: Colors.green.shade800,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: Colors.green.shade800,
              tabs: const [
                Tab(text: 'Sona Erdi'),
                Tab(text: 'İptal Edildi'),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFutureTab("Sona Erdi"),
                  _buildFutureTab("İptal Edildi"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
