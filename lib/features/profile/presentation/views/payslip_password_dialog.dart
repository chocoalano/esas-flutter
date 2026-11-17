import 'package:esas/core/theme/app_dimens.dart';
import 'package:esas/core/theme/app_palette.dart';
import 'package:esas/core/theme/app_typography.dart';
import 'package:esas/core/ui/components/app_input_decoration.dart';
import 'package:esas/core/ui/dialogs/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// Asks for the account password before pay is shown (WP-01 Final, G5).
///
/// The password goes to the server, which checks it; the app never keeps it.
/// Returns null when the person cancels.
///
/// Closing goes through `Navigator.pop`, not `Get.back`: when a snackbar is on
/// screen `Get.back()` dismisses THE SNACKBAR and returns, so a "Batal" pressed
/// a second after an error toast did nothing and the dialog stayed.
Future<String?> askPayslipPassword() => Get.dialog<String>(
  const _PayslipPasswordDialog(),
  barrierDismissible: false,
);

class _PayslipPasswordDialog extends StatefulWidget {
  const _PayslipPasswordDialog();

  @override
  State<_PayslipPasswordDialog> createState() => _PayslipPasswordDialogState();
}

class _PayslipPasswordDialogState extends State<_PayslipPasswordDialog> {
  final _password = TextEditingController();
  bool _hidden = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_password.text);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AppDialog(
      icon: Icons.lock_outline_rounded,
      title: 'Buka data gaji',
      message:
          'Masukkan kembali kata sandi akun Anda. Data gaji terbuka selama '
          'beberapa menit di perangkat ini.',
      content: TextField(
        controller: _password,
        autofocus: true,
        obscureText: _hidden,
        autofillHints: const [AutofillHints.password],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: appInputDecoration(
          theme,
          'Kata sandi',
          suffixIcon: IconButton(
            tooltip: _hidden ? 'Tampilkan' : 'Sembunyikan',
            icon: Icon(
              _hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
        ),
      ),
      actions: [
        AppDialog.button(
          label: 'Batal',
          primary: false,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppDialog.button(label: 'Buka', onPressed: _submit),
      ],
    );
  }
}

/// Shows, once, the password that opens a saved payslip PDF (WP-01 Final, G6).
///
/// The file is AES-256 encrypted under a password made for it alone; the app
/// keeps neither, so this is the only time it is shown.
Future<void> showPayslipPdfPassword(String password) => Get.dialog<void>(
  PayslipPdfPasswordDialog(password: password),
  barrierDismissible: false,
);

class PayslipPdfPasswordDialog extends StatelessWidget {
  const PayslipPdfPasswordDialog({required this.password, super.key});

  final String password;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = theme.palette;

    return AppDialog(
      icon: Icons.key_outlined,
      tone: AppDialogTone.warning,
      title: 'Kata sandi slip gaji',
      message:
          'Berkas slip gaji terkunci. Simpan kata sandi ini untuk membukanya - '
          'kata sandi tidak akan ditampilkan lagi.',
      content: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: palette.surfaceSubtle,
          borderRadius: AppRadii.lgAll,
          border: Border.all(color: palette.borderSubtle),
        ),
        // `SelectableText`, supaya orang bisa menyalin sebagian — dan di
        // tengah, karena ini satu nilai yang dibaca, bukan sebuah kalimat.
        child: SelectableText(
          password,
          key: const ValueKey('payslip-pdf-password'),
          textAlign: TextAlign.center,
          style: AppTypography.mono(
            color: theme.colorScheme.onSurface,
            fontSize: 20,
            letterSpacing: 1.2,
          ),
        ),
      ),
      actions: [
        AppDialog.button(
          label: 'Salin & tutup',
          primary: false,
          icon: Icons.copy_rounded,
          onPressed: () async {
            final NavigatorState navigator = Navigator.of(context);
            await Clipboard.setData(ClipboardData(text: password));
            navigator.pop();
          },
        ),
        AppDialog.button(
          label: 'Sudah saya catat',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
