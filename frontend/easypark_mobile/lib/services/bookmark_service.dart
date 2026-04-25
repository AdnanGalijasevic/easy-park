import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:easypark_mobile/models/bookmark.dart';
import 'package:easypark_mobile/services/base_service.dart';
import 'package:easypark_mobile/utils/constants.dart';

class BookmarkService extends BaseService<Bookmark> {
  BookmarkService() : super("Bookmark");

  @override
  Future<Bookmark> fromJson(Map<String, dynamic> json) async {
    return Bookmark.fromJson(json);
  }

  Future<List<Bookmark>> getMyBookmarks() async {
    final uri = Uri.parse('${AppConstants.baseUrl}/Bookmark');
    final headers = await getHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List<dynamic> list;
      if (data is Map && data.containsKey('resultList')) {
        list = data['resultList'] as List<dynamic>;
      } else if (data is Map && data.containsKey('result')) {
        list = data['result'] as List<dynamic>;
      } else if (data is List) {
        list = data;
      } else {
        return [];
      }
      return list
          .map((e) => Bookmark.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load bookmarks: ${response.statusCode}');
    }
  }

  Future<Bookmark> addBookmark(int parkingLocationId) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/Bookmark');
    final headers = await getHeaders();
    final body = jsonEncode({'parkingLocationId': parkingLocationId});
    final response = await http.post(uri, headers: headers, body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Bookmark.fromJson(jsonDecode(response.body));
    } else {
      final err = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final msg =
          err['userError'] ?? err['message'] ?? 'Failed to add bookmark';
      throw Exception(msg);
    }
  }

  Future<void> removeBookmark(int id) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/Bookmark/$id');
    final headers = await getHeaders();
    final response = await http.delete(uri, headers: headers);

    if (response.statusCode != 200 && response.statusCode != 204) {
      final err = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final msg =
          err['userError'] ?? err['message'] ?? 'Failed to remove bookmark';
      throw Exception(msg);
    }
  }
}
