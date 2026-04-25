import 'package:easypark_mobile/models/notification.dart';
import 'package:easypark_mobile/services/base_service.dart';

class NotificationService extends BaseService<Notification> {
  NotificationService() : super('Notification');

  @override
  Future<Notification> fromJson(Map<String, dynamic> json) async {
    return Notification.fromJson(json);
  }

  Future<void> markAsRead(int id) async {
    final response = await postAction('$id/read', {});
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to mark notification as read');
    }
  }

  Future<void> markAllAsRead() async {
    final response = await postAction('read-all', {});
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to mark all notifications as read');
    }
  }
}
