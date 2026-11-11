import 'package:esas/core/theme/app_theme.dart';
import 'package:esas/features/home/data/repositories/home_repository.dart';
import 'package:esas/features/home/presentation/widgets/home_leave_balance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// HOME-14. "Lihat 2 jenis izin lainnya" went to the permit tab, which shows
/// no balances — the two it promised were not anywhere to be seen.
void main() {
  testWidgets('"lihat lainnya" shows the balances it hid', (tester) async {
    var opened = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeLeaveBalance(
              balances: const [
                LeaveBalance(code: 'annual', label: 'annual', remaining: 8),
                LeaveBalance(code: 'sick', label: 'sick', remaining: 3),
                LeaveBalance(code: 'marriage', label: 'marriage', remaining: 3),
                LeaveBalance(
                  code: 'special',
                  label: 'special',
                  remaining: 1.5,
                  quota: 2,
                ),
              ],
              loading: false,
              error: false,
              onOpen: () => opened++,
              onRequests: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Cuti menikah'), findsNothing);

    await tester.tap(find.text('Lihat 2 jenis izin lainnya'));
    await tester.pumpAndSettle();

    expect(opened, 0, reason: 'the permit tab has no balances to show');
    expect(find.text('Cuti menikah'), findsOneWidget);
    expect(find.text('Cuti khusus'), findsOneWidget);
    expect(find.textContaining('1,5'), findsWidgets);
  });
}
