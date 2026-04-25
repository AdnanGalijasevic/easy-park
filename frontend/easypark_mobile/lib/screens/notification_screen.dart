import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easypark_mobile/providers/notification_provider.dart';
import 'package:intl/intl.dart';
import 'package:easypark_mobile/theme/easy_park_colors.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notificationProvider = Provider.of<NotificationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        actions: [
          if (notificationProvider.unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: "Mark all as read",
              onPressed: () => notificationProvider.markAllAsRead(),
            ),
        ],
      ),
      body: notificationProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : notificationProvider.items.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined,
                          size: 64, color: EasyParkColors.muted),
                      SizedBox(height: 16),
                      Text("No notifications yet"),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: notificationProvider.items.length,
                  itemBuilder: (context, index) {
                    final notification = notificationProvider.items[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: notification.type == 'Alert'
                            ? EasyParkColors.errorContainer
                            : EasyParkColors.infoLight,
                        child: Icon(
                          notification.type == 'Alert'
                              ? Icons.warning_amber_rounded
                              : Icons.info_outline,
                          color: notification.type == 'Alert'
                              ? EasyParkColors.error
                              : EasyParkColors.info,
                        ),
                      ),
                      title: Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight: notification.isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notification.message),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd.MM.yyyy HH:mm')
                                .format(notification.createdAt.toLocal()),
                            style: const TextStyle(fontSize: 12, color: EasyParkColors.muted),
                          ),
                        ],
                      ),
                      trailing: !notification.isRead
                          ? Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: EasyParkColors.info,
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                      onTap: () {
                        if (!notification.isRead) {
                          notificationProvider.markAsRead(notification.id);
                        }
                      },
                    );
                  },
                ),
    );
  }
}
