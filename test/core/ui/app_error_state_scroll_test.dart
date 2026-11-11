import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/core/ui/components/app_error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// UI-02. Under a header and a strip, a landscape phone leaves the error
/// state about 150 dp. The content needs ~280: the retry button sat outside
/// the hit-test area and could not be pressed, with no other way to retry.
void main() {
  testWidgets('a short space still reaches the retry button', (tester) async {
    var retried = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 150,
                child: AppErrorState(
                  title: 'Gagal memuat',
                  message: 'Periksa koneksi Anda lalu coba lagi.',
                  onRetry: () => retried++,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final button = find.text('Coba lagi');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);

    expect(retried, 1);
    expect(tester.takeException(), isNull);
  });
}
