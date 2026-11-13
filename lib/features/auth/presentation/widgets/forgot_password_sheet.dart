import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/ui/components/app_button.dart';
import '../../../../core/ui/components/app_input_decoration.dart';
import '../../../../core/ui/dialogs/app_snackbar.dart';

/// Menampilkan lembar modal bawah (bottom sheet) untuk pemulihan kata sandi.
Future<void> showForgotPasswordSheet(
  BuildContext context, {
  String? initialIdentifier,
  required Future<String> Function(String) onSubmit,
  bool selfServiceAvailable = false,
}) {
  final theme = Theme.of(context);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: theme.colorScheme.surface,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xxl)),
    ),
    builder: (context) => ForgotPasswordSheet(
      initialIdentifier: initialIdentifier,
      onSubmit: onSubmit,
      selfServiceAvailable: selfServiceAvailable,
    ),
  );
}

/// Tampilan formulir pemulihan kata sandi pengguna.
class ForgotPasswordSheet extends StatefulWidget {
  const ForgotPasswordSheet({
    super.key,
    this.initialIdentifier,
    required this.onSubmit,
    this.selfServiceAvailable = false,
  });

  final String? initialIdentifier;
  final Future<String> Function(String identifier) onSubmit;

  /// Whether the server offers a self-service reset (FUNC-C01).
  ///
  /// It does not today: `/auth/forgot-password` does not exist, so a submit
  /// could only ever fail. Until it does, the sheet sends nobody into that
  /// dead end and leads straight to HR / IT, who reset passwords.
  final bool selfServiceAvailable;

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _identifierController;

  bool _isLoading = false;
  bool _isSubmitted = false;
  String? _errorMessage;
  String _successMessage =
      'Instruksi reset kata sandi telah dikirim ke email terdaftar Anda.';

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController(
      text: widget.initialIdentifier ?? '',
    );
  }

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    setState(() => _errorMessage = null);

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final identifier = _identifierController.text.trim();
    setState(() => _isLoading = true);

    try {
      final msg = await widget.onSubmit(identifier);
      if (!mounted) return;
      setState(() {
        _isSubmitted = true;
        _successMessage = msg;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Tidak dapat memproses permintaan. Periksa koneksi internet Anda.';
        _isLoading = false;
      });
    }
  }

  void _copyHrSupportMessage(BuildContext context) {
    final identifier = _identifierController.text.trim();
    final idText = identifier.isNotEmpty ? identifier : '[Isi NIP Anda]';
    final text =
        'Halo Tim HR / IT Administrator,\n'
        'Saya membutuhkan bantuan untuk reset kata sandi akun Absensas.\n'
        'NIP/Email: $idText\n'
        'Mohon bantuan petunjuk atau reset akun saya. Terima kasih.';

    Clipboard.setData(ClipboardData(text: text));
    showInfoSnackbar('Format pesan bantuan telah disalin ke papan klip');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final primary = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsetsBottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grab Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: palette.borderSubtle,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),

              if (!_isSubmitted) ...[
                // Header dengan Icon Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                      ),
                      child: Icon(
                        Icons.lock_reset_rounded,
                        color: primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lupa Kata Sandi?',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.selfServiceAvailable
                                ? 'Masukkan NIP atau Email terdaftar untuk menerima tautan pemulihan sandi.'
                                : 'Kata sandi diatur ulang oleh HR atau admin IT perusahaan Anda. Salin format permintaan di bawah, lalu kirimkan kepada mereka.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: palette.textMuted,
                        size: AppIconSizes.md,
                      ),
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                // Pesan Error jika gagal
                if (widget.selfServiceAvailable && _errorMessage != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: palette.danger.background,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: palette.danger.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: palette.danger.foreground,
                          size: AppIconSizes.md,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.danger.foreground,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Form Input
                if (widget.selfServiceAvailable) ...[
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppFieldLabel('NIP atau Email', required: true),
                        TextFormField(
                          controller: _identifierController,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            hintText:
                                'Contoh: 12345678 atau nama@perusahaan.com',
                            // Cut off at 320dp on one line.
                            hintMaxLines: 6,
                            prefixIcon: const Icon(
                              Icons.badge_outlined,
                              size: AppIconSizes.lg,
                            ),
                            suffixIcon:
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _identifierController,
                                  builder: (context, value, _) {
                                    if (value.text.isEmpty) {
                                      return const SizedBox.shrink();
                                    }
                                    return IconButton(
                                      // Named for TalkBack / VoiceOver.
                                      tooltip: 'Hapus isian',
                                      icon: const Icon(
                                        Icons.cancel_outlined,
                                        size: AppIconSizes.md,
                                      ),
                                      onPressed: () {
                                        _identifierController.clear();
                                        setState(() => _errorMessage = null);
                                      },
                                    );
                                  },
                                ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'NIP atau Email tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        AppButton(
                          wrapLabel: true,
                          label: 'Kirim Instruksi Reset',
                          icon: Icons.send_rounded,
                          busy: _isLoading,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                ],

                // Card Bantuan HR / IT Admin
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: palette.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: palette.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.support_agent_rounded,
                            size: AppIconSizes.md,
                            color: primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          // Flexible: at 320dp the heading ran off the edge.
                          Flexible(
                            child: Text(
                              'Butuh bantuan HR atau IT Admin?',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Jika Anda lupa email kantor atau akun terkunci, hubungi tim HR perusahaan Anda.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textMuted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      InkWell(
                        onTap: () => _copyHrSupportMessage(context),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        // At least 48dp tall: a 24dp link is a miss for a thumb
                        // and fails the platform tap-target guideline.
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: AppIconSizes.sm,
                                  color: primary,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Flexible(
                                  child: Text(
                                    'Salin Format Permintaan ke HR',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Tampilan Sukses
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: palette.success.background,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: palette.success.border,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.mark_email_read_rounded,
                          color: palette.success.foreground,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Permintaan Terkirim',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _successMessage,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: palette.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Tips petunjuk
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: palette.surfaceSubtle,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          border: Border.all(color: palette.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: AppIconSizes.md,
                                  color: palette.warning.foreground,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  'Petunjuk Tambahan',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '• Periksa folder Kotak Masuk atau folder Spam di email Anda.\n'
                              '• Tautan pemulihan umumnya berlaku selama 60 menit.\n'
                              '• Jika tidak menerima email, pastikan NIP atau email Anda sesuai catatan HR.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: palette.textMuted,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      AppButton(
                        wrapLabel: true,
                        label: 'Kembali ke Halaman Masuk',
                        icon: Icons.check_circle_outline_rounded,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
