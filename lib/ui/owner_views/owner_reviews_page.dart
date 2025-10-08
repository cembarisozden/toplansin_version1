import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:toplansin/data/entitiy/reviews.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';

class OwnerReviewsPage extends StatefulWidget {
  final String haliSahaId; // Yorumların bağlı olduğu halı saha ID'si
  const OwnerReviewsPage({super.key, required this.haliSahaId});

  @override
  State<OwnerReviewsPage> createState() => _OwnerReviewsPageState();
}

class _OwnerReviewsPageState extends State<OwnerReviewsPage> {
  static const int _pageSize = 20;

  late final CollectionReference<Map<String, dynamic>> _reviewsCol;
  final List<Reviews> _items = [];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reviewsCol = FirebaseFirestore.instance
        .collection('hali_sahalar')
        .doc(widget.haliSahaId)
        .collection('reviews');

    _loadFirst();
  }

  Future<void> _loadFirst() async {
    setState(() {
      _initialLoading = true;
      _error = null;
      _hasMore = true;
      _cursor = null;
      _items.clear();
    });
    try {
      final page = await _fetchPage();
      setState(() {
        _items.addAll(page.items);
        _cursor = page.lastDoc;
        _hasMore = page.items.length == _pageSize;
      });
    } catch (e) {
      setState(() => _error = 'Yorumlar yüklenirken bir hata oluştu.');
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _fetchPage(startAfter: _cursor);
      setState(() {
        _items.addAll(page.items);
        _cursor = page.lastDoc;
        _hasMore = page.items.length == _pageSize;
      });
    } catch (e) {
      // sessizce yutabilir veya snackBar gösterebilirsin
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Tek sayfa getirir (orderBy datetime desc, limit)
  Future<_ReviewPage> _fetchPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> q = _reviewsCol
        .orderBy('datetime', descending: true)
        .limit(_pageSize);

    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final snap = await q.get(const GetOptions(
      // cache+server davranışı istersen ayarlayabilirsin
      source: Source.serverAndCache,
    ));

    final items = snap.docs.map(Reviews.fromDocument).toList(growable: false);
    final last = snap.docs.isEmpty ? null : snap.docs.last;
    return _ReviewPage(items, last);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          "Değerlendirmeler",
          style: AppTextStyles.titleLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFirst,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text(
          "Henüz bir yorum yapılmamış.",
          style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notif) {
        if (notif.metrics.pixels >= notif.metrics.maxScrollExtent - 200) {
          _loadMore(); // sona yaklaşınca otomatik daha fazla yükle
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // load more footeri
          if (index == _items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: _loadingMore
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : TextButton(
                  onPressed: _loadMore,
                  child: const Text("Daha fazla yükle"),
                ),
              ),
            );
          }

          final review = _items[index];
          return _ReviewCard(review: review);
        },
      ),
    );
  }
}

class _ReviewPage {
  _ReviewPage(this.items, this.lastDoc);
  final List<Reviews> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final Reviews review;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kullanıcı Bilgileri
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.blue.shade700,
                  child: Text(
                    (review.user_name.isNotEmpty
                        ? review.user_name[0]
                        : 'U')
                        .toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.user_name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMMM yyyy • HH:mm', 'tr_TR')
                          .format(review.datetime),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Rating ve Yorum
            Row(
              children: [
                Row(
                  children: List.generate(5, (i) {
                    final whole = review.rating.floor();
                    final hasHalf =
                        (review.rating - whole) >= 0.5 && i == whole;
                    if (i < whole) {
                      return const Icon(Icons.star, color: Colors.amber, size: 20);
                    } else if (hasHalf) {
                      return const Icon(Icons.star_half, color: Colors.amber, size: 20);
                    } else {
                      return const Icon(Icons.star_border, color: Colors.amber, size: 20);
                    }
                  }),
                ),
                const SizedBox(width: 8),
                Text(
                  review.rating.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Yorum Metni
            Text(
              review.comment,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
