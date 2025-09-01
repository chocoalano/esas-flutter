import 'package:esas/utils/api_constants.dart';
import 'package:esas/utils/helper.dart';
import 'package:flutter/material.dart';

// --- helpers (tetap) ---
T? _tryGet<T>(T? Function() getter) {
  try {
    return getter();
  } catch (_) {
    return null;
  }
}

void showAttendanceDetailSheet(BuildContext context, dynamic attendance) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  final String imageIn = (_tryGet<String?>(() => attendance.imageIn) ?? '')
      .toString();
  final String imageOut = (_tryGet<String?>(() => attendance.imageOut) ?? '')
      .toString();
  final dynamic locationIn = _tryGet<dynamic>(() => attendance.locationIn);
  final dynamic locationOut = _tryGet<dynamic>(() => attendance.locationOut);

  final String userName =
      (_tryGet<String?>(() => attendance.user?.name) ?? 'Karyawan').toString();
  final String userNip = (_tryGet<String?>(() => attendance.user?.nip) ?? 'N/A')
      .toString();

  final DateTime? createdAt = _tryGet<DateTime?>(() => attendance.createdAt);
  final String createdAtStr = createdAt != null
      ? formatFullDateIndo(createdAt.toIso8601String())
      : '-';

  final String timeIn = (_tryGet<String?>(() => attendance.timeIn) ?? 'N/A')
      .toString();
  final String typeIn = (_tryGet<String?>(() => attendance.typeIn) ?? 'N/A')
      .toString();
  final String statusIn = (_tryGet<String?>(() => attendance.statusIn) ?? 'N/A')
      .toString();

  final String timeOut = (_tryGet<String?>(() => attendance.timeOut) ?? 'N/A')
      .toString();
  final String typeOut = (_tryGet<String?>(() => attendance.typeOut) ?? 'N/A')
      .toString();
  final String statusOut =
      (_tryGet<String?>(() => attendance.statusOut) ?? 'N/A').toString();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    enableDrag: true, // pastikan bisa di-drag
    isDismissible: true,
    backgroundColor: colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.99,
        expand: false,
        builder: (context, scrollController) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView(
                controller: scrollController,
                physics: const ClampingScrollPhysics(), // stabil di Android
                children: [
                  // Grab handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withAlpha(60),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // Header
                  Row(
                    children: [
                      buildAvatar(
                        context,
                        userName: userName,
                        imageUrl:
                            (_tryGet<String?>(
                              () => attendance.user?.avatarUrl,
                            ) ??
                            ''),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'NIP: $userNip',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        // gunakan pop() langsung agar selalu menutup sheet ini
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tanggal
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: const Text('Tanggal'),
                    subtitle: Text(createdAtStr),
                  ),
                  const Divider(height: 16),

                  // Masuk
                  Text('Detail Masuk', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _kvRow(context, 'Jam Masuk', timeIn, icon: Icons.login),
                  _kvRow(context, 'Metode', typeIn),
                  _statusRow(
                    context,
                    'Status',
                    statusIn,
                    isLate: statusIn.toUpperCase() == 'LATE',
                  ),
                  const SizedBox(height: 12),

                  // Keluar
                  Text('Detail Keluar', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _kvRow(context, 'Jam Keluar', timeOut, icon: Icons.logout),
                  _kvRow(context, 'Metode', typeOut),
                  _statusRow(
                    context,
                    'Status',
                    statusOut,
                    isLate: statusOut.toUpperCase() == 'LATE',
                  ),
                  const SizedBox(height: 12),

                  // Foto In/Out
                  if (imageIn.isNotEmpty || imageOut.isNotEmpty) ...[
                    Text('Lampiran Foto', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (imageIn.isNotEmpty)
                          Expanded(
                            child: _imageTile(
                              context,
                              title: 'Masuk',
                              url:
                                  "$baseImageUrl/esas-assets/deployment/$imageIn",
                            ),
                          ),
                        if (imageOut.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _imageTile(
                              context,
                              title: 'Keluar',
                              url:
                                  "$baseImageUrl/esas-assets/deployment/$imageOut",
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Lokasi
                  if (locationIn != null || locationOut != null) ...[
                    Text('Lokasi', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    if (locationIn != null)
                      _kvRow(
                        context,
                        'Lokasi Masuk',
                        locationIn.toString(),
                        icon: Icons.location_on,
                      ),
                    if (locationOut != null)
                      _kvRow(
                        context,
                        'Lokasi Keluar',
                        locationOut.toString(),
                        icon: Icons.location_on_outlined,
                      ),
                    const SizedBox(height: 12),
                  ],

                  // Actions (JANGAN pakai Expanded di dalam ListView)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Tutup'),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _kvRow(
  BuildContext context,
  String keyText,
  String valueText, {
  IconData? icon,
}) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
        Expanded(
          flex: 4,
          child: Text(keyText, style: theme.textTheme.bodyMedium),
        ),
        Expanded(
          flex: 6,
          child: Text(
            valueText,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _statusRow(
  BuildContext context,
  String keyText,
  String valueText, {
  bool isLate = false,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final color = isLate ? cs.error : cs.primary;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(keyText, style: theme.textTheme.bodyMedium),
        ),
        Expanded(
          flex: 6,
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withAlpha(30)),
              ),
              child: Text(
                valueText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: .2,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _imageTile(
  BuildContext context, {
  required String title,
  required String url,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  return InkWell(
    onTap: () {
      showDialog(
        context: context,
        builder: (dCtx) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => SizedBox(
                  height: 220,
                  child: Center(
                    child: Icon(Icons.broken_image, color: cs.outline),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    child: Container(
      height: 140,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Center(child: Icon(Icons.broken_image, color: cs.outline)),
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(150),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
