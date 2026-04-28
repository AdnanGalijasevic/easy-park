import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easypark_mobile/models/bookmark.dart';
import 'package:easypark_mobile/providers/bookmark_provider.dart';
import 'package:easypark_mobile/providers/shell_navigation_provider.dart';
import 'package:easypark_mobile/theme/easy_park_colors.dart';
import 'package:easypark_mobile/utils/app_feedback.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BookmarkProvider>(context, listen: false).loadBookmarks();
    });
  }

  Future<void> _removeBookmark(Bookmark bookmark) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Bookmark'),
        content: Text(
          'Remove "${bookmark.parkingLocationName}" from your bookmarks?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: EasyParkColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await Provider.of<BookmarkProvider>(
          context,
          listen: false,
        ).removeBookmark(bookmark.id);
        AppFeedback.success(
          '"${bookmark.parkingLocationName}" removed from bookmarks.',
        );
      } catch (e) {
        if (mounted) {
          AppFeedback.error(e.toString().replaceFirst('Exception: ', ''));
        }
      }
    }
  }

  void _navigateToLocation(BuildContext context, Bookmark bookmark) {
    context.read<ShellNavigationProvider>().goToHomeAndFocusParking(
          bookmark.parkingLocationId,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookmarkProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.bookmarks.isEmpty) {
          return RefreshIndicator(
            onRefresh: provider.loadBookmarks,
            child: ListView(
              children: [
                SizedBox(
                  height: 350,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 72,
                        color: EasyParkColors.onBackgroundMuted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No bookmarks yet',
                        style: TextStyle(color: EasyParkColors.textSecondary, fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the bookmark icon on a parking location to save it here',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: EasyParkColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.loadBookmarks,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: provider.bookmarks.length,
            itemBuilder: (context, index) {
              final bookmark = provider.bookmarks[index];
              return _BookmarkCard(
                bookmark: bookmark,
                onRemove: () => _removeBookmark(bookmark),
                onTap: () => _navigateToLocation(context, bookmark),
              );
            },
          ),
        );
      },
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _BookmarkCard({
    required this.bookmark,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: const BoxDecoration(
            color: EasyParkColors.infoLight,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          child: const Icon(Icons.local_parking, color: EasyParkColors.info, size: 26),
        ),
        title: Text(
          bookmark.parkingLocationName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Saved ${_relativeDate(bookmark.createdAt)}',
            style: const TextStyle(color: EasyParkColors.textSecondary, fontSize: 12),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.map_outlined, color: EasyParkColors.info),
              tooltip: 'Show on map',
              onPressed: onTap,
            ),
            IconButton(
              icon: const Icon(Icons.bookmark_remove, color: EasyParkColors.error),
              tooltip: 'Remove bookmark',
              onPressed: onRemove,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _relativeDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}.${dt.month}.${dt.year}';
  }
}
