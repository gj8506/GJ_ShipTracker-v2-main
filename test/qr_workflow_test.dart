import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gjandasher_shiptracker/core/theme/app_theme.dart';
import 'package:gjandasher_shiptracker/features/qr_customers/presentation/customer_list_screen.dart';
import 'package:gjandasher_shiptracker/features/qr_customers/presentation/customer_providers.dart';
import 'package:gjandasher_shiptracker/features/qr_customers/presentation/customer_qr_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('customer QR stays available from the customer registry',
      (tester) async {
    final customer = CustomerModel.forAccount(
      uid: 'uid-42',
      name: 'Ana Cruz',
      contactNumber: '09171234567',
      createdAt: DateTime(2026, 1, 2),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Keep the registry test offline: the production stream reads
          // Firestore, but the QR action itself is what needs verifying.
          customersStreamProvider.overrideWith(
            (ref) => Stream.value([customer]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.themeFor(Brightness.light),
          home: const CustomerListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana Cruz'), findsOneWidget);

    // The QR action still lives in the core staff workflow even though the
    // redundant customer-profile button was removed.
    await tester.tap(find.byTooltip('View QR Code'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerQrDialog), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('GJandAsher ID Card'), findsOneWidget);
    expect(find.text('CODE: GJAS1:uid-42'), findsOneWidget);
  });
}
