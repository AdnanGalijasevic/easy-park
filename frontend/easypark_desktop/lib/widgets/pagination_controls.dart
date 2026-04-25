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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 38,
          height: 38,
          child: ElevatedButton(
            onPressed: (currentPage > 0 && totalPages > 0) ? onPrevious : null,
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
          child: ElevatedButton(
            onPressed: (currentPage < totalPages - 1 && totalPages > 0)
                ? onNext
                : null,
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
      ],
    );
  }
}

