import 'package:flutter/material.dart';
import 'package:easypark_mobile/models/bookmark.dart';
import 'package:easypark_mobile/services/bookmark_service.dart';

class BookmarkProvider with ChangeNotifier {
  final BookmarkService _service = BookmarkService();

  List<Bookmark> _bookmarks = [];
  bool _isLoading = false;

  List<Bookmark> get bookmarks => _bookmarks;
  bool get isLoading => _isLoading;

  bool isBookmarked(int parkingLocationId) {
    return _bookmarks.any((b) => b.parkingLocationId == parkingLocationId);
  }

  int? bookmarkIdFor(int parkingLocationId) {
    try {
      return _bookmarks
          .firstWhere((b) => b.parkingLocationId == parkingLocationId)
          .id;
    } catch (_) {
      return null;
    }
  }

  Future<void> loadBookmarks() async {
    _isLoading = true;
    notifyListeners();
    try {
      _bookmarks = await _service.getMyBookmarks();
    } catch (_) {
      _bookmarks = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addBookmark(int parkingLocationId) async {
    final bookmark = await _service.addBookmark(parkingLocationId);
    _bookmarks.add(bookmark);
    notifyListeners();
  }

  Future<void> removeBookmark(int bookmarkId) async {
    await _service.removeBookmark(bookmarkId);
    _bookmarks.removeWhere((b) => b.id == bookmarkId);
    notifyListeners();
  }

  Future<void> toggleBookmark(int parkingLocationId) async {
    if (isBookmarked(parkingLocationId)) {
      final id = bookmarkIdFor(parkingLocationId);
      if (id != null) await removeBookmark(id);
    } else {
      await addBookmark(parkingLocationId);
    }
  }
}
