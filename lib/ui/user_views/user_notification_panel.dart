import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toplansin/core/providers/UserNotificationProvider.dart';
import 'package:toplansin/data/entitiy/person.dart';
import 'package:toplansin/ui/user_views/subscription_detail_page.dart';
import 'package:toplansin/ui/user_views/user_reservation_detail_page.dart';
import 'package:toplansin/ui/user_views/user_reservations_page.dart';

class UserNotificationPanel extends StatelessWidget {
  final Person currentUser;

  const UserNotificationPanel({
    required this.currentUser,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<UserNotificationProvider>().notifications;
    final userReservations = context.watch<UserNotificationProvider>().userReservations;

    return Container(
      height: MediaQuery.of(context).size.height * 0.50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const Text(
            "Bildirimler",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          Expanded(
            child: notifications.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 50, color: Colors.grey),
                  const SizedBox(height: 10),
                  const Text("Bildirim yok", style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            )
                : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final item = notifications[index];
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.notifications, color: Colors.green),
                      title: Text(
                        item['title'] ?? "",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(item['subtitle'] ?? ""),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: () {
                        final type = item['type'];

                        if (type == 'reservation') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserReservationDetailPage(
                                reservation: userReservations[index],
                              ),
                            ),
                          ).then((_) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserReservationsPage(),
                              ),
                            );
                          });
                        } else if (type == 'subscription') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SubscriptionDetailPage(
                                currentUser: currentUser,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(
                      thickness: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Colors.grey,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
