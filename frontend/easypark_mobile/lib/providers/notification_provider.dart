import 'package:flutter/foundation.dart';
import 'package:easypark_mobile/models/notification.dart';
import 'package:easypark_mobile/providers/base_provider.dart';
import 'package:easypark_mobile/services/notification_service.dart';

class NotificationProvider extends BaseProvider<Notification> {
  final NotificationService _notificationService = NotificationService();

  NotificationProvider() : super(NotificationService());

  int get unreadCount => items.where((n) => !n.isRead).length;

  Future<void> fetchMyNotifications(int userId) async {
    await loadData(search: {'UserId': userId});
  }

  Future<void> markAsRead(int id) async {
    try {
      await _notificationService.markAsRead(id);
      // Update local state instead of full reload
      final index = items.indexWhere((n) => n.id == id);
      if (index != -1) {
        final n = items[index];
        items[index] = Notification(
          id: n.id,
          userId: n.userId,
          title: n.title,
          message: n.message,
          type: n.type,
          isRead: true,
          createdAt: n.createdAt,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();
      for (var i = 0; i < items.length; i++) {
        final n = items[i];
        if (!n.isRead) {
          items[i] = Notification(
            id: n.id,
            userId: n.userId,
            title: n.title,
            message: n.message,
            type: n.type,
            isRead: true,
            createdAt: n.createdAt,
          );
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }
}
