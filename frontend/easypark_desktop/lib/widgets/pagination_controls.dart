import 'package:flutter/material.dart';
import 'package:easypark_desktop/app_colors.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';

class PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final Color backgroundColor;

  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.totalPages,
    this.onPrevious,
    this.onNext,
    this.backgroundColor = AppColors.primaryYellow,
  });

  @override
  Widget build(BuildContext context) {
    final canPrevious = currentPage > 0 && totalPages > 0;
    final canNext = currentPage < totalPages - 1 && totalPages > 0;
    final previousReason = totalPages <= 0
        ? 'No pages available.'
        : currentPage <= 0
        ? 'Already on first page.'
        : 'Go to previous page';
    final nextReason = totalPages <= 0
        ? 'No pages available.'
        : currentPage >= totalPages - 1
        ? 'Already on last page.'
        : 'Go to next page';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 38,
          height: 38,
          child: Tooltip(
            message: previousReason,
            child: ElevatedButton(
              onPressed: canPrevious ? onPrevious : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: EasyParkColors.onInverseSurface,
                disabledBackgroundColor: backgroundColor,
                disabledForegroundColor: EasyParkColors.disabled,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
                shadowColor: EasyParkColors.scrim,
              ),
              child: const Icon(Icons.chevron_left),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          totalPages > 0
              ? 'Page ${currentPage + 1} / $totalPages'
              : 'Page - / -',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 38,
          height: 38,
          child: Tooltip(
            message: nextReason,
            child: ElevatedButton(
              onPressed: canNext ? onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: EasyParkColors.onInverseSurface,
                disabledBackgroundColor: backgroundColor,
                disabledForegroundColor: EasyParkColors.disabled,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
                shadowColor: EasyParkColors.scrim,
              ),
              child: const Icon(Icons.chevron_right),
            ),
          ),
        ),
      ],
    );
  }
}

