import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/errors/app_error_handler.dart';
import 'package:toplansin/core/providers/UserNotificationProvider.dart';
import 'package:toplansin/data/entitiy/notification_model.dart';
import 'package:toplansin/services/time_service.dart';
import 'package:toplansin/ui/user_views/shared/theme/app_text_styles.dart';
import 'package:toplansin/ui/user_views/shared/widgets/app_snackbar/app_snackbar.dart';
import 'package:toplansin/ui/user_views/shared/widgets/loading_spinner/loading_spinner.dart';
import 'package:toplansin/ui/user_views/subscription_detail_page.dart';
import 'package:toplansin/ui/user_views/user_reservation_detail_page.dart';
import 'package:toplansin/data/entitiy/person.dart';

/*───────────────────────────────────────────
│  Renk Sabitleri  –  sonradan AppColors’a taşı
└───────────────────────────────────────────*/
const kAccent = Color(0xFF22D1AE);
const kUnreadDot = Color(0xFF3DCC7B);
const kUnreadBgLight = Color(0x1422D1AE);
const kUnreadBgDark = Color(0x2622D1AE);
const kBgLight = Colors.white;
const kTextPrimary = Color(0xFF141718);
const kTextSecondary = Color(0xFF6B6E74);

class UserNotificationPage extends StatelessWidget {

  const UserNotificationPage({required this.currentUser ,super.key});
  final Person currentUser ;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;
    final unreadBg = isDark ? kUnreadBgDark : kUnreadBgLight;

    return Scaffold(
      backgroundColor: kBgLight,
      appBar: AppBar(
        backgroundColor: kBgLight,
        elevation: 0,
        title: Text(
          'Bildirimler',
          style: AppTextStyles.titleLarge.copyWith(
            color: kTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        leadingWidth: 50,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: kTextPrimary),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async =>
            await context.read<UserNotificationProvider>().markAllAsRead(),
            icon: Icon(Ionicons.eye_outline, color: kTextPrimary, size: 16),
            label: Text(
              'Tümünü okundu yap',
              style: AppTextStyles.bodyMedium.copyWith(color: kTextPrimary),
            ),
          ),
        ],
      ),
      body: Consumer<UserNotificationProvider>(
        builder: (_, prov, __) {
          final items = prov.notifications;
          if (items.isEmpty) {
            return Center(
              child: Text('Yeni bildirim yok',
                  style:
                  AppTextStyles.bodyLarge.copyWith(color: kTextSecondary)),
            );
          }

          /*──────── 4 Başlıklı Gruplama ────────*/
          final today = TimeService.nowUtc();
          final todayStart = DateTime(today.year, today.month, today.day);
          final yesterdayStart = todayStart.subtract(const Duration(days: 1));
          final weekStart = todayStart.subtract(const Duration(days: 7));

          final List<_SectionItem> sectioned = [];
          bool addedToday = false;
          bool addedYesterday = false;
          bool addedWeek = false;
          bool addedOlder = false;

          for (final n in items) {
            if (n.createdAt.isAfter(todayStart) && !addedToday) {
              sectioned.add(_SectionItem.header('Bugün'));
              addedToday = true;
            } else if (n.createdAt.isAfter(yesterdayStart) &&
                n.createdAt.isBefore(todayStart) &&
                !addedYesterday) {
              sectioned.add(_SectionItem.header('Dün'));
              addedYesterday = true;
            } else if (n.createdAt.isAfter(weekStart) &&
                n.createdAt.isBefore(yesterdayStart) &&
                !addedWeek) {
              sectioned.add(_SectionItem.header('Bu hafta'));
              addedWeek = true;
            } else if (n.createdAt.isBefore(weekStart) && !addedOlder) {
              sectioned.add(_SectionItem.header('Daha önce'));
              addedOlder = true;
            }
            sectioned.add(_SectionItem.notification(n));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sectioned.length,
            itemBuilder: (_, i) {
              final s = sectioned[i];
              if (s.isHeader) {
                return Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Text(
                        s.header!,
                        style: AppTextStyles.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: kTextSecondary,
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Expanded(
                          child: Divider(
                              color: kTextSecondary.withOpacity(.25),
                              thickness: 0.8,
                              height: 0)),
                    ],
                  ),
                );
              }
              return _NotificationTile(
                notification: s.notification!,
                unreadBg: unreadBg,
                currentUser: currentUser,
              );
            },
          );
        },
      ),
    );
  }
}

/*───────────────────────────────────────────
│  Tek bildirim satırı
└───────────────────────────────────────────*/
class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final Color unreadBg;
  final Person currentUser ;


  const _NotificationTile({
    required this.notification,
    required this.unreadBg,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final timeText = _smartTime(notification.createdAt);

    return InkWell(
      onTap: () async {

        await context
            .read<UserNotificationProvider>()
            .markAsRead(notification.id);

        if (!context.mounted) return; // güvenlik
        showLoader(context);
        try {
          if (notification.type == 'reservation') {
            final res = await context
                .read<UserNotificationProvider>()
                .userReservation(reservationId: notification.eventId,
                userId: notification.userId);
            hideLoader();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserReservationDetailPage(reservation: res,),
              ),
            );
          } else if (notification.type == 'subscription') {
            hideLoader();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SubscriptionDetailPage(currentUser: currentUser),
              ),
            );
          }
        }catch(e){
          hideLoader();
          final msg=AppErrorHandler.getMessage(e,context: "Rezervasyon Bulunamadı");
          AppSnackBar.error(context,"Rezervasyon bulunamadı.");
        }
      },
      child: Container(
        color: notification.read ? Colors.transparent : unreadBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!notification.read)
              Container(
                margin: const EdgeInsets.only(right: 12, top: 6),
                width: 8,
                height: 30,
                decoration: const BoxDecoration(
                  color: kUnreadDot,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(width: 20),
            CircleAvatar(
              radius: 22,
              backgroundColor: kAccent.withOpacity(.15),
              child: Icon(Ionicons.notifications_outline,
                  color: kAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: notification.read
                            ? FontWeight.w400
                            : FontWeight.w600,
                        color: kTextPrimary,
                      )),
                  const SizedBox(height: 4),
                  Text(notification.body,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: kTextSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              timeText,
              style: AppTextStyles.bodySmall.copyWith(
                color: kTextSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/*───────────────────────────────────────────
│  Daha modern süre gösterimi
│  <1 dk  ->   “şimdi”
│  <1 sa  ->   “Xm”
│  <3 sa  ->   “Xh”
│  Aynı gün -> “HH:mm”
│  Dün        “Dün”
│  <7 gün ->  “EEE” (Sal)
│  Diğer   ->  “d MMM” (12 Tem)
└───────────────────────────────────────────*/
String _smartTime(DateTime dt) {
  final now = TimeService.nowUtc();
  final diff = now.difference(dt);

  if (diff.inSeconds < 60) return 'şimdi';
  if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
  if (diff.inHours < 24) return '${diff.inHours}sa';
  if (diff.inDays < 7) return '${diff.inDays}g';

  final fmt = diff.inDays < 30
      ? DateFormat('d MMM, HH:mm', 'tr')
      : DateFormat('d MMM yyyy', 'tr');
  return fmt.format(dt);
}

/*───────────────────────────────────────────
│  Liste öğe-tip sınıfı
└───────────────────────────────────────────*/
class _SectionItem {
  final bool isHeader;
  final String? header;
  final NotificationModel? notification;

  _SectionItem.header(this.header)
      : isHeader = true,
        notification = null;

  _SectionItem.notification(this.notification)
      : isHeader = false,
        header = null;
}
