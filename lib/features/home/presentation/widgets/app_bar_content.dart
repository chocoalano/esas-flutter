import 'package:esas/app/widgets/controllers/theme_controller.dart';
import 'package:esas/utils/api_constants.dart';
import 'package:esas/utils/helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppBarContent extends StatelessWidget {
  final ThemeController themeController;
  final String userName;
  final String date;
  final String? userAvatarUrl;

  const AppBarContent({
    super.key,
    required this.themeController,
    required this.userName,
    required this.date,
    required this.userAvatarUrl,
  });

  static const String defaultAvatarPath = 'esas-assets/default.png';

  @override
  Widget build(BuildContext context) {
    final isDark = themeController.isDarkMode;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    // Capitalize username
    final String formattedName =
        toBeginningOfSentenceCase(userName.toLowerCase()) ?? userName;

    // Bangun URL avatar
    final String avatarUrl =
        (userAvatarUrl != null && userAvatarUrl!.isNotEmpty)
        ? imageUrl("$baseImageUrl/${userAvatarUrl!}")
        : imageUrl("$baseImageUrl/$defaultAvatarPath");

    final String fallbackUrl = imageUrl("$baseImageUrl/$defaultAvatarPath");

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // User info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, $formattedName 👋',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
        ),

        // Theme toggle + avatar
        Row(
          children: [
            Tooltip(
              message: 'Switch Theme',
              child: IconButton(
                icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                onPressed: themeController.toggleTheme,
              ),
            ),
            const SizedBox(width: 8),

            // Avatar with fallback
            Tooltip(
              message: 'User Avatar',
              child: ClipOval(
                child: Image.network(
                  avatarUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint("Gagal memuat avatar: $error");
                    debugPrint("ini url avatar: $avatarUrl, $fallbackUrl");
                    return Image.network(
                      fallbackUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
